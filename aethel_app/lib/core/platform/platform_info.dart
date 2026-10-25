import 'platform_info_stub.dart' if (dart.library.io) 'platform_info_io.dart'
    as impl;

bool get isWebPlatform => impl.isWebPlatform;
bool get isAndroidPlatform => impl.isAndroidPlatform;
bool get isIOSPlatform => impl.isIOSPlatform;
bool get isMacOSPlatform => impl.isMacOSPlatform;
bool get isWindowsPlatform => impl.isWindowsPlatform;
bool get isLinuxPlatform => impl.isLinuxPlatform;

bool get isMobilePlatform => isAndroidPlatform || isIOSPlatform;

bool get isDesktopPlatform =>
    isMacOSPlatform || isWindowsPlatform || isLinuxPlatform;

String get platformName => impl.platformName;
