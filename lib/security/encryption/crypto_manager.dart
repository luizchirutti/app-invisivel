import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';
import '../../core/constants/security_constants.dart';

/// Gerenciador centralizado de criptografia AES-256-GCM
class CryptoManager {
  static final CryptoManager _instance = CryptoManager._internal();

  factory CryptoManager() {
    return _instance;
  }

  CryptoManager._internal();

  /// Gera uma chave AES-256 criptograficamente segura
  static Uint8List generateAESKey() {
    final key = enc.Key.fromSecureRandom(32); // 256 bits = 32 bytes
    return key.bytes;
  }

  /// Gera um IV aleatório (96 bits para GCM)
  static Uint8List generateGCMIV() {
    final random = SecureRandom('Fortuna');
    return random.nextBytes(12); // 96 bits = 12 bytes
  }

  /// Encripta dados usando AES-256-GCM
  /// Retorna: base64(IV + Ciphertext + AuthTag)
  static String encryptAES256GCM(
    String plaintext,
    Uint8List keyBytes,
  ) {
    try {
      final key = enc.Key(keyBytes);
      final iv = generateGCMIV();
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      final encrypted = encrypter.encrypt(plaintext, iv: enc.IV(iv));

      // Combinar: IV (12 bytes) + Ciphertext + AuthTag (16 bytes)
      final combined = Uint8List(iv.length + encrypted.bytes.length);
      combined.setAll(0, iv);
      combined.setAll(iv.length, encrypted.bytes);

      return base64Encode(combined);
    } catch (e) {
      throw CryptoException('Erro ao encriptar: $e');
    }
  }

  /// Decripta dados AES-256-GCM
  /// Espera: base64(IV + Ciphertext + AuthTag)
  static String decryptAES256GCM(
    String encryptedData,
    Uint8List keyBytes,
  ) {
    try {
      final combined = base64Decode(encryptedData);

      if (combined.length < 28) {
        // Mínimo: 12 (IV) + 0 (ciphertext) + 16 (tag)
        throw CryptoException('Dados encriptados inválidos');
      }

      final key = enc.Key(keyBytes);
      final iv = combined.sublist(0, 12);
      final encryptedBytes = combined.sublist(12);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final decrypted =
          encrypter.decrypt(enc.Encrypted(encryptedBytes), iv: enc.IV(iv));

      return decrypted;
    } catch (e) {
      throw CryptoException('Erro ao decriptar: $e');
    }
  }

  /// Gera hash SHA-256
  static String hashSHA256(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Gera hash SHA-512
  static String hashSHA512(String input) {
    return sha512.convert(utf8.encode(input)).toString();
  }

  /// Gera HMAC-SHA256 para autenticação
  static String generateHMACSHA256(String data, String secretKey) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Deriva uma chave usando PBKDF2
  /// Útil para derivar chaves a partir de senhas
  static Uint8List derivePBKDF2Key({
    required String password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final pbkdf2 = KeyDerivator('SHA-256/HMAC/PBKDF2');
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }
}

/// Exceção de criptografia
class CryptoException implements Exception {
  final String message;

  CryptoException(this.message);

  @override
  String toString() => 'CryptoException: $message';
}

/// Gerenciador de armazenamento seguro de senhas/chaves
class SecureStorageManager {
  static final SecureStorageManager _instance =
      SecureStorageManager._internal();

  factory SecureStorageManager() {
    return _instance;
  }

  SecureStorageManager._internal();

  /// Calcula hash seguro de senha para validação
  static String hashPassword(String password) {
    // Usar PBKDF2 com salt aleatório
    final salt = CryptoManager.generateGCMIV();
    final derivedKey = CryptoManager.derivePBKDF2Key(
      password: password,
      salt: salt,
      iterations: 100000, // OWASP recomenda 100k+
      keyLength: 32,
    );

    // Retornar salt + hash em base64
    final combined = Uint8List(salt.length + derivedKey.length);
    combined.setAll(0, salt);
    combined.setAll(salt.length, derivedKey);

    return base64Encode(combined);
  }

  /// Verifica senha contra hash armazenado
  static bool verifyPassword(String password, String hashWithSalt) {
    try {
      final decoded = base64Decode(hashWithSalt);
      final salt = decoded.sublist(0, 12);
      final storedHash = decoded.sublist(12);

      final derivedKey = CryptoManager.derivePBKDF2Key(
        password: password,
        salt: salt,
        iterations: 100000,
        keyLength: 32,
      );

      // Comparação constant-time para evitar timing attacks
      return _constantTimeEqual(derivedKey, storedHash);
    } catch (e) {
      return false;
    }
  }

  /// Comparação constant-time de bytes (evita timing attacks)
  static bool _constantTimeEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
