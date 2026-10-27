import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/sync_service.dart';
import '../../../core/platform/device_services.dart';
import '../../../core/storage/local_store.dart';
import '../../../data/models.dart';

class FocusState {
  const FocusState({
    this.run,
    this.remainingSeconds = 0,
    this.completedSession,
    this.blockError,
  });

  final FocusRun? run;
  final int remainingSeconds;
  final FocusSession? completedSession;

  /// Non-null when the platform block for this run failed to start (missing
  /// usage access, unresolvable packages, …). The timer keeps running; only
  /// app interception is down.
  final String? blockError;

  bool get isRunning => run != null && !run!.paused;
  bool get isPaused => run?.paused ?? false;

  FocusState copyWith({
    Object? run = _unset,
    int? remainingSeconds,
    Object? completedSession = _unset,
    Object? blockError = _unset,
  }) {
    return FocusState(
      run: identical(run, _unset) ? this.run : run as FocusRun?,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      completedSession: identical(completedSession, _unset)
          ? this.completedSession
          : completedSession as FocusSession?,
      blockError: identical(blockError, _unset)
          ? this.blockError
          : blockError as String?,
    );
  }
}

const Object _unset = Object();

class FocusController extends StateNotifier<FocusState> {
  FocusController() : super(const FocusState()) {
    _restore();
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final LocalStore _local = LocalStore.instance;
  Timer? _ticker;

  void _restore() {
    if (!_local.isOpen) return;
    final run = _local.snapshot.activeFocus;
    if (run == null) return;
    final remaining = run.remainingSeconds(DateTime.now());
    if (remaining <= 0 && !run.paused) {
      unawaited(_complete(run));
      return;
    }
    state = FocusState(run: run, remainingSeconds: remaining);
    if (!run.paused) {
      _startTicker();
      unawaited(_applyBlock(run));
    }
  }

  Future<void> start({
    required String task,
    required int minutes,
    List<String> blockedApps = const [],
  }) async {
    final now = DateTime.now();
    final run = FocusRun(
      task: task.trim().isEmpty ? 'Deep work' : task.trim(),
      minutes: minutes,
      startedAt: now,
      endsAt: now.add(Duration(minutes: minutes)),
      blockedApps: blockedApps,
    );
    _local.snapshot.activeFocus = run;
    await _local.save();
    state = FocusState(run: run, remainingSeconds: minutes * 60);
    _startTicker();
    await _applyBlock(run);
  }

  /// Starts the platform block screen for this run. On platforms without a
  /// blocker this is a no-op (the timer still works). On Android a failure
  /// is surfaced in [FocusState.blockError] so the UI can say so instead of
  /// silently letting the user open YouTube mid-session.
  Future<void> _applyBlock(FocusRun run) async {
    if (run.blockedApps.isEmpty || run.paused) {
      state = state.copyWith(blockError: null);
      return;
    }
    final caps = await DeviceServices.instance.capabilities();
    if (!caps.appBlocking) {
      state = state.copyWith(blockError: null);
      return;
    }
    if (_isAndroid) {
      final overlay = await DeviceServices.instance.hasOverlayPermission();
      final a11y = await DeviceServices.instance.hasAccessibilityBlocker();
      if (!overlay && !a11y) {
        state = state.copyWith(
          blockError:
              'Hard blocking needs "Display over other apps". Open Settings → '
              'Apps → Aethel → Display over other apps, then resume this session.',
        );
        unawaited(DeviceServices.instance.requestOverlayPermission());
        return;
      }
    }
    final ok = await DeviceServices.instance.startBlock(
      names: run.blockedApps,
      until: run.endsAt,
    );
    if (ok) {
      state = state.copyWith(blockError: null);
      return;
    }
    if (_isAndroid) {
      final usage = await DeviceServices.instance.hasUsageAccess();
      state = state.copyWith(
        blockError: usage
            ? 'App blocking could not start. The blocked apps may not be '
                'installed, or the block service was refused.'
            : 'App blocking needs usage access. Open Settings → Special access '
                '→ Usage access and allow Aethel, then resume this session.',
      );
      if (!usage) {
        unawaited(DeviceServices.instance.requestUsageAccess());
      }
      return;
    }
    state = state.copyWith(
      blockError: 'App blocking could not start on this device.',
    );
  }

  void _clearBlock() {
    unawaited(DeviceServices.instance.stopBlock());
  }

  Future<void> pause() async {
    final run = state.run;
    if (run == null || run.paused) return;
    final paused = run.pause(DateTime.now());
    _local.snapshot.activeFocus = paused;
    await _local.save();
    _ticker?.cancel();
    _clearBlock();
    state = state.copyWith(
      run: paused,
      remainingSeconds: paused.pausedRemainingSeconds,
      blockError: null,
    );
  }

  Future<void> resume() async {
    final run = state.run;
    if (run == null || !run.paused) return;
    final resumed = run.resume(DateTime.now());
    _local.snapshot.activeFocus = resumed;
    await _local.save();
    state = state.copyWith(
      run: resumed,
      remainingSeconds: resumed.remainingSeconds(DateTime.now()),
    );
    _startTicker();
    await _applyBlock(resumed);
  }

  Future<void> cancel() async {
    _ticker?.cancel();
    _clearBlock();
    _local.snapshot.activeFocus = null;
    await _local.save();
    state = const FocusState();
  }

  void acknowledgeCompletion() {
    state = state.copyWith(completedSession: null);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final run = state.run;
      if (run == null || run.paused) return;
      final remaining = run.remainingSeconds(DateTime.now());
      if (remaining <= 0) {
        _ticker?.cancel();
        unawaited(_complete(run));
      } else {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  Future<void> _complete(FocusRun run) async {
    _ticker?.cancel();
    _clearBlock();
    final session = FocusSession(
      id: const Uuid().v4(),
      task: run.task,
      minutes: run.minutes,
      startedAt: run.startedAt,
      completed: true,
    );
    final snapshot = _local.snapshot;
    snapshot.sessions.add(session);
    snapshot.activeFocus = null;
    await _local.save();
    SyncService.instance.bump();
    state = FocusState(completedSession: session);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clearBlock();
    super.dispose();
  }
}

final focusControllerProvider =
    StateNotifierProvider<FocusController, FocusState>((ref) {
  return FocusController();
});
