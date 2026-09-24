# Aethel — Firebase Setup Guide

## Step 1: Create Firebase Project
1. Go to https://console.firebase.google.com/
2. Click "Add project" → name it "Aethel"
3. Disable Google Analytics (not needed yet)
4. Click "Create project"

## Step 2: Add Android App
1. In Firebase console → Project Overview → Click Android icon
2. Package name: `com.example.aethel`
3. App nickname: "Aethel Android" (optional)
4. Download `google-services.json`
5. Put it in: `aethel_app/android/app/google-services.json`

## Step 3: Configure Android Build Files

### android/build.gradle.kts (or build.gradle)
Add classpath at top-level:
```groovy
dependencies {
    classpath 'com.android.tools.build:gradle:8.1.0'
    classpath 'org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.20'
    classpath 'com.google.gms:google-services:4.4.0'  // ← ADD THIS
}
```

### android/app/build.gradle.kts (or build.gradle)
Add at bottom:
```groovy
apply plugin: 'com.google.gms.google-services'
```

## Step 4: Initialize Firebase in Flutter

In `lib/main.dart`, add before `runApp()`:
```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // ... rest of your code
}
```

## Step 5: Run
```bash
flutter pub get
flutter run
```

## Push Notifications
- FCM tokens will be auto-collected by `firebase_messaging`
- Send tokens to your backend via `POST /devices/register`
- Backend already calls `sendPushNotification(userId, payload)` which logs to DB
- Real FCM delivery requires server key in Railway env vars (see below)
