import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/password_tools.dart';

/// Live strength meter bound to a [TextEditingController].
///
/// It listens to the controller so the score moves with every keystroke
/// instead of waiting for the next rebuild triggered by form validation.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) =>
          PasswordStrengthBar(score: passwordStrength(controller.text)),
    );
  }
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.score});

  final int score;

  static String hintFor(int score) {
    return switch (score) {
      0 => 'Start typing to see how it holds up.',
      1 => 'Add length, then a number or a symbol.',
      2 => 'Longer still, and mix in upper case.',
      3 => 'Good. A few more characters would make it excellent.',
      _ => 'Excellent — this one would take a very long time to guess.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    final textTheme = Theme.of(context).textTheme;
    final color = switch (score) {
      <= 1 => palette.danger,
      2 => palette.brass,
      _ => palette.teal,
    };
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var index = 0; index < 4; index++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 4,
                  decoration: BoxDecoration(
                    color: index < score ? color : palette.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (index < 3) const SizedBox(width: 5),
            ],
            const SizedBox(width: 10),
            SizedBox(
              width: 62,
              child: Text(
                passwordStrengthLabel(score),
                textAlign: TextAlign.right,
                style: textTheme.labelSmall?.copyWith(
                  // Nothing typed yet: stay quiet instead of scolding.
                  color: score == 0 ? palette.muted : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          hintFor(score),
          style: textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}
