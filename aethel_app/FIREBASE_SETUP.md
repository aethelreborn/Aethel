# Aethel — Complete Firebase Setup Guide

## Step 1: Generate Android Platform Files

```bash
cd "/home/darkie/Main Project/Aethel/aethel_app"
flutter create . --platforms=android
```

This creates `android/` folder with Gradle build files.

---

## Step 2: Add Firebase Packages

```bash
flutter pub add firebase_core firebase_messaging firebase_analytics
```

This updates `pubspec.yaml` and runs `flutter pub get`.

---

## Step 3: Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click **"Add project"**
3. Name: `Aethel`
4. (Optional) Disable Google Analytics
5. Click **"Create project"**

---

## Step 4: Add Android App to Firebase

1. In Firebase console → Project Overview → Click the **Android icon**
2. **Package name:** `com.example.aethel`
3. **App nickname:** `Aethel Android` (optional)
4. **Debug signing certificate SHA-1:** (skip for now, add later for production)
5. Click **"Register app"**
6. **Download `google-services.json`**
7. Put it in: `aethel_app/android/app/google-services.json`

---

## Step 5: Update Android Build Files

### File: `android/build.gradle` (top-level)

Find the `dependencies` block and add Google Services plugin:

```groovy
buildscript {
    dependencies {
        // ... existing classespath ...
        classpath 'com.google.gms:google-services:4.4.0'  // ← ADD THIS LINE
    }
}
```

### File: `android/app/build.gradle`

Add at the **very bottom** of the file:

```groovy
apply plugin: 'com.google.gms.google-services'
```

---

## Step 6: Initialize Firebase in Flutter

### File: `lib/main.dart`

Replace the entire file with this:

```dart
import 'package:aethel_app/material.dart';
import 'package:aethel_app/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aethel/core/network/api_client.dart';
import 'package:aethel/core/theme/app_theme.dart';
import 'package:aethel/features/auth/presentation/screens/splash_screen.dart';
import 'package:aethel/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:aethel/features/auth/presentation/screens/login_screen.dart';
import 'package:aethel/features/auth/presentation/screens/master_password_setup.dart';
import 'package:aethel/features/auth/presentation/screens/signup_screen.dart';
import 'package:aethel/features/dashboard/presentation/dashboard_screen.dart';
import 'package:aethel/features/dashboard/providers/sync_initializer_provider.dart';

Future<void> _initializeFirebase() async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Firebase for push notifications
  await _initializeFirebase();

  ApiClient.init();
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
```

---

## Step 7: Register Device for Push Notifications

Create a new file: `lib/core/services/firebase_messaging_service.dart`

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:aethel/core/network/api_client.dart';

class FirebaseMessagingService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get token
    final token = await _messaging.getToken();
    if (token != null) {
      print('FCM Token: $token');
      // Send to backend
      await _registerDevice(token);
    }

    // Listen for messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
    });
  }

  static Future<void> _registerDevice(String token) async {
    try {
      await ApiClient.dio.post('/devices/register', data: {
        'pushToken': token,
        'platform': 'android',
      });
      print('Device registered successfully');
    } catch (e) {
      print('Failed to register device: $e');
    }
  }
}
```

Then call it in `main.dart` after Firebase init:

```dart
await FirebaseMessagingService.initialize();
```

---

## Step 8: Run and Test

```bash
flutter run
```

On first launch, Firebase will request notification permissions. Accept them. Check the console for the FCM token.

---

## Step 9: Build Release APK

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

Install it on your phone:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or share it directly — anyone can install it.

---

## Step 10: Set Up FCM Server Key (Backend)

1. In Firebase console → Project Settings → Cloud Messaging tab
2. Copy the **Server key**
3. Add to Railway variables:
   ```
   FCM_SERVER_KEY=<your-fcm-server-key>
   ```
4. Update backend `notifications.service.ts` to use real FCM API

---

## Next Steps

- [ ] Add SHA-1 certificate for production builds
- [ ] Configure FCM server key in backend
- [ ] Test push notifications on real device
- [ ] Upload to Google Play Store ($25 one-time fee)
