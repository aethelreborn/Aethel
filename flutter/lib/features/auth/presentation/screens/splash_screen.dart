import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aethel/core/constants/colors.dart';
import 'onboarding_screen.dart';

final _localAuthProvider = Provider((ref) => LocalAuthentication());
final _storageProvider = Provider((ref) => const FlutterSecureStorage());

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _checked = false;

  Future<void> _checkAuth() async {
    final auth = ref.read(_localAuthProvider);
    final storage = ref.read(_storageProvider);
    try {
      final canBiometric = await auth.canCheckBiometrics;
      final stored = await storage.read(key: 'vault_key');
      if (!mounted) return;
      if (stored != null && canBiometric) {
        final authenticated = await auth.authenticate(
          localizedReason: 'Verify it\'s you to unlock Aethel',
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!mounted) return;
        if (authenticated) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
          return;
        }
      }
      if (!mounted) return;
      if (stored == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/master-password');
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
    setState(() => _checked = true);
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
            Text('Your data. Your keys. Your privacy.', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            if (!_checked) ...[
              const SizedBox(height: 48),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
