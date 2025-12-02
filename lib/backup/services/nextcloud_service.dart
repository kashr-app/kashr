import 'dart:io';

import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:finanalyzer/backup/services/backup_service.dart';
import 'package:finanalyzer/backup/services/webdav_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Service for managing Nextcloud backup operations
class NextcloudService {
  final FlutterSecureStorage _secureStorage;
  final log = Logger();

  NextcloudService(this._secureStorage);

  /// Create WebDAV client from config
  Future<WebDavClient?> _createClient(NextcloudConfig config) async {
    try {
      final password = await _secureStorage.read(key: config.passwordKey);
      if (password == null) {
        log.w('No password found for Nextcloud config');
        return null;
      }

      return WebDavClient(
        baseUrl: config.url,
        username: config.username,
        password: password,
      );
    } catch (e, stack) {
      log.e('Failed to create WebDAV client', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Test connection to Nextcloud
  Future<bool> testConnection(NextcloudConfig config) async {
    final client = await _createClient(config);
    if (client == null) return false;

    return await client.testConnection();
  }

  /// Check if a backup exists on Nextcloud
  Future<bool> backupExistsOnCloud(
    NextcloudConfig config,
    BackupMetadata backup,
  ) async {
    final client = await _createClient(config);
    if (client == null) return false;

    final filename = _getBackupFilename(backup);
    final remotePath = '${config.backupPath}$filename';

    return await client.fileExists(remotePath);
  }

  /// Upload backup to Nextcloud
  Future<void> uploadBackup(
    NextcloudConfig config,
    BackupMetadata backup,
  ) async {
    final client = await _createClient(config);
    if (client == null) {
      throw Exception('Failed to create Nextcloud client');
    }

    if (backup.localPath == null) {
      throw Exception('Backup has no local path');
    }

    final filename = _getBackupFilename(backup);
    final remotePath = '${config.backupPath}$filename';

    await client.uploadFile(backup.localPath!, remotePath);
    log.i('Uploaded backup to Nextcloud: $filename');
  }

  /// List all backup files on Nextcloud
  Future<List<String>> listBackupsOnCloud(NextcloudConfig config) async {
    final client = await _createClient(config);
    if (client == null) return [];

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
    Directory backupsDir,
  ) async {
    final client = await _createClient(config);
    if (client == null) {
      throw Exception('Failed to create Nextcloud client');
    }

    final remotePath = '${config.backupPath}$filename';

    if (!await client.fileExists(remotePath)) {
      throw Exception('File not found on remote: $remotePath');
    }

    final destination = File('${backupsDir.path}/$filename');
    if (destination.existsSync()) {
      throw Exception('Local file already exists.');
    }

    await client.downloadFile(remotePath, destination);

    log.i('Downloaded backup from Nextcloud: $filename');
    return destination;
  }
}
