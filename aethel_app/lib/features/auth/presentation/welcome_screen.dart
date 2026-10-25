import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_frame.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onCreate,
    required this.onSignIn,
  });

  final VoidCallback onCreate;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    return AuthFrame(
      headline: 'Keep the keys to your life, close.',
      supporting:
          'Aethel is a private vault, a bill ledger, and a focus timer. '
          'Everything is encrypted on this device before it ever reaches a server.',
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthFormHeading(
            title: 'A quieter place for the important things.',
            subtitle:
                'One master password opens your vault. We never see it, and we cannot reset it.',
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: onCreate,
            child: const Text('Create your vault'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onSignIn,
            child: const Text('Open an existing vault'),
          ),
          const SizedBox(height: 28),
          Divider(color: palette.line),
          const SizedBox(height: 20),
          const _ModuleLine(
            icon: Icons.lock_outline_rounded,
            label: 'Vault',
            description: 'Passwords, cards, notes',
          ),
          const SizedBox(height: 14),
          const _ModuleLine(
            icon: Icons.receipt_long_outlined,
            label: 'Bills',
            description: 'Subscriptions and due dates',
          ),
          const SizedBox(height: 14),
          const _ModuleLine(
            icon: Icons.hourglass_empty_rounded,
            label: 'Focus',
            description: 'A timer that remembers',
          ),
          const SizedBox(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 16, color: palette.brass),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your master password never leaves this device. Sync sends ciphertext only.',
                  style: textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleLine extends StatelessWidget {
  const _ModuleLine({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.teal),
        const SizedBox(width: 11),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.muted),
          ),
        ),
      ],
    );
  }
}
