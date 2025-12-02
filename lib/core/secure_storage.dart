import 'package:flutter_secure_storage/flutter_secure_storage.dart';

FlutterSecureStorage secureStorage() => FlutterSecureStorage(
  aOptions: const AndroidOptions(encryptedSharedPreferences: true),
);
