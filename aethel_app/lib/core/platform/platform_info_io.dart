import 'dart:io';

bool get isWebPlatform => false;
bool get isAndroidPlatform => Platform.isAndroid;
bool get isIOSPlatform => Platform.isIOS;
bool get isMacOSPlatform => Platform.isMacOS;
bool get isWindowsPlatform => Platform.isWindows;
bool get isLinuxPlatform => Platform.isLinux;

String get platformName => Platform.operatingSystem;
