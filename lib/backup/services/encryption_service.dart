import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

const String _header = 'FINBAK_ENC_V1\x00\x00\x00';
const int _saltLength = 32;
const int _ivLength = 12;
const int _tagLength = 16;

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
      final result = await _enrycpt(
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
      final result = await _decrypt(
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

/// Perform the actual encryption (runs in isolate)
Future<Uint8List> _enrycpt(
  Uint8List data,
  String password,
  Function(double) onProgress,
) async {
  // Generate random salt and IV
  final secureRandom = _createSecureRandom();
  final salt = _generateRandomBytes(secureRandom, _saltLength);
  final iv = _generateRandomBytes(secureRandom, _ivLength);

  final encryptedData = await _runCipher(
    true,
    data,
    password,
    salt,
    iv,
    onProgress,
  );
  // Build final output: header + salt + IV + encrypted data (with tag)
  final output = BytesBuilder();
  output.add(utf8.encode(_header));
  output.add(salt);
  output.add(iv);
  output.add(encryptedData);

  return output.toBytes();
}

/// Perform the actual decryption (runs in isolate)
Future<Uint8List> _decrypt(
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

  final salt = data.sublist(offset, offset + _saltLength);
  offset += _saltLength;

  final iv = data.sublist(offset, offset + _ivLength);
  offset += _ivLength;

  // Extract encrypted data (includes auth tag)
  final dataIn = data.sublist(offset);
  final dataOut = _runCipher(false, dataIn, password, salt, iv, onProgress);

  return dataOut;
}

/// Service for encrypting and decrypting backup files
/// Uses AES-256-GCM with PBKDF2 key derivation
class EncryptionService {
  final Logger log;

  EncryptionService(this.log);

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

Uint8List _generateRandomBytes(SecureRandom random, int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextUint8();
  }
  return bytes;
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

Future<Uint8List> _runCipher(
  bool encrypt,
  Uint8List dataIn,
  String password,
  Uint8List salt,
  Uint8List iv,
  Function(double) onProgress,
) async {
  final key = _deriveKey(password, salt);

  // Setup cipher using AES-256-GCM
  final cipher = GCMBlockCipher(AESEngine());
  final params = AEADParameters(
    KeyParameter(key),
    _tagLength * 8, // tag length in bits
    iv,
    Uint8List(0), // no additional authenticated data
  );

  cipher.init(encrypt, params); // true = encrypt

  // Allocate output buffer
  final dataOut = Uint8List(
    dataIn.length + (encrypt ? _tagLength : -_tagLength),
  );

  // Work in chunks
  const chunkSize = 64 * 1024; // 64 KB
  int processed = 0;
  int offset = 0;

  while (processed < dataIn.length) {
    final remaining = dataIn.length - processed;
    final size = remaining < chunkSize ? remaining : chunkSize;

    offset += cipher.processBytes(dataIn, processed, size, dataOut, offset);

    processed += size;

    onProgress(processed / dataIn.length);

    // Let isolate event loop breathe to allow sending updates
    if (processed % (4 * chunkSize) == 0) {
      await Future.microtask(() {});
    }
  }
  offset += cipher.doFinal(dataOut, offset);

  onProgress(1.0);
  return dataOut;
}
