import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStore {
  SecureKeyStore({required this.storage});
  final FlutterSecureStorage storage;
  static const _vaultKeyKey = 'aethel_vault_key';
  static const _saltKey = 'aethel_salt';

  Future<void> saveKey(Uint8List key, Uint8List salt) async {
    await storage.write(key: _vaultKeyKey, value: base64Encode(key));
    await storage.write(key: _saltKey, value: base64Encode(salt));
  }

  Future<Uint8List?> readKey() async {
    final encoded = await storage.read(key: _vaultKeyKey);
    return encoded == null ? null : base64Decode(encoded);
  }

  Future<bool> hasKey() async {
    return await storage.read(key: _vaultKeyKey) != null;
  }

  Future<void> clear() async {
    await storage.delete(key: _vaultKeyKey);
    await storage.delete(key: _saltKey);
  }
}
