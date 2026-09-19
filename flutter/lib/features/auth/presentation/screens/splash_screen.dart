import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aethel/core/constants/colors.dart';
import 'package:aethel/core/crypto/secure_key_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'onboarding_screen.dart';

final _storageProvider = Provider((ref) => const FlutterSecureStorage());

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Future<void> _checkAuth() async {
    final storage = ref.read(_storageProvider);
    final hasKey = await storage.hasKey();

    if (!mounted) return;

    if (!hasKey) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    final key = await storage.getDerivedKey();
    if (!mounted) return;

    if (key != null) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), _checkAuth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accentDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('Aethel', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark)),
            const SizedBox(height: 8),
            Text('Your data. Your keys. Your privacy.', style: TextStyle(fontSize: 14, color: AppColors.textPrimaryDark.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
