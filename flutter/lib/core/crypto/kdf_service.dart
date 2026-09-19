import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class KdfService {
  KdfService._();
  static const int keyLength = 32;
  static const String info = 'aethel-vault-key-v1';

  static Uint8List generateSalt() {
    return SecureRandom('Fortuna').nextBytes(keyLength);
  }

  static Uint8List deriveKey(String password, Uint8List salt) {
    // Step 1: Extract — Hmac(salt, password) to produce PRK
    final hmac = HMac(SHA256Digest(), 32)..init(KeyParameter(salt));
    final prk = Uint8List(hmac.macSize);
    hmac.update(Uint8List.fromList(password.codeUnits), 0, password.codeUnits.length);
    hmac.doFinal(prk, 0);

    // Step 2: Expand — HKDF with PRK as IKM
    final hkdf = HKDFKeyDerivator(SHA256Digest())
      ..init(HkdfParameters(prk, keyLength, salt, Uint8List.fromList(info.codeUnits)));
    final out = Uint8List(keyLength);
    hkdf.deriveKey(null, 0, out, 0);
    return out;
  }
}
