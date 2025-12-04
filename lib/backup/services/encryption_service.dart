import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

const String _header = 'FINBAK_ENC_V1\x00\x00\x00';
const int _saltLength = 32;
const int _ivLength = 12;
const int _tagLength = 16;

// Top-level function for isolate-based decryption
void _decryptInIsolate(SendPort initialReplyTo) async {
  final port = ReceivePort();
  initialReplyTo.send(port.sendPort);
  await for (final message in port) {
    final transferable = message["data"] as TransferableTypedData;
    final data = transferable.materialize().asUint8List();
    final password = message["password"] as String;
    final replyPort = message["port"] as SendPort;
    try {
      final result = await _performDecryption(
        data,
        password,
        (p) => replyPort.send({"progress": p}),
      );
      replyPort.send({
        "result": TransferableTypedData.fromList([result]),
      });
    } catch (e, _) {
      replyPort.send({"error": e.toString()});
    }
  }
}

// Top-level function for isolate-based encryption
void _encryptInIsolate(SendPort initialReplyTo) async {
  final port = ReceivePort();
  initialReplyTo.send(port.sendPort);
  await for (final message in port) {
    final transferable = message["data"] as TransferableTypedData;
    final data = transferable.materialize().asUint8List();
    final password = message["password"] as String;
    final replyPort = message["port"] as SendPort;
    try {
      final result = await _performEncryption(
        data,
        password,
        (p) => replyPort.send({"progress": p}),
      );
      replyPort.send({
        "result": TransferableTypedData.fromList([result]),
      });
    } catch (e, _) {
      replyPort.send({"error": e.toString()});
    }
  }
}

/// Perform the actual decryption (runs in isolate)
Future<Uint8List> _performDecryption(
  Uint8List data,
  String password,
  Function(double) onProgress,
) async {
  var offset = 0;

  // Verify header
  final headerBytes = data.sublist(offset, offset + _header.length);
  final headerString = utf8.decode(headerBytes);
  if (headerString != _header) {
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

  // Derive key from password
  final key = _deriveKey(password, salt);

  // Setup cipher using AES-256-GCM
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

  // Decrypt in chunks
  const chunkSize = 64 * 1024; // 64 KB
  int processed = 0;
  int outOffset = 0;

  while (processed < encryptedData.length) {
    final remaining = encryptedData.length - processed;
    final size = remaining < chunkSize ? remaining : chunkSize;

    outOffset += cipher.processBytes(
      encryptedData,
      processed,
      size,
      decryptedData,
      outOffset,
    );

    processed += size;

    onProgress(processed / encryptedData.length);

    // Let isolate event loop breathe → allows sending updates
    if (processed % (4 * chunkSize) == 0) {
      // yield every few chunks
      await Future.microtask(() {});
    }
  }
  outOffset += cipher.doFinal(decryptedData, outOffset);

  onProgress(1.0);

  return decryptedData;
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

/// Perform the actual encryption (runs in isolate)
Future<Uint8List> _performEncryption(
  Uint8List data,
  String password,
  Function(double) onProgress,
) async {
  // Generate random salt and IV
  final secureRandom = _createSecureRandom();
  final salt = _generateRandomBytes(secureRandom, _saltLength);
  final iv = _generateRandomBytes(secureRandom, _ivLength);

  // Derive key from password
  final key = _deriveKey(password, salt);

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

  // Encrypt in chunks
  const chunkSize = 64 * 1024; // 64 KB
  int processed = 0;
  int outOffset = 0;

  while (processed < data.length) {
    final remaining = data.length - processed;
    final size = remaining < chunkSize ? remaining : chunkSize;

    outOffset += cipher.processBytes(
      data,
      processed,
      size,
      encryptedData,
      outOffset,
    );

    processed += size;

    onProgress(processed / data.length);

    // Let isolate event loop breathe → allows sending updates
    if (processed % (4 * chunkSize) == 0) {
      // yield every few chunks
      await Future.microtask(() {});
    }
  }
  outOffset += cipher.doFinal(encryptedData, outOffset);

  // Build final output: header + salt + IV + encrypted data (with tag)
  final output = BytesBuilder();
  output.add(utf8.encode(_header));
  output.add(salt);
  output.add(iv);
  output.add(encryptedData);

  return output.toBytes();
}

/// Service for encrypting and decrypting backup files
/// Uses AES-256-GCM with PBKDF2 key derivation
class EncryptionService {
  final log = Logger();

  Future<Uint8List> _runInIsolate(
    void Function(SendPort) entryPoint,
    Uint8List data,
    String password,
    Function(double) onProgress,
  ) async {
    // Run in a separate isolate to avoid blocking the UI
    final receivePort = ReceivePort();
    await Isolate.spawn(entryPoint, receivePort.sendPort);
    final SendPort isolateSendPort = await receivePort.first;

    final responsePort = ReceivePort();

    // Send the actual work request
    isolateSendPort.send({
      "data": TransferableTypedData.fromList([data]),
      "password": password,
      "port": responsePort.sendPort,
    });

    Uint8List? result;

    // Listen to messages (progress OR result)
    await for (final message in responsePort) {
      if (message is Map && message.containsKey("progress")) {
        onProgress(message["progress"]);
      }

      if (message is Map && message.containsKey("result")) {
        final t = message["result"] as TransferableTypedData;
        result = t.materialize().asUint8List();
        break; // Stop listening, we have the final data
      }

      if (message is Map && message.containsKey("error")) {
        throw Exception(message["error"]);
      }
    }

    if (result == null) {
      throw Exception('no result');
    }
    return result;
  }

  /// Encrypt data using AES-256-GCM
  /// Returns encrypted data with header, salt, IV, ciphertext, and auth tag
  Future<Uint8List> encrypt(
    Uint8List data,
    String password,
    Function(double) onProgress,
  ) async {
    try {
      log.i('Starting encryption in isolate...');
      final encryptedData = await _runInIsolate(
        _encryptInIsolate,
        data,
        password,
        onProgress,
      );
      log.i('Encryption completed: ${encryptedData.length} bytes');
      return encryptedData;
    } catch (e, stack) {
      log.e('Encryption failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Decrypt data using AES-256-GCM
  /// Expects data format: header + salt + IV + encrypted data (with tag)
  Future<Uint8List> decrypt(
    Uint8List data,
    String password,
    Function(double) onProgress,
  ) async {
    try {
      log.i('Starting decryption in isolate...');

      final decryptedData = await _runInIsolate(
        _decryptInIsolate,
        data,
        password,
        onProgress,
      );

      log.i('Decryption completed: ${decryptedData.length} bytes');
      return decryptedData;
    } catch (e, stack) {
      log.e('Decryption failed', error: e, stackTrace: stack);
      if (e.toString().contains('InvalidCipherTextException')) {
        throw Exception('Invalid password or corrupted data');
      }
      rethrow;
    }
  }

  /// Calculate SHA-256 checksum of data
  String calculateChecksum(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }
}
