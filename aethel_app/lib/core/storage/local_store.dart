import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models.dart';
import '../crypto/crypto_service.dart';

class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  static const _snapshotKey = 'aethel.snapshot.v1';

  SharedPreferences? _prefs;
  Uint8List? _key;
  AppSnapshot _snapshot = AppSnapshot.empty();
  bool _open = false;

  bool get isOpen => _open && _key != null;
  AppSnapshot get snapshot => _snapshot;

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  /// Opens the local snapshot with [key]. Returns false when a snapshot exists
  /// but cannot be decrypted, which means the key is wrong.
  Future<bool> open(Uint8List key) async {
    _key = Uint8List.fromList(key);
    final prefs = _prefs;
    if (prefs == null) throw StateError('LocalStore.init must be called first');

    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) {
      _snapshot = AppSnapshot.empty();
      _open = true;
      return true;
    }

    try {
      final decoded = CryptoService.decryptString(raw, _key!);
      final json = jsonDecode(decoded);
      if (json is! Map) throw const FormatException('Invalid snapshot');
      _snapshot = AppSnapshot.fromJson(Map<String, dynamic>.from(json));
      _open = true;
      return true;
    } catch (_) {
      _snapshot = AppSnapshot.empty();
      _open = false;
      _key = null;
      return false;
    }
  }

  void close() {
    _key = null;
    _snapshot = AppSnapshot.empty();
    _open = false;
  }

  Future<void> save() async {
    final key = _key;
    final prefs = _prefs;
    if (!_open || key == null || prefs == null) return;
    final encrypted =
        CryptoService.encryptString(jsonEncode(_snapshot.toJson()), key);
    await prefs.setString(_snapshotKey, encrypted.ciphertext);
  }

  Future<void> replace(AppSnapshot snapshot) async {
    _snapshot = snapshot;
    await save();
  }

  Future<void> rekey(Uint8List newKey) async {
    if (!_open) return;
    _key = Uint8List.fromList(newKey);
    await save();
  }

  Future<void> wipe() async {
    close();
    await _prefs?.remove(_snapshotKey);
  }

  /// Used only by the sync layer to seal outgoing payloads. The key never
  /// leaves this process.
  Uint8List? exportKeyForSync() {
    final key = _key;
    return key == null ? null : Uint8List.fromList(key);
  }

  String? exportEncryptedBackup({required String accountLabel}) {
    final prefs = _prefs;
    final raw = prefs?.getString(_snapshotKey);
    if (raw == null) return null;
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'aethel-backup-v1',
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'account': accountLabel,
      'cipher': 'AES-256-GCM',
      'kdf': 'PBKDF2-HMAC-SHA256',
      'snapshot': raw,
    });
  }
}
