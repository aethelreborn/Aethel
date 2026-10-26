import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/password_tools.dart';
import '../../../widgets/page.dart';
import '../../../widgets/password_strength.dart';
import 'auth_frame.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({
    super.key,
    required this.onBack,
    required this.onSignIn,
  });

  final VoidCallback onBack;
  final VoidCallback onSignIn;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    await ref.read(sessionControllerProvider.notifier).signUp(
          email: _email.text,
          masterPassword: _password.text,
          name: _name.text,
        );
    if (mounted) setState(() => _submitted = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final busy = session.busy || _submitted;

    return AuthFrame(
      headline: 'A fresh page, sealed.',
      supporting:
          'Your vault is created on this device first. The server stores an encrypted copy it cannot read — not your titles, passwords, or notes.',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: busy ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 16),
              const AuthFormHeading(
                title: 'Start a private ledger.',
                subtitle:
                    'One account for the vault, the bills, and your focus.',
              ),
              const SizedBox(height: 24),
              if (session.error != null) ...[
                ErrorBanner(
                  message: session.error!,
                  onDismiss: () =>
                      ref.read(sessionControllerProvider.notifier).clearError(),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  hintText: 'What should Aethel call you?',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email.';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                label: 'Master password',
                hint:
                    'At least ${AppConfig.minMasterPasswordLength} characters',
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < AppConfig.minMasterPasswordLength) {
                    return 'Use at least ${AppConfig.minMasterPasswordLength} characters.';
                  }
                  if (passwordStrength(password) < 2) {
                    return 'Mix letters, numbers, or symbols.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              PasswordStrengthMeter(controller: _password),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirm,
                label: 'Confirm master password',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) {
                  if (value != _password.text) {
                    return 'The two passwords do not match.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: palette.brassSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: palette.brass),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'There is no reset. Aethel cannot recover this password — keep it somewhere safe.',
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create my vault'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have a vault?',
                    style: textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                  TextButton(
                    onPressed: busy ? null : widget.onSignIn,
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
