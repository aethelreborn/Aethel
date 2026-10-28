import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/session_controller.dart';
import 'features/auth/presentation/auth_flow.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/unlock_screen.dart';
import 'features/premium/premium_controller.dart';
import 'features/shell/presentation/app_shell.dart';

class AethelApp extends ConsumerWidget {
  const AethelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return MaterialApp(
      title: 'Aethel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const RootGate(),
    );
  }
}

class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fetch the payment plan as soon as the vault opens (sign-in or unlock),
    // so free-tier caps are known before the user taps "add" anywhere.
    ref.listen(sessionControllerProvider, (previous, next) {
      if (next.status == SessionStatus.unlocked &&
          previous?.status != SessionStatus.unlocked) {
        unawaited(ref.read(premiumControllerProvider.notifier).refresh());
      }
    });
    final session = ref.watch(sessionControllerProvider);
    final child = switch (session.status) {
      SessionStatus.booting => const SplashScreen(),
      SessionStatus.signedOut => const AuthFlow(),
      SessionStatus.locked => const UnlockScreen(),
      SessionStatus.unlocked => const AutoLock(child: AppShell()),
    };

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey(session.status),
        child: child,
      ),
    );
  }
}

class AutoLock extends ConsumerStatefulWidget {
  const AutoLock({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoLock> createState() => _AutoLockState();
}

class _AutoLockState extends ConsumerState<AutoLock> {
  AppLifecycleListener? _lifecycle;
  Timer? _inactivity;
  DateTime? _hiddenAt;

  int get _minutes => ref.read(settingsControllerProvider).autoLockMinutes;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: () {
        // Back in the app — e.g. returning from the payment browser. Re-check
        // any pending checkout and the plan itself.
        unawaited(ref.read(premiumControllerProvider.notifier).refresh());
        final hiddenAt = _hiddenAt;
        if (hiddenAt != null && _minutes > 0) {
          if (DateTime.now().difference(hiddenAt).inMinutes >= _minutes) {
            _lock();
          }
        }
        _hiddenAt = null;
      },
    );
    _resetTimer();
  }

  void _resetTimer() {
    _inactivity?.cancel();
    final minutes = _minutes;
    if (minutes <= 0) return;
    _inactivity = Timer(Duration(minutes: minutes), _lock);
  }

  void _lock() {
    if (!mounted) return;
    ref.read(sessionControllerProvider.notifier).lock();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _inactivity?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsControllerProvider, (previous, next) {
      if (previous?.autoLockMinutes != next.autoLockMinutes) {
        _resetTimer();
      }
    });
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerSignal: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
