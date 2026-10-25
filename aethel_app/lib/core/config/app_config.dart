import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const appName = 'Aethel';
  static const version = '1.0.0';
  static const _apiBaseUrlOverride = String.fromEnvironment('AETHEL_API_URL');
  static const wsUrlOverride = String.fromEnvironment('AETHEL_WS_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static Uri get websocketUri {
    if (wsUrlOverride.isNotEmpty) return Uri.parse(wsUrlOverride);

    final api = Uri.parse(apiBaseUrl);
    final secure = api.scheme == 'https';
    final port = api.hasPort
        ? (api.port == 3000 ? 3001 : api.port)
        : (secure ? 443 : 3001);

    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: api.host,
      port: port,
    );
  }

  static const pbkdf2Iterations = 210000;
  static const vaultKeyLength = 32;
  static const minMasterPasswordLength = 10;
}
