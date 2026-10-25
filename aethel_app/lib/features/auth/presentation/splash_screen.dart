import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/paper.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.aethel;
    return Scaffold(
      body: LedgerBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AethelMark(size: 58),
              const SizedBox(height: 20),
              Text(
                'Aethel',
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Opening your private ledger',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: palette.line,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
