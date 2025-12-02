import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:finanalyzer/backup/services/local_storage_service.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:logger/logger.dart';

/// Repository for managing backup metadata and configuration
class BackupRepository {
  final LocalStorageService _localStorageService;
  final log = Logger();

  BackupRepository({required LocalStorageService localStorageService})
    : _localStorageService = localStorageService;

  /// Get all backup metadata by reading from archive files
  Future<List<BackupMetadata>> getAllMetadata() async {
    try {
      final backupFiles = await _localStorageService.getAllBackupFiles();
      final metadataList = <BackupMetadata>[];

      for (final file in backupFiles) {
        try {
          final metadata = await _readMetadataFromArchive(file);
          metadataList.add(metadata.copyWith(fileSizeBytes: file.lengthSync()));
        } catch (e) {
          log.w('Failed to read metadata from ${file.path}: $e');
          // Continue with other files
        }
      }

      // Sort by creation date (newest first)
      metadataList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return metadataList;
    } catch (e, stack) {
      log.e('Failed to get all metadata', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Read metadata from a backup archive file
  Future<BackupMetadata> readMetadataFromArchive(File backupFile) async {
    if (!backupFile.existsSync()) {
      throw Exception('File not found ${backupFile.path}');
    }
    return _readMetadataFromArchive(backupFile);
  }

  /// Read metadata from a backup archive file
  Future<BackupMetadata> _readMetadataFromArchive(File backupFile) async {
    final bytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final metadataFile = archive.findFile('metadata.json');
    if (metadataFile == null) {
      throw Exception(
        'Backup archive missing metadata.json: ${backupFile.path}',
      );
    }

    final metadataJson = utf8.decode(metadataFile.content as List<int>);
    final metadataMap = jsonDecode(metadataJson) as Map<String, dynamic>;
    final metadata = BackupMetadata.fromJson(metadataMap);

    // Set the localPath to the actual file path
    // (metadata in archive doesn't have this as it's set after archive creation)
    return metadata.copyWith(
      localPath: backupFile.path,
      fileSizeBytes: backupFile.lengthSync(),
    );
  }

  /// Get backup configuration
  Future<BackupConfig> getConfig() async {
    final db = await DatabaseHelper().database;
    final results = await db.query('backup_config', where: 'id = 1');

    if (results.isEmpty) {
      // Return default config if not found
      return const BackupConfig();
    }

    final map = results.first;
    return BackupConfig(
      autoBackupEnabled: map['auto_backup_enabled'] == 1,
      frequency: BackupFrequency.values.firstWhere(
        (f) => f.name == map['backup_frequency'],
        orElse: () => BackupFrequency.weekly,
      ),
      lastAutoBackup: map['last_auto_backup'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_auto_backup'] as int)
          : null,
      encryptionEnabled: map['encryption_enabled'] == 1,
      maxLocalBackups: map['max_local_backups'] as int,
      autoBackupToCloud: map['auto_backup_to_cloud'] == 1,
    );
  }

  /// Save backup configuration
  Future<void> saveConfig(BackupConfig config) async {
    final db = await DatabaseHelper().database;
    await db.update('backup_config', {
      'auto_backup_enabled': config.autoBackupEnabled ? 1 : 0,
      'backup_frequency': config.frequency.name,
      'last_auto_backup': config.lastAutoBackup?.millisecondsSinceEpoch,
      'encryption_enabled': config.encryptionEnabled ? 1 : 0,
      'max_local_backups': config.maxLocalBackups,
      'auto_backup_to_cloud': config.autoBackupToCloud ? 1 : 0,
    }, where: 'id = 1');
  }
}
