import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform/device_services.dart';

/// A newer build published on GitHub Releases.
class UpdateInfo {
  const UpdateInfo({
    required this.tag,
    required this.version,
    required this.releaseUrl,
    required this.notes,
    required this.assetName,
    required this.assetUrl,
  });

  final String tag;
  final String version;
  final String releaseUrl;
  final String notes;
  final String? assetName;
  final String? assetUrl;
}

enum UpdateOutcome { installed, relaunched, opened, failed }

/// Compares the installed build with the published release and, when asked,
/// downloads and hands the new build to the platform installer.
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  static const _repo = 'aethelreborn/Aethel';
  static const snoozedTagKey = 'update_snoozed_tag';
  static const lastCheckKey = 'update_last_check_ms';

  static const _checkInterval = Duration(hours: 12);

  final Dio _dio = Dio();

  /// Returns a release newer than the installed build, or null when there is
  /// nothing to do (throttled, already snoozed, or the check failed — an
  /// update check must never break startup).
  Future<UpdateInfo?> check(SharedPreferences prefs,
      {bool force = false}) async {
    final stamp = DateTime.now();
    if (!force) {
      final last = prefs.getInt(lastCheckKey) ?? 0;
      final elapsed = stamp.millisecondsSinceEpoch - last;
      if (last != 0 && elapsed < _checkInterval.inMilliseconds) return null;
    }
    try {
      final package = await PackageInfo.fromPlatform();
      final response = await _dio.get<Object?>(
        'https://api.github.com/repos/$_repo/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Aethel',
          },
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      await prefs.setInt(lastCheckKey, stamp.millisecondsSinceEpoch);
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;

      final tag = (data['tag_name'] as String?) ?? '';
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (!_newer(version, package.version)) return null;

      String? assetName;
      String? assetUrl;
      final wanted = _assetName();
      final assets = (data['assets'] as List?)?.whereType<Map>() ?? const [];
      for (final asset in assets) {
        final name = '${asset['name']}';
        if (wanted != null && name == wanted) {
          assetName = name;
          assetUrl = asset['browser_download_url'] as String?;
        }
      }

      final notes = '${data['body'] ?? ''}'.trim();
      final info = UpdateInfo(
        tag: tag,
        version: version,
        releaseUrl:
            '${data['html_url'] ?? 'https://github.com/$_repo/releases'}',
        notes: notes.isEmpty ? 'A newer build of Aethel is ready.' : notes,
        assetName: assetName,
        assetUrl: assetUrl,
      );
      // The user dismissed this release before — stay quiet about it.
      if (prefs.getString(snoozedTagKey) == info.version) return null;
      return info;
    } catch (error) {
      debugPrint('Update check failed: $error');
      return null;
    }
  }

  /// Remembers a dismissed release so the prompt does not come back for it.
  Future<void> snooze(SharedPreferences prefs, UpdateInfo info) =>
      prefs.setString(snoozedTagKey, info.version);

  static bool _newer(String candidate, String current) {
    final a = candidate.split('.').map(int.tryParse).toList();
    final b = current.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 4; i++) {
      final left = i < a.length ? (a[i] ?? 0) : 0;
      final right = i < b.length ? (b[i] ?? 0) : 0;
      if (left != right) return left > right;
    }
    return false;
  }

  /// The release asset that matches this build's platform, when we can
  /// install it ourselves.
  String? _assetName() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'aethel-android.apk';
      case TargetPlatform.linux:
        return 'aethel-linux-x64.AppImage';
      case TargetPlatform.windows:
        return 'aethel-windows-x64-setup.exe';
      case TargetPlatform.macOS:
        return 'aethel-macos.dmg';
      default:
        return null;
    }
  }

  /// Downloads the release asset and hands it to the platform.
  Future<UpdateOutcome> install(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final assetUrl = info.assetUrl;
    if (assetUrl == null || kIsWeb) {
      await _open(info.releaseUrl);
      return UpdateOutcome.opened;
    }

    String path;
    try {
      path = await _download(assetUrl, info.assetName!, onProgress);
    } catch (error) {
      debugPrint('Update download failed: $error');
      return UpdateOutcome.failed;
    }

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final ok = await DeviceServices.instance.installApk(path);
          return ok ? UpdateOutcome.installed : UpdateOutcome.failed;
        case TargetPlatform.linux:
          await Process.run('chmod', ['+x', path]);
          await Process.start(path, <String>[],
              mode: ProcessStartMode.detached);
          return _leaveAndRelaunch();
        case TargetPlatform.windows:
          await Process.start(path, <String>[],
              mode: ProcessStartMode.detached);
          return _leaveAndRelaunch();
        case TargetPlatform.macOS:
          await Process.start('open', [path], mode: ProcessStartMode.detached);
          return UpdateOutcome.opened;
        default:
          await _open(info.releaseUrl);
          return UpdateOutcome.opened;
      }
    } catch (error) {
      debugPrint('Update install failed: $error');
      return UpdateOutcome.failed;
    }
  }

  Future<String> _download(
    String url,
    String fileName,
    void Function(double progress)? onProgress,
  ) async {
    final directory = await _downloadDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    await _dio.download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
    return path;
  }

  /// Android installs out of the app cache (declared in file_paths.xml);
  /// everything else uses the temp dir.
  Future<Directory> _downloadDirectory() async {
    final base = await getTemporaryDirectory();
    final directory = Directory('${base.path}${Platform.pathSeparator}updates');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  /// Desktop installers replace files on disk, so this build has to get out
  /// of the way first.
  /// The installer is already running; give the OS a beat, then leave so the
  /// freshly installed build can start.
  UpdateOutcome _leaveAndRelaunch() {
    Future<void>.delayed(const Duration(milliseconds: 400), () => exit(0));
    return UpdateOutcome.relaunched;
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Could not open $url: $error');
    }
  }
}
