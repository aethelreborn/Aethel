import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/platform_info.dart';

class SecureKeys {
  const SecureKeys._();

  static const access = 'aethel_access';
  static const refresh = 'aethel_refresh';
  static const vaultKey = 'aethel_vault_key';
  static const keyCheck = 'aethel_key_check';
  static const email = 'aethel_email';
  static const name = 'aethel_name';
}

class SecureStore {
  SecureStore(this._prefs);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _fallbackKeys = {
    SecureKeys.email,
    SecureKeys.name,
    SecureKeys.keyCheck,
  };

  bool _allowsFallback(String key) => _fallbackKeys.contains(key);

  Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) return value;
    } catch (_) {
      // Desktop keyrings can be unavailable. Only non-secret labels and the
      // encrypted key check may use the preferences fallback.
    }
    if (!_allowsFallback(key)) return null;
    return _prefs.getString('aethel.fallback.$key');
  }

  Future<bool> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      await _prefs.remove('aethel.fallback.$key');
      return true;
    } catch (_) {
      if (!_allowsFallback(key)) return false;
      await _prefs.setString('aethel.fallback.$key', value);
      return false;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Ignore unavailable keyrings; the fallback copy is removed below.
    }
    await _prefs.remove('aethel.fallback.$key');
  }

  Future<void> saveSession({
    required String access,
    required String refresh,
    required String email,
    String? name,
  }) async {
    await Future.wait([
      write(SecureKeys.access, access),
      write(SecureKeys.refresh, refresh),
      write(SecureKeys.email, email),
      if (name != null && name.trim().isNotEmpty)
        write(SecureKeys.name, name.trim()),
    ]);
  }

  Future<void> saveVaultKey(Uint8List key) async {
    await write(SecureKeys.vaultKey, base64Encode(key));
  }

  Future<Uint8List?> readVaultKey() async {
    final encoded = await read(SecureKeys.vaultKey);
    if (encoded == null) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveKeyCheck(String ciphertext) =>
      write(SecureKeys.keyCheck, ciphertext);

  Future<String?> readKeyCheck() => read(SecureKeys.keyCheck);

  Future<String?> readEmail() => read(SecureKeys.email);

  Future<String?> readName() => read(SecureKeys.name);

  Future<void> clearSession() async {
    await Future.wait([
      delete(SecureKeys.access),
      delete(SecureKeys.refresh),
      delete(SecureKeys.vaultKey),
      delete(SecureKeys.keyCheck),
      delete(SecureKeys.email),
      delete(SecureKeys.name),
    ]);
  }

  Future<void> clearTokens() async {
    await Future.wait([delete(SecureKeys.access), delete(SecureKeys.refresh)]);
  }
}

class BiometricService {
  const BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static bool get platformSupportsBiometrics =>
      isMobilePlatform || isMacOSPlatform || isWindowsPlatform;

  static Future<bool> isAvailable() async {
    if (!platformSupportsBiometrics) return false;
    try {
      if (await _auth.isDeviceSupported()) return true;
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    if (!platformSupportsBiometrics) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
