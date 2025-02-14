import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// --- PBKDF2 Implementation ---
/// Derives a key from the given [password] and [salt] using HMAC-SHA256.
/// [iterations] specifies how many iterations to perform and [keyLength] is the desired output length in bytes.
Uint8List pbkdf2(
    String password, Uint8List salt, int iterations, int keyLength) {
  final passwordBytes = utf8.encode(password);
  final hmac = Hmac(sha256, passwordBytes);
  final int hLen = 32; // SHA-256 output size in bytes.
  final int l = (keyLength / hLen).ceil();
  final List<int> derivedKey = [];

  for (int i = 1; i <= l; i++) {
    // INT(i) in big-endian.
    final List<int> intBlock = [
      (i >> 24) & 0xff,
      (i >> 16) & 0xff,
      (i >> 8) & 0xff,
      i & 0xff
    ];
    // U1 = HMAC(password, salt || INT(i))
    List<int> U = hmac.convert(salt + intBlock).bytes;
    List<int> T = List.from(U);

    // Iterate and XOR.
    for (int j = 1; j < iterations; j++) {
      U = hmac.convert(U).bytes;
      for (int k = 0; k < T.length; k++) {
        T[k] ^= U[k];
      }
    }
    derivedKey.addAll(T);
  }
  return Uint8List.fromList(derivedKey.sublist(0, keyLength));
}
