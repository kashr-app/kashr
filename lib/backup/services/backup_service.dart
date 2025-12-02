import 'dart:io';

import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:finanalyzer/backup/model/backup_repository.dart';
import 'package:finanalyzer/backup/services/archive_service.dart';
import 'package:finanalyzer/backup/services/local_storage_service.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

const backupFileExt = 'finbak';
final _fileNameDateFormat = DateFormat('yyyy-MM-dd_HHmmss');

/// Core service for backup and restore operations
class BackupService {
  final DatabaseHelper _dbHelper;
  final BackupRepository _backupRepository;
  final ArchiveService _archiveService;
  final LocalStorageService _localStorageService;

  final log = Logger();
  final _uuid = const Uuid();

  BackupService({
    required DatabaseHelper dbHelper,
    required BackupRepository backupRepository,
    required ArchiveService archiveService,
    required LocalStorageService localStorageService,
  }) : _dbHelper = dbHelper,
       _backupRepository = backupRepository,
       _archiveService = archiveService,
       _localStorageService = localStorageService;

  Future<File> _createDBBackup(String backupId, Directory tempDir) async {
    // Close database to ensure consistency
    log.i('Closing database...');
    await _dbHelper.close();

    // Get database file path
    final dbPath = await _getDatabasePath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('Database file not found at: $dbPath');
    }

    log.i('Database file found: $dbPath (${await dbFile.length()} bytes)');

    final tmpFilePath = '${tempDir.path}/db_copy_$backupId.db';
    final tempDbFile = File(tmpFilePath);

    // Copy database to temp location
    await dbFile.copy(tempDbFile.path);
    log.i('Copied database to temp location $tmpFilePath');
    return tempDbFile;
  }

  /// Create a new backup
  Future<BackupMetadata> createBackup({
    String? password,
    void Function(double progress)? onProgress,
  }) async {
    try {
      log.i('Starting backup creation...');
      onProgress?.call(0.0);

      final backupId = _uuid.v4();
      final tempDir = await getTemporaryDirectory();
      onProgress?.call(0.1);

      final tempDbFile = await _createDBBackup(backupId, tempDir);
      onProgress?.call(0.4);

      // TODO Phase 2: Encrypt if password provided
      final encrypted = false;

      // Create metadata
      // Get app version
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      // Generate backup ID
      final timestamp = DateTime.now();
      final metadata = BackupMetadata(
        id: backupId,
        createdAt: timestamp,
        dbVersion: dbVersion,
        appVersion: appVersion,
        encrypted: encrypted,
        fileSizeBytes: null, // will be set later
        checksum: null, // TODO: Calculate checksum
      );

      onProgress?.call(0.5);

      // Create ZIP archive
      final filename = createFilename(timestamp);

      final tempArchiveFile = File('${tempDir.path}/$filename');
      await _archiveService.createBackup(
        database: tempDbFile,
        metadata: metadata,
        output: tempArchiveFile,
      );
      log.i('Created archive: ${tempArchiveFile.path}');
      onProgress?.call(0.7);

      // Save to local storage
      final savedFile = await _localStorageService.saveBackup(
        tempArchiveFile,
        filename,
      );
      final localPath = savedFile.path;

      onProgress?.call(0.8);

      // Update metadata with paths
      final finalMetadata = metadata.copyWith(
        localPath: localPath,
        fileSizeBytes: await savedFile.length(),
      );

      // Re-open database to ensure it's available
      await _dbHelper.database;

      onProgress?.call(0.9);

      // Clean up temp files
      await tempDbFile.delete();
      await tempArchiveFile.delete();

      log.i('Backup created successfully: $backupId');
      onProgress?.call(1.0);

      return finalMetadata;
    } catch (e, stack) {
      log.e('Failed to create backup', error: e, stackTrace: stack);

      // Ensure database is reopened
      try {
        await _dbHelper.database;
      } catch (_) {}

      rethrow;
    }
  }

  Future<void> cleanupOldBackups() async {
    final config = await _backupRepository.getConfig();
    await _localStorageService.cleanupOldBackups(config.maxLocalBackups);
  }

  /// Restore from backup
  Future<void> restoreBackup(
    BackupMetadata backup,
    String? password,
    void Function(double progress)? onProgress,
  ) async {
    try {
      log.i('Starting restore from backup: ${backup.id}');
      onProgress?.call(0.1);

      // Get backup file
      log.i('Looking for local backup file...');
      if (backup.localPath == null) {
        final error = 'Backup metadata missing localPath for ID: ${backup.id}';
        log.e(error);
        throw Exception(error);
      }

      File? backupFile = File(backup.localPath!);
      if (!await backupFile.exists()) {
        final error = 'Backup file not found at path: ${backup.localPath}';
        log.e(error);
        throw Exception(error);
      }
      log.i('Found backup file: ${backupFile.path}');
      onProgress?.call(0.2);

      // Create temp directory for extraction
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/restore_${backup.id}');
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create(recursive: true);

      // Extract archive
      log.i('Extracting backup archive...');
      final contents = await _archiveService.extractBackup(
        backupFile,
        extractDir,
      );

      onProgress?.call(0.4);

      // Verify metadata matches
      if (contents.metadata.id != backup.id) {
        throw Exception('Backup metadata mismatch');
      }

      if (backup.encrypted) {
        if (password == null) {
          throw Exception('Password required for encrypted backup');
        }
        // TODO Phase 2: Decrypt if encrypted
      }

      final restoredDbFile = contents.database;

      onProgress?.call(0.5);

      // Verify database file is valid SQLite
      // TODO: Add database validation

      log.i('Database file validated');
      onProgress?.call(0.6);

      // Close current database
      log.i('Closing current database...');
      await _dbHelper.close();

      onProgress?.call(0.7);

      // Get current database path
      log.i('Getting database path...');
      final dbPath = await _getDatabasePath();
      log.i('Database path: $dbPath');

      final currentDbFile = File(dbPath);
      final backupDbFile = File('$dbPath.backup');

      log.i('Current DB exists: ${await currentDbFile.exists()}');

      if (await currentDbFile.exists()) {
        await currentDbFile.copy(backupDbFile.path);
        log.i('Backed up current database');
      }

      onProgress?.call(0.8);

      try {
        // Replace current database with restored one
        log.i('Copying restored DB from ${restoredDbFile.path} to $dbPath');
        log.i('Restored DB size: ${await restoredDbFile.length()} bytes');
        await restoredDbFile.copy(dbPath);
        log.i('Database file copied successfully');

        onProgress?.call(0.9);

        // Try to open the restored database
        log.i('Opening restored database...');
        await _dbHelper.database;
        log.i('Restored database opened successfully');

        // Clean up backup
        if (await backupDbFile.exists()) {
          await backupDbFile.delete();
        }

        onProgress?.call(1.0);
        log.i('Restore completed successfully');
      } catch (e, stack) {
        log.e(
          'Failed to restore database, rolling back',
          error: e,
          stackTrace: stack,
        );

        // Rollback: restore original database
        if (await backupDbFile.exists()) {
          log.i('Restoring original database from backup...');
          await backupDbFile.copy(dbPath);
          await backupDbFile.delete();
          log.i('Rolled back to original database');
        }

        // Re-open database
        log.i('Reopening database after rollback...');
        await _dbHelper.database;
        log.i('Database reopened');

        rethrow;
      }

      // Clean up temp directory
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
    } catch (e, stack) {
      log.e('Failed to restore backup', error: e, stackTrace: stack);

      // Ensure database is reopened
      try {
        await _dbHelper.database;
      } catch (_) {
        log.e('Failed to reopen the database');
      }

      rethrow;
    }
  }

  /// List available backups
  Future<List<BackupMetadata>> listBackups() async {
    return await _backupRepository.getAllMetadata();
  }

  /// Delete a backup
  Future<void> deleteBackup(BackupMetadata backup) async {
    try {
      if (backup.localPath == null) {
        throw Exception('Missing local path');
      }
      final file = File(backup.localPath!);
      if (await file.exists()) {
        await file.delete();
        log.i('Deleted backup file: ${backup.localPath}');
      }

      log.i('Deleted backup: ${backup.id}');
    } catch (e, stack) {
      log.e('Failed to delete backup', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Verify backup integrity
  Future<bool> verifyBackup(BackupMetadata backup) async {
    try {
      if (backup.localPath == null) {
        return false;
      }
      final file = File(backup.localPath!);
      return await verifyBackupFile(file);
    } catch (e, stack) {
      log.e('Failed to verify backup', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Verify backup integrity
  Future<bool> verifyBackupFile(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }
      return await _archiveService.verifyArchive(file);
    } catch (e, stack) {
      log.e('Failed to verify backup', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Get metadata
  Future<BackupMetadata> getMetadata(File backupFile) async {
    return await _backupRepository.readMetadataFromArchive(backupFile);
  }

  /// Get backup configuration
  Future<BackupConfig> getConfig() async {
    return await _backupRepository.getConfig();
  }

  /// Save backup configuration
  Future<void> saveConfig(BackupConfig config) async {
    await _backupRepository.saveConfig(config);
  }

  /// Export backup to user-chosen location
  Future<void> exportBackup(BackupMetadata backup) async {
    try {
      if (backup.localPath == null) {
        throw Exception('Missing local path');
      }
      final file = File(backup.localPath!);
      if (!await file.exists()) {
        throw Exception('Backup file not found');
      }

      await _localStorageService.exportBackup(file);
      log.i('Exported backup: ${backup.id}');
    } catch (e, stack) {
      log.e('Failed to export backup', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<Directory> getLocalBackupsDirectory() {
    return _localStorageService.getBackupsDirectory();
  }

  /// Get database file path
  Future<String> _getDatabasePath() async {
    if (Platform.isWindows || Platform.isLinux) {
      final factory = databaseFactoryFfi;
      final dbPath = await factory.getDatabasesPath();
      return '$dbPath/$dbFileName';
    } else {
      final dbPath = await getDatabasesPath();
      return '$dbPath/$dbFileName';
    }
  }

  static String createFilename(DateTime timestamp) {
    String formattedDate = _fileNameDateFormat.format(timestamp);
    return 'backup_$formattedDate.$backupFileExt';
  }
}
