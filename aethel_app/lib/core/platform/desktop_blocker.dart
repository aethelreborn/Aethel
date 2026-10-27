import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Pure-Dart desktop app blocker: polls the OS process table with
/// [Process.run] and force-kills matching processes until a deadline. No
/// native code and no MethodChannel are involved, so it works on Windows,
/// macOS, and Linux without platform channels.
///
/// Matching rule (conservative, exact-first):
/// * Display names and process names are normalized to lowercase; a
///   trailing `.exe` and any directory path are stripped from process
///   entries before comparison.
/// * A small alias map resolves well-known display names to their real
///   executable (e.g. "Visual Studio Code" -> `code`, "Google Chrome" ->
///   `chrome`, "Microsoft Edge" -> `msedge`). When an alias applies, only
///   an exact match on that executable kills anything.
/// * Otherwise a process matches only if its name equals the full display
///   name, or the display name with separators removed
///   ("visual studio code" -> `visualstudiocode`). For single-word display
///   names that is the same as equality.
/// * Multi-word unknown names are never word- or substring-matched, so
///   picking "Markdown Code Notes" can never kill `code`. Prefer exact
///   display names in the picker.
class DesktopBlocker {
  DesktopBlocker._();

  static const Duration _pollInterval = Duration(milliseconds: 2000);
  static const Duration _commandTimeout = Duration(seconds: 5);

  /// Display-name fragment -> exact executable name. Only common mappings
  /// that can be justified; the executable itself must still match exactly.
  static const Map<String, String> _aliases = <String, String>{
    'visual studio code': 'code',
    'vs code': 'code',
    'vscode': 'code',
    'google chrome': 'chrome',
    'chrome': 'chrome',
    'microsoft edge': 'msedge',
    'msedge': 'msedge',
    'edge': 'msedge',
    'mozilla firefox': 'firefox',
    'firefox': 'firefox',
    'spotify': 'spotify',
    'discord': 'discord',
  };

  /// Executables that must never be killed, regardless of what the user
  /// picked. Names are normalized the same way as process entries (no
  /// `.exe`, no path, lowercase).
  static const Set<String> _systemNames = <String>{
    // Windows.
    'system',
    'idle',
    'registry',
    'smss',
    'csrss',
    'wininit',
    'winlogon',
    'services',
    'lsass',
    'svchost',
    'fontdrvhost',
    'dwm',
    'conhost',
    'sihost',
    'taskhostw',
    'ctfmon',
    'runtimebroker',
    'searchindexer',
    'spoolsv',
    'explorer',
    'taskkill',
    'tasklist',
    // macOS.
    'launchd',
    'kernel_task',
    'coreaudiod',
    'windowserver',
    'loginwindow',
    'dock',
    'finder',
    'systemuiserver',
    'controlcenter',
    'notificationcenter',
    'opendirectoryd',
    'configd',
    'distnoted',
    'usernoted',
    'bluetoothd',
    'mds',
    'securityagent',
    'tccd',
    // Linux.
    'init',
    'systemd',
    'kthreadd',
    'ksoftirqd',
    'dbus-daemon',
    'dbus',
    'sshd',
    'gdm',
    'sddm',
    'lightdm',
    'gnome-shell',
    'plasmashell',
    'xorg',
    'xwayland',
    'kwin_x11',
    'kwin_wayland',
    'xfwm4',
    'mutter',
    'pulseaudio',
    'pipewire',
    'wireplumber',
    'networkmanager',
    'systemd-logind',
    'systemd-udevd',
    'systemd-journald',
    'bash',
    'zsh',
    'fish',
    'sh',
    'sudo',
  };

  static Timer? _timer;
  static bool _busy = false;
  static DateTime _until = DateTime.fromMillisecondsSinceEpoch(0);
  static List<_Target> _targets = const <_Target>[];

  /// Whether a block loop is currently scheduled.
  static bool get isRunning => _timer != null;

  /// Starts a background loop that kills processes matching [names] until
  /// [until]. Returns false if [names] is empty, [until] is in the past, or
  /// no kill mechanism is available on this platform (anything other than
  /// Windows, macOS, or Linux; those always ship `taskkill`/`kill`).
  static Future<bool> start({
    required List<String> names,
    required DateTime until,
  }) async {
    if (!_isSupportedPlatform) return false;
    if (!until.isAfter(DateTime.now())) return false;
    final cleaned = <String>[
      for (final name in names)
        if (name.trim().isNotEmpty) _normalizeName(name),
    ];
    if (cleaned.isEmpty) return false;
    stop();
    _targets = <_Target>[
      for (final name in cleaned) _buildTarget(name),
    ];
    _until = until;
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(_tick());
    });
    unawaited(_tick());
    return true;
  }

  /// Stops the loop if running. An already in-flight tick finishes against
  /// its own snapshot and cannot restart the loop.
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _targets = const <_Target>[];
    _until = DateTime.fromMillisecondsSinceEpoch(0);
  }

  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<void> _tick() async {
    if (_busy) return;
    final activeTimer = _timer;
    if (activeTimer == null) return;
    final targets = List<_Target>.of(_targets);
    final until = _until;
    _busy = true;
    try {
      if (!DateTime.now().isBefore(until)) {
        if (identical(_timer, activeTimer)) stop();
        return;
      }
      if (targets.isEmpty) return;
      final processes = await _listProcesses();
      final killedImages = <String>{};
      final killedPids = <int>{};
      for (final process in processes) {
        if (_systemNames.contains(process.name)) continue;
        if (_isSelf(process)) continue;
        if (!targets.any((target) => target.matches(process.name))) continue;
        if (defaultTargetPlatform == TargetPlatform.windows) {
          final image = process.image;
          if (image == null || !killedImages.add(image.toLowerCase())) {
            continue;
          }
        } else if (!killedPids.add(process.pid)) {
          continue;
        }
        if (!identical(_timer, activeTimer)) return;
        try {
          await _kill(process);
        } catch (_) {
          // A single failed kill must not stop the loop.
        }
        if (!DateTime.now().isBefore(until)) {
          if (identical(_timer, activeTimer)) stop();
          return;
        }
      }
    } catch (_) {
      // Never throw out of the polling loop; the next tick will retry.
    } finally {
      _busy = false;
    }
  }

  static Future<List<_ProcessEntry>> _listProcesses() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return _listWindows();
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return _listPosix();
      default:
        return const <_ProcessEntry>[];
    }
  }

  static Future<List<_ProcessEntry>> _listWindows() async {
    final result = await Process.run(
      'tasklist',
      <String>['/FO', 'CSV', '/NH'],
    ).timeout(_commandTimeout);
    if (result.exitCode != 0) return const <_ProcessEntry>[];
    final stdout = result.stdout;
    if (stdout is! String) return const <_ProcessEntry>[];
    final entries = <_ProcessEntry>[];
    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final fields = _parseCsvLine(trimmed);
      if (fields.length < 2) continue;
      final image = fields[0].trim();
      final pid = int.tryParse(fields[1].trim());
      if (image.isEmpty || pid == null) continue;
      entries.add(_ProcessEntry(
        pid: pid,
        name: _normalizeProcessName(image),
        image: image,
      ));
    }
    return entries;
  }

  static Future<List<_ProcessEntry>> _listPosix() async {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final result = await Process.run(
      'ps',
      isMac ? <String>['-axo', 'pid=,comm='] : <String>['-eo', 'pid=,comm='],
    ).timeout(_commandTimeout);
    if (result.exitCode != 0) return const <_ProcessEntry>[];
    final stdout = result.stdout;
    if (stdout is! String) return const <_ProcessEntry>[];
    final entries = <_ProcessEntry>[];
    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final space = trimmed.indexOf(' ');
      if (space <= 0) continue;
      final pid = int.tryParse(trimmed.substring(0, space));
      final comm = trimmed.substring(space + 1).trim();
      if (pid == null || comm.isEmpty) continue;
      final base = comm.split('/').last;
      if (base.isEmpty) continue;
      entries.add(_ProcessEntry(
        pid: pid,
        name: _normalizeProcessName(base),
      ));
    }
    return entries;
  }

  static Future<void> _kill(_ProcessEntry process) async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        final image = process.image;
        if (image == null) return;
        if (image.contains('/') ||
            image.contains(r'\') ||
            image.contains('"')) {
          return;
        }
        await Process.run(
          'taskkill',
          <String>['/F', '/T', '/IM', image],
        ).timeout(_commandTimeout);
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        await Process.run(
          'kill',
          <String>['-9', '${process.pid}'],
        ).timeout(_commandTimeout);
      default:
        return;
    }
  }

  static _Target _buildTarget(String displayName) {
    final normalized = _normalizeName(displayName);
    final alias = _aliasFor(normalized);
    if (alias != null) {
      return _Target(displayName, <String>{alias});
    }
    final compact = normalized.replaceAll(RegExp('[^a-z0-9]'), '');
    final candidates = <String>{normalized};
    if (compact.isNotEmpty && compact != normalized) {
      candidates.add(compact);
    }
    return _Target(displayName, candidates);
  }

  /// Longest/most specific keys are listed first in [_aliases], so an exact
  /// key match wins; otherwise the key must appear as a whole word.
  static String? _aliasFor(String normalized) {
    for (final entry in _aliases.entries) {
      if (normalized == entry.key) return entry.value;
    }
    for (final entry in _aliases.entries) {
      if (_hasWholeWord(normalized, entry.key)) return entry.value;
    }
    return null;
  }

  static bool _hasWholeWord(String text, String word) {
    if (!text.contains(word)) return false;
    final start = text.indexOf(word);
    final end = start + word.length;
    final beforeOk = start == 0 || text[start - 1] == ' ';
    final afterOk = end == text.length || text[end] == ' ';
    return beforeOk && afterOk;
  }

  static String _normalizeName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _isSelf(_ProcessEntry process) {
    final self = Platform.resolvedExecutable.split(RegExp(r'[/\\]')).last;
    final normalized = _normalizeProcessName(self);
    return process.name == normalized || process.name == 'aethel';
  }

  static String _normalizeProcessName(String raw) {
    var name = raw.trim().toLowerCase();
    if (name.endsWith('.exe')) {
      name = name.substring(0, name.length - 4);
    }
    return name;
  }

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}

class _Target {
  const _Target(this.displayName, this.processNames);

  final String displayName;
  final Set<String> processNames;

  bool matches(String processName) => processNames.contains(processName);
}

class _ProcessEntry {
  const _ProcessEntry({required this.pid, required this.name, this.image});

  final int pid;

  /// Normalized executable basename with any `.exe` stripped.
  final String name;

  /// Original Windows image name including `.exe`, used for `taskkill /IM`.
  final String? image;
}
