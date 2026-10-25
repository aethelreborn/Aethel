import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/sync_service.dart';
import '../../../core/storage/local_store.dart';
import '../../../data/models.dart';

class FocusState {
  const FocusState({
    this.run,
    this.remainingSeconds = 0,
    this.completedSession,
  });

  final FocusRun? run;
  final int remainingSeconds;
  final FocusSession? completedSession;

  bool get isRunning => run != null && !run!.paused;
  bool get isPaused => run?.paused ?? false;

  FocusState copyWith({
    Object? run = _unset,
    int? remainingSeconds,
    Object? completedSession = _unset,
  }) {
    return FocusState(
      run: identical(run, _unset) ? this.run : run as FocusRun?,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      completedSession: identical(completedSession, _unset)
          ? this.completedSession
          : completedSession as FocusSession?,
    );
  }
}

const Object _unset = Object();

class FocusController extends StateNotifier<FocusState> {
  FocusController() : super(const FocusState()) {
    _restore();
  }

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
    if (!run.paused) _startTicker();
  }

  Future<void> start({required String task, required int minutes}) async {
    final now = DateTime.now();
    final run = FocusRun(
      task: task.trim().isEmpty ? 'Deep work' : task.trim(),
      minutes: minutes,
      startedAt: now,
      endsAt: now.add(Duration(minutes: minutes)),
    );
    _local.snapshot.activeFocus = run;
    await _local.save();
    state = FocusState(run: run, remainingSeconds: minutes * 60);
    _startTicker();
  }

  Future<void> pause() async {
    final run = state.run;
    if (run == null || run.paused) return;
    final paused = run.pause(DateTime.now());
    _local.snapshot.activeFocus = paused;
    await _local.save();
    _ticker?.cancel();
    state = state.copyWith(
      run: paused,
      remainingSeconds: paused.pausedRemainingSeconds,
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
  }

  Future<void> cancel() async {
    _ticker?.cancel();
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
    super.dispose();
  }
}

final focusControllerProvider =
    StateNotifierProvider<FocusController, FocusState>((ref) {
  return FocusController();
});
