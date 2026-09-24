import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class AesService {
  AesService._();
  static const int keyLength = 32;
  static const int ivLength = 12;
  static const int tagBits = 128;

  static String encrypt(Uint8List key, String plaintext) {
    final iv = _randomBytes(ivLength);
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(true, AEADParameters(KeyParameter(key), tagBits, iv, Uint8List(0)));
    final plainBytes = Uint8List.fromList(plaintext.codeUnits);
    final out = cipher.process(plainBytes);
    final combined = Uint8List(out.length + iv.length);
    combined.setRange(0, out.length, out);
    combined.setRange(out.length, out.length + iv.length, iv);
    return base64Encode(combined);
  }

  static String decrypt(Uint8List key, String encryptedBase64) {
    final data = base64Decode(encryptedBase64);
    final iv = data.sublist(data.length - ivLength);
    final ct = data.sublist(0, data.length - ivLength);
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(false, AEADParameters(KeyParameter(key), tagBits, iv, Uint8List(0)));
    return String.fromCharCodes(cipher.process(ct));
  }

  static Uint8List _randomBytes(int n) {
    return SecureRandom('Fortuna').nextBytes(n);
  }
}
