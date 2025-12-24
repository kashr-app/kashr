import 'dart:io';

import 'package:kashr/backup/model/backup_config.dart';
import 'package:kashr/backup/model/backup_metadata.dart';
import 'package:kashr/backup/services/backup_service.dart';
import 'package:kashr/backup/services/webdav_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Service for managing Nextcloud backup operations
class NextcloudService {
  final FlutterSecureStorage _secureStorage;
  final Logger log;

  NextcloudService(this._secureStorage, this.log);

  /// Create WebDAV client from config
  Future<WebDavClient> _createClient(NextcloudConfig config) async {
    try {
      final password = await _secureStorage.read(key: config.passwordKey);
      if (password == null) {
        throw Exception('No password found for Nextcloud config');
      }

      return WebDavClient(
        baseUrl: config.url,
        username: config.username,
        password: password,
        log: log,
      );
    } catch (e, stack) {
      log.e('Failed to create WebDAV client', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Test connection to Nextcloud
  Future<bool> testConnection(NextcloudConfig config) async {
    final client = await _createClient(config);
    return await client.testConnection();
  }

  /// Upload backup to Nextcloud
  Future<void> uploadBackup(
    NextcloudConfig config,
    BackupMetadata backup, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final client = await _createClient(config);

    if (backup.localPath == null) {
      throw Exception('Backup has no local path');
    }

    final filename = _getBackupFilename(backup);
    final remotePath = '${config.backupPath}$filename';

    await client.uploadFile(
      backup.localPath!,
      remotePath,
      onProgress: onProgress,
    );
    log.i('Uploaded backup to Nextcloud: $filename');
  }

  /// List all backup files on Nextcloud
  Future<List<String>> listBackupsOnCloud(NextcloudConfig config) async {
    final client = await _createClient(config);
    final files = await client.listDirectory(config.backupPath);
    final backupFiles = files.where((f) => f.endsWith('.$backupFileExt'));
    return backupFiles.toList();
  }

  String _getBackupFilename(BackupMetadata backup) {
    return BackupService.createFilename(backup.createdAt);
  }

  /// Download backup from Nextcloud
  Future<File> downloadBackup(
    NextcloudConfig config,
    String filename,
    Directory backupsDir, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final client = await _createClient(config);

    final remotePath = '${config.backupPath}$filename';

    if (!await client.fileExists(remotePath)) {
      throw Exception('File not found on remote: $remotePath');
    }

    final destination = File('${backupsDir.path}/$filename');
    if (destination.existsSync()) {
      throw Exception('Local file already exists.');
    }

    await client.downloadFile(remotePath, destination, onProgress: onProgress);

    log.i('Downloaded backup from Nextcloud: $filename');
    return destination;
  }
}
