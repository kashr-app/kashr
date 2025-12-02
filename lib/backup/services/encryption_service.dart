import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

/// Service for encrypting and decrypting backup files
/// Uses AES-256-GCM with PBKDF2 key derivation
class EncryptionService {
  static const String _header = 'FINBAK_ENC_V1\x00\x00\x00';
  static const int _saltLength = 32;
  static const int _ivLength = 12;
  static const int _tagLength = 16;

  final log = Logger();

  /// Encrypt data using AES-256-GCM
  /// Returns encrypted data with header, salt, IV, ciphertext, and auth tag
  Future<Uint8List> encrypt(Uint8List data, String password) async {
    try {
      log.i('Starting encryption...');

      // Generate random salt and IV
      final secureRandom = _createSecureRandom();
      final salt = _generateRandomBytes(secureRandom, _saltLength);
      final iv = _generateRandomBytes(secureRandom, _ivLength);

      log.i('Generated salt and IV');

      // Derive key from password using PBKDF2
      final key = _deriveKey(password, salt);
      log.i('Derived encryption key');

      // Encrypt data using AES-256-GCM
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        _tagLength * 8, // tag length in bits
        iv,
        Uint8List(0), // no additional authenticated data
      );

      cipher.init(true, params); // true = encrypt

      // Allocate output buffer (data + auth tag)
      final encryptedData = Uint8List(data.length + _tagLength);

      // Encrypt
      var offset = 0;
      offset += cipher.processBytes(data, 0, data.length, encryptedData, 0);
      offset += cipher.doFinal(encryptedData, offset);

      log.i('Encryption completed: ${encryptedData.length} bytes');

      // Build final output: header + salt + IV + encrypted data (with tag)
      final output = BytesBuilder();
      output.add(utf8.encode(_header));
      output.add(salt);
      output.add(iv);
      output.add(encryptedData);

      final result = output.toBytes();
      log.i('Total encrypted size: ${result.length} bytes');

      return result;
    } catch (e, stack) {
      log.e('Encryption failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Decrypt data using AES-256-GCM
  /// Expects data format: header + salt + IV + encrypted data (with tag)
  Future<Uint8List> decrypt(Uint8List data, String password) async {
    try {
      log.i('Starting decryption...');

      var offset = 0;

      // Verify header
      final headerBytes = data.sublist(offset, offset + _header.length);
      final header = utf8.decode(headerBytes);
      if (header != _header) {
        throw Exception('Invalid backup file header');
      }
      offset += _header.length;

      // Extract salt
      final salt = data.sublist(offset, offset + _saltLength);
      offset += _saltLength;

      // Extract IV
      final iv = data.sublist(offset, offset + _ivLength);
      offset += _ivLength;

      // Extract encrypted data (includes auth tag)
      final encryptedData = data.sublist(offset);

      log.i('Extracted salt, IV, and encrypted data');

      // Derive key from password
      final key = _deriveKey(password, salt);
      log.i('Derived decryption key');

      // Decrypt using AES-256-GCM
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        _tagLength * 8,
        iv,
        Uint8List(0),
      );

      cipher.init(false, params); // false = decrypt

      // Allocate output buffer
      final decryptedData = Uint8List(encryptedData.length - _tagLength);

      // Decrypt
      var decryptedOffset = 0;
      decryptedOffset += cipher.processBytes(
        encryptedData,
        0,
        encryptedData.length,
        decryptedData,
        0,
      );
      decryptedOffset += cipher.doFinal(decryptedData, decryptedOffset);

      log.i('Decryption completed: ${decryptedData.length} bytes');

      return decryptedData;
    } catch (e, stack) {
      log.e('Decryption failed', error: e, stackTrace: stack);
      if (e.toString().contains('mac check')) {
        throw Exception('Invalid password or corrupted data');
      }
      rethrow;
    }
  }

  /// Verify password without full decryption
  /// Tries to decrypt the first 1KB of data
  Future<bool> verifyPassword(Uint8List data, String password) async {
    try {
      // For GCM mode, we need to decrypt everything to verify the auth tag
      // So we just try to decrypt and catch any errors
      await decrypt(data, password);
      return true;
    } catch (e) {
      log.i('Password verification failed: ${e.toString()}');
      return false;
    }
  }

  /// Derive encryption key from password using Argon2id
  Uint8List _deriveKey(String password, Uint8List salt) {
    final params = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: 32, // 256 bits
      iterations: 3,
      memory: 1024 * 64, // Memory cost: 64 MiB
      lanes: 1, // threads
      version: Argon2Parameters.ARGON2_VERSION_13, // Use Argon2 version 13
    );

    // Instantiate the Argon2KeyDerivator
    final derivator = KeyDerivator("argon2");

    // Initialize the derivator with the parameters
    derivator.init(params);

    // Derive the key using the password
    final key = derivator.process(Uint8List.fromList(password.codeUnits));

    return key;
  }

  /// Create a secure random number generator
  FortunaRandom _createSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = <int>[];
    for (var i = 0; i < 32; i++) {
      seeds.add(random.nextInt(256));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Generate random bytes
  Uint8List _generateRandomBytes(SecureRandom random, int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextUint8();
    }
    return bytes;
  }

  /// Calculate SHA-256 checksum of data
  String calculateChecksum(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }
}
