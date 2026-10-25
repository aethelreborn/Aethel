import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/paper.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.headline,
    required this.supporting,
    required this.form,
  });

  final String headline;
  final String supporting;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final wide = MediaQuery.sizeOf(context).width >= 940;

    return Scaffold(
      body: LedgerBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (!wide) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLockup(),
                      const SizedBox(height: 36),
                      Text(
                        headline,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        supporting,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: palette.muted),
                      ),
                      const SizedBox(height: 28),
                      PaperCard(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        child: form,
                      ),
                    ],
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(56, 44, 48, 44),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 88)
                              .clamp(0.0, double.infinity)
                              .toDouble(),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BrandLockup(),
                            const SizedBox(height: 84),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: Text(
                                headline,
                                style: constraints.maxWidth > 1200
                                    ? Theme.of(context).textTheme.displayLarge
                                    : Theme.of(context).textTheme.displayMedium,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Text(
                                supporting,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(color: palette.muted),
                              ),
                            ),
                            const SizedBox(height: 30),
                            const _Assurances(),
                            const SizedBox(height: 56),
                            Text(
                              'Aethel keeps the ciphertext. You keep the key.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: palette.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 520,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      border: Border(left: BorderSide(color: palette.line)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 56,
                        vertical: 48,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 96)
                              .clamp(0.0, double.infinity)
                              .toDouble(),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: form,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Assurances extends StatelessWidget {
  const _Assurances();

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    const items = [
      (Icons.key_outlined, 'AES-256-GCM, sealed before sync'),
      (Icons.cloud_off_outlined, 'Works offline; syncs only ciphertext'),
      (Icons.visibility_off_outlined, 'No tracking, ads, or plaintext titles'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 17, color: palette.teal),
                const SizedBox(width: 10),
                Text(
                  item.$2,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.ink,
                        fontSize: 13.5,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class AuthFormHeading extends StatelessWidget {
  const AuthFormHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
    this.hint,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final Iterable<String>? autofillHints;
  final String? hint;
  final bool autofocus;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
          ),
        ),
      ),
    );
  }
}
