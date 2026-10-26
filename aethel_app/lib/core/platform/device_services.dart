import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A launchable application installed on this device.
class InstalledApp {
  const InstalledApp({required this.id, required this.name});

  /// Stable identifier: Android package name, desktop file id, executable
  /// name, or the bundle folder name on macOS.
  final String id;
  final String name;

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) => InstalledApp(
        id: '${map['id'] ?? ''}',
        name: '${map['name'] ?? ''}',
      );
}

/// What this platform can actually do, so the UI can ask for the right
/// things instead of offering controls that go nowhere.
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.appList,
    required this.appBlocking,
    required this.usageAccess,
    required this.installApk,
  });

  final bool appList;
  final bool appBlocking;
  final bool usageAccess;
  final bool installApk;

  static const desktopUnsupported = DeviceCapabilities(
    appList: true,
    appBlocking: false,
    usageAccess: false,
    installApk: false,
  );

  static const web = DeviceCapabilities(
    appList: false,
    appBlocking: false,
    usageAccess: false,
    installApk: false,
  );
}

enum PermissionOutcome { granted, denied, notRequired, unsupported }

class DeviceServices {
  DeviceServices._();

  static final DeviceServices instance = DeviceServices._();

  static const MethodChannel channel = MethodChannel('aethel/platform');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<DeviceCapabilities> capabilities() async {
    if (kIsWeb) return DeviceCapabilities.web;
    if (_isAndroid) {
      final usage = await _invoke<bool>('hasUsageAccess') ?? false;
      return DeviceCapabilities(
        appList: true,
        appBlocking: true,
        usageAccess: usage,
        installApk: true,
      );
    }
    return DeviceCapabilities.desktopUnsupported;
  }

  /// Android's usage-access grant is a system settings toggle, so it can only
  /// be checked, never requested from inside the app.
  Future<bool> hasUsageAccess() async {
    if (!_isAndroid) return false;
    return await _invoke<bool>('hasUsageAccess') ?? false;
  }

  Future<void> requestUsageAccess() async {
    if (!_isAndroid) return;
    await _invoke<bool>('requestUsageAccess');
  }

  Future<void> openNotificationSettings() async {
    await _invoke<bool>('openNotificationSettings');
  }

  /// Shows the installed applications the user can pick to block.
  ///
  /// Android needs a platform channel (package visibility), the desktop
  /// platforms are enumerated straight from disk so they keep working even
  /// where no native code is registered.
  Future<List<InstalledApp>> installedApps() async {
    if (kIsWeb) return const [];
    if (_isAndroid) {
      final raw = await _invoke<List<dynamic>>('listApps');
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(InstalledApp.fromMap)
          .where((app) => app.id.isNotEmpty && app.name.isNotEmpty)
          .toList();
    }
    if (_isDesktop) return _desktopApps();
    return const [];
  }

  /// Downloads are handed to the Android package installer.
  Future<bool> installApk(String path) async {
    if (!_isAndroid) return false;
    return await _invoke<bool>('installApk', path) ?? false;
  }

  /// Keeps [names] out of reach until [until]. Returns true when a platform
  /// block session is actually running — only Android can do this, so the
  /// caller can tell the user honestly where blocking is unavailable.
  Future<bool> startBlock({
    required List<String> names,
    required DateTime until,
  }) async {
    if (!_isAndroid || names.isEmpty) return false;
    final ok = await _invoke<bool>('startBlock', <String, dynamic>{
      'names': names,
      'untilMs': until.millisecondsSinceEpoch,
    });
    return ok ?? false;
  }

  Future<void> stopBlock() async {
    if (!_isAndroid) return;
    await _invoke<bool>('stopBlock');
  }

  Future<List<InstalledApp>> _desktopApps() async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.linux:
          return _linuxApps();
        case TargetPlatform.windows:
          return _windowsApps();
        case TargetPlatform.macOS:
          return _macApps();
        default:
          return const [];
      }
    } catch (_) {
      return const [];
    }
  }

  List<InstalledApp> _linuxApps() {
    final directories = <String>{
      '${Platform.environment['HOME'] ?? ''}/.local/share/applications',
      '/usr/share/applications',
      '/usr/local/share/applications',
      '/var/lib/snapd/desktop/applications',
      '/etc/profile.d',
    };
    final found = <String, InstalledApp>{};
    for (final directory in directories) {
      final dir = Directory(directory);
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.desktop')) continue;
        final id = entry.uri.pathSegments.last;
        final contents = _readHead(entry, 8000);
        if (contents.isEmpty) continue;
        if (RegExp(r'^NoDisplay=true', multiLine: true).hasMatch(contents) ||
            RegExp(r'^Hidden=true', multiLine: true).hasMatch(contents)) {
          continue;
        }
        if (!RegExp(r'^Type=Application', multiLine: true)
            .hasMatch(contents)) {
          continue;
        }
        final name = RegExp(r'^Name=(.+)$', multiLine: true)
            .stringMatch(contents)
            ?.substring(5)
            .trim();
        if (name == null || name.isEmpty) continue;
        found[id] = InstalledApp(id: id, name: name);
      }
    }
    return found.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<InstalledApp> _windowsApps() {
    final roots = <String>{
      '${Platform.environment['APPDATA'] ?? ''}\\Microsoft\\Windows\\Start Menu\\Programs',
      '$_programData\\Microsoft\\Windows\\Start Menu\\Programs',
      '${Platform.environment['LOCALAPPDATA'] ?? ''}\\Microsoft\\Windows\\Start Menu\\Programs',
    };
    final found = <String, InstalledApp>{};
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync(recursive: true, followLinks: false)) {
        if (entry is! File || !entry.path.toLowerCase().endsWith('.lnk')) {
          continue;
        }
        final base = entry.uri.pathSegments.last;
        final name = base.substring(0, base.length - 4);
        if (name.isEmpty) continue;
        found[name] = InstalledApp(id: name, name: name);
      }
    }
    return found.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  String get _programData =>
      Platform.environment['ProgramData'] ?? r'C:\ProgramData';

  List<InstalledApp> _macApps() {
    final roots = <String>{
      '/Applications',
      '/Applications/Utilities',
      '${Platform.environment['HOME'] ?? ''}/Applications',
    };
    final found = <String, InstalledApp>{};
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync(followLinks: false)) {
        if (entry is! Directory || !entry.path.endsWith('.app')) continue;
        final base = entry.uri.pathSegments.last;
        final name = base.endsWith('.app')
            ? base.substring(0, base.length - 4)
            : base;
        if (name.isEmpty) continue;
        found[base] = InstalledApp(id: base, name: name);
      }
    }
    return found.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  String _readHead(File file, int bytes) {
    try {
      final raf = file.openSync();
      final length = raf.lengthSync();
      final data = raf.readSync(length < bytes ? length : bytes);
      raf.closeSync();
      return utf8.decode(data, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }
}
