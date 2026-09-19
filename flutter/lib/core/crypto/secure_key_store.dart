import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'kdf_service.dart';

class SecureKeyStore {
  SecureKeyStore({required this.storage});
  final FlutterSecureStorage storage;

  // Secure storage key names
  static const _aesKeyStoreKey = 'aethel_aes_key';
  static const _saltStoreKey = 'aethel_salt';

  Future<void> saveKey(Uint8List key, Uint8List salt) async {
    await storage.write(key: _aesKeyStoreKey, value: base64Encode(key));
    await storage.write(key: _saltStoreKey, value: base64Encode(salt));
  }

  Future<Uint8List?> readKey() async {
    final encoded = await storage.read(key: _aesKeyStoreKey);
    return encoded == null ? null : base64Decode(encoded);
  }

  Future<bool> hasKey() async {
    return await storage.read(key: _aesKeyStoreKey) != null;
  }

  Future<void> clear() async {
    await storage.delete(key: _aesKeyStoreKey);
    await storage.delete(key: _saltStoreKey);
  }

  /// Stores a newly derived AES-256 key after master-password setup.
  /// Derives the key via [KdfService] with a fresh random salt.
  Future<void> storeDerivedKey(String password) async {
    final salt = KdfService.generateSalt();
    final key = KdfService.deriveKey(password, salt);
    await saveKey(key, salt);
  }

  /// Reads the stored salt, prompts biometric auth, derives and returns
  /// the AES key. Returns null when no key exists yet or biometric fails.
  Future<Uint8List?> getDerivedKey() async {
    final saltEncoded = await storage.read(key: _saltStoreKey);
    if (saltEncoded == null) return null;

    final authenticated = await LocalAuthentication().authenticate(
      localizedReason: 'Authenticate to unlock your vault',
      options: const AuthenticationOptions(biometricOnly: false),
    );
    if (!authenticated) return null;

    final salt = base64Decode(saltEncoded);
    return KdfService.deriveKey('', salt);
  }
}
