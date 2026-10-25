import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import 'welcome_screen.dart';

enum _AuthPage { welcome, signIn, signUp }

class AuthFlow extends ConsumerStatefulWidget {
  const AuthFlow({super.key});

  @override
  ConsumerState<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends ConsumerState<AuthFlow> {
  _AuthPage _page = _AuthPage.welcome;

  void _go(_AuthPage page) {
    ref.read(sessionControllerProvider.notifier).clearError();
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_page) {
      _AuthPage.welcome => WelcomeScreen(
          key: const ValueKey('welcome'),
          onCreate: () => _go(_AuthPage.signUp),
          onSignIn: () => _go(_AuthPage.signIn),
        ),
      _AuthPage.signIn => SignInScreen(
          key: const ValueKey('signIn'),
          onBack: () => _go(_AuthPage.welcome),
          onSignUp: () => _go(_AuthPage.signUp),
        ),
      _AuthPage.signUp => SignUpScreen(
          key: const ValueKey('signUp'),
          onBack: () => _go(_AuthPage.welcome),
          onSignIn: () => _go(_AuthPage.signIn),
        ),
    };

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }
}
