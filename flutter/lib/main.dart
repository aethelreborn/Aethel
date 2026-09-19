import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:aethel/core/theme/app_theme.dart';
import 'package:aethel/features/auth/presentation/screens/splash_screen.dart';
import 'package:aethel/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:aethel/features/auth/presentation/screens/login_screen.dart';
import 'package:aethel/features/auth/presentation/screens/master_password_setup.dart';
import 'package:aethel/features/auth/presentation/screens/signup_screen.dart';
import 'package:aethel/features/dashboard/presentation/dashboard_screen.dart';
import 'package:aethel/features/dashboard/providers/sync_initializer_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  ApiClient.init();
  // Restore persisted JWTs so the user stays logged in across restarts
  final storage = const FlutterSecureStorage();
  final savedAccess = await storage.read(key: 'jwt_access');
  final savedRefresh = await storage.read(key: 'jwt_refresh');
  if (savedAccess != null && savedRefresh != null) {
    await ApiClient.setTokens(savedAccess, savedRefresh);
  }
  runApp(
    ProviderScope(
      child: const AethelApp(),
    ),
  );
}

class AethelApp extends StatelessWidget {
  const AethelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aethel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/master-password': (_) => const MasterPasswordSetupScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
    );
  }
}
