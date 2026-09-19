import 'package:flutter/material.dart';
import 'package:aethel/core/constants/colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  final _pages = [
    const _OnboardPage(icon: Icons.shield_outlined, title: 'Zero-Knowledge Vault', subtitle: 'Your master password never leaves your device. We can\'t read your data — not even to recover it.'),
    const _OnboardPage(icon: Icons.receipt_long_outlined, title: 'Bill & Subscription Tracker', subtitle: 'Never miss a payment again. Get smart reminders before bills are due and track your monthly spending at a glance.'),
    const _OnboardPage(icon: Icons.do_not_disturb_on_outlined, title: 'Focus Blocker', subtitle: 'Block distracting apps on a schedule so you can stay in the zone. Works offline, respects your time.'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimaryDark : AppColors.bgPrimaryLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  onPageChanged: (i) => setState(() => _page = i),
                  children: _pages.map((p) => p.build(context)).toList(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _page == i ? AppColors.accentLight : Colors.grey.shade400,
                  ),
                )),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/master-password'),
                  child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Continue'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                child: const Text('Already have an account? Log in'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String subtitle;
  const _OnboardPage({required this.icon, required this.title, required this.subtitle});
  Widget build(BuildContext ctx) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 80, color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.accentDark : AppColors.accentLight),
      const SizedBox(height: 24),
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(subtitle, style: TextStyle(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
    ]);
  }
}
