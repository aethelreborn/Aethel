import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import '../config/app_config.dart';

class DerivedKeys {
  const DerivedKeys({required this.verifier, required this.vaultKey});

  /// Sent to the server in place of the master password.
  final String verifier;

  /// Never leaves this device. Encrypts the local snapshot and item payloads.
  final Uint8List vaultKey;
}

class EncryptedValue {
  const EncryptedValue({required this.ciphertext, required this.iv});

  /// Base64 of `iv || ciphertext || gcmTag`.
  final String ciphertext;

  /// Base64 of the 12-byte IV, sent separately because the API expects it.
  final String iv;
}

class CryptoService {
  const CryptoService._();

  static const keyCheckPlaintext = 'aethel.vault.keycheck.v1';
  static const _ivLength = 12;
  static const _tagBits = 128;

  static Future<DerivedKeys> deriveKeys({
    required String email,
    required String masterPassword,
  }) async {
    final result = await compute(_deriveKeysInBackground, <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'password': masterPassword,
    });
    return DerivedKeys(
      verifier: result['verifier'] as String,
      vaultKey: result['key'] as Uint8List,
    );
  }

  static Map<String, dynamic> _deriveKeysInBackground(
      Map<String, dynamic> input) {
    final email = (input['email'] as String).trim().toLowerCase();
    final password = input['password'] as String;
    final salt = SHA256Digest().process(
      Uint8List.fromList(utf8.encode('aethel.v1|$email')),
    );
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, AppConfig.pbkdf2Iterations, 64));
    final material =
        derivator.process(Uint8List.fromList(utf8.encode(password)));

    final verifierBytes = material.sublist(0, 32);
    final vaultKey = Uint8List.fromList(material.sublist(32, 64));
    final verifier = base64UrlEncode(verifierBytes).replaceAll('=', '');

    return <String, dynamic>{'verifier': verifier, 'key': vaultKey};
  }

  static EncryptedValue encryptString(String plaintext, Uint8List key) {
    final iv = randomBytes(_ivLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), _tagBits, iv, Uint8List(0)),
      );
    final encrypted =
        cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    final combined = Uint8List(iv.length + encrypted.length)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + encrypted.length, encrypted);

    return EncryptedValue(
      ciphertext: base64Encode(combined),
      iv: base64Encode(iv),
    );
  }

  static String decryptString(String ciphertext, Uint8List key) {
    final combined = base64Decode(ciphertext);
    if (combined.length <= _ivLength) {
      throw const FormatException('Ciphertext is too short');
    }
    final iv = combined.sublist(0, _ivLength);
    final encrypted = combined.sublist(_ivLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), _tagBits, iv, Uint8List(0)),
      );
    return utf8.decode(cipher.process(encrypted));
  }

  static String? tryDecryptString(String? ciphertext, Uint8List key) {
    if (ciphertext == null || ciphertext.isEmpty) return null;
    try {
      return decryptString(ciphertext, key);
    } catch (_) {
      return null;
    }
  }

  static EncryptedValue encryptJson(Object value, Uint8List key) =>
      encryptString(jsonEncode(value), key);

  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static bool constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    if (left.length != right.length) return false;
    var difference = 0;
    for (var i = 0; i < left.length; i++) {
      difference |= left[i] ^ right[i];
    }
    return difference == 0;
  }
}
