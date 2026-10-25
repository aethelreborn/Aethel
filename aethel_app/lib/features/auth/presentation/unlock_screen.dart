import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/page.dart';
import '../../../widgets/sheets.dart';
import 'auth_frame.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_submitted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    await ref.read(sessionControllerProvider.notifier).unlock(_password.text);
    if (mounted) setState(() => _submitted = false);
  }

  Future<void> _biometrics() async {
    await ref.read(sessionControllerProvider.notifier).unlockWithBiometrics();
  }

  Future<void> _switchAccount() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Use a different account?',
      message:
          'The encrypted vault stored on this device will be removed. Anything that has not synced yet will be lost.',
      confirmLabel: 'Remove local vault',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final profile = session.profile;
    final name = profile?.name.trim() ?? '';
    final firstName = name.isEmpty ? '' : name.split(' ').first;
    final busy = session.busy || _submitted;
    final biometrics = session.biometricAvailable && settings.biometricUnlock;

    return AuthFrame(
      headline: 'Locked, as it should be.',
      supporting:
          'The vault is sealed on this device. Your master password is the only key; Aethel cannot recover it for you.',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthFormHeading(
                title: firstName.isEmpty
                    ? 'Welcome back.'
                    : 'Welcome back, $firstName.',
                subtitle: profile?.email ?? 'Unlock this device to continue.',
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
              PasswordField(
                controller: _password,
                label: 'Master password',
                autofocus: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _unlock(),
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Enter your master password.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : _unlock,
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
              if (biometrics) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: busy ? null : _biometrics,
                  icon: const Icon(Icons.fingerprint_rounded, size: 20),
                  label: const Text('Unlock with biometrics'),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_outlined,
                      size: 15, color: palette.brass),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Offline unlock works. Sync resumes when Aethel can reach the server.',
                      style:
                          textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: palette.line),
              Center(
                child: TextButton(
                  onPressed: busy ? null : _switchAccount,
                  child: const Text('Use a different account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
