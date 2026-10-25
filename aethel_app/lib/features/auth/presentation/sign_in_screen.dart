import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/page.dart';
import 'auth_frame.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    super.key,
    required this.onBack,
    required this.onSignUp,
  });

  final VoidCallback onBack;
  final VoidCallback onSignUp;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    await ref.read(sessionControllerProvider.notifier).signIn(
          email: _email.text,
          masterPassword: _password.text,
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
      headline: 'Your ledger is already here.',
      supporting:
          'Unlock this device with your master password. The server only ever receives a derived verifier, never the password itself.',
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
                title: 'Open your vault.',
                subtitle:
                    'Enter the email and master password for this account.',
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Enter your master password.';
                  }
                  return null;
                },
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
                    : const Text('Unlock my vault'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.offline_bolt_outlined,
                      size: 15, color: palette.brass),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'If the server is unreachable, unlock once online to refresh this device.',
                      style:
                          textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Divider(color: palette.line),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New to Aethel?',
                    style: textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                  TextButton(
                    onPressed: busy ? null : widget.onSignUp,
                    child: const Text('Create a vault'),
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
