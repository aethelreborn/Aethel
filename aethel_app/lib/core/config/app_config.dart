import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const appName = 'Aethel';
  static const version = '1.0.0';
  static const _apiBaseUrlOverride = String.fromEnvironment('AETHEL_API_URL');
  static const wsUrlOverride = String.fromEnvironment('AETHEL_WS_URL');

  /// Whether this build was compiled with an explicit vault server address.
  ///
  /// A shipped binary without one can only ever talk to the machine it runs
  /// on, so CI passes `--dart-define=AETHEL_API_URL=https://…` for every
  /// release artifact.
  static bool get hasConfiguredServer => _clean(_apiBaseUrlOverride).isNotEmpty;

  static String get apiBaseUrl {
    final override = _clean(_apiBaseUrlOverride);
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  /// Request paths already start with `/`, so a trailing slash in the
  /// configured server would produce `//auth/login`.
  static String _clean(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// WebSocket shares the HTTP server (path `/ws`) so one exposed port
  /// suffices on PaaS hosts; only an explicit override changes the target.
  static Uri get websocketUri {
    final override = _clean(wsUrlOverride);
    if (override.isNotEmpty) return Uri.parse(override);

    final api = Uri.parse(apiBaseUrl);
    final secure = api.scheme == 'https';
    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: api.host,
      port: api.hasPort ? api.port : (secure ? 443 : 80),
      path: '/ws',
    );
  }

  static const pbkdf2Iterations = 210000;
  static const vaultKeyLength = 32;
  static const minMasterPasswordLength = 10;
}
