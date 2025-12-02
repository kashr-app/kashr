import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:finanalyzer/backup/services/backup_service.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing local backup files
class LocalStorageService {
  final log = Logger();

  /// Get the app's backup directory
  Future<Directory> getBackupsDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory('${appDocDir.path}/backups');

    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
      log.i('Created backups directory: ${backupsDir.path}');
    }

    return backupsDir;
  }

  /// Save backup file to backups directory
  Future<File> saveBackup(File source, String filename) async {
    try {
      final backupsDir = await getBackupsDirectory();
      final destination = File('${backupsDir.path}/$filename');

      await source.copy(destination.path);

      log.i('Saved backup: ${destination.path}');
      return destination;
    } catch (e, stack) {
      log.e('Failed to save backup', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get backup file by ID
  Future<File?> getBackupFile(String backupId) async {
    try {
      final backupsDir = await getBackupsDirectory();
      final files = await backupsDir.list().toList();

      for (final entity in files) {
        if (entity is File && entity.path.contains(backupId)) {
          return entity;
        }
      }

      return null;
    } catch (e, stack) {
      log.e('Failed to get backup file', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Delete backup file by ID
  Future<void> deleteBackupFile(String backupId) async {
    try {
      final file = await getBackupFile(backupId);
      if (file != null && await file.exists()) {
        await file.delete();
        log.i('Deleted backup file: ${file.path}');
      }
    } catch (e, stack) {
      log.e('Failed to delete backup file', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Export backup to user-chosen location
  Future<void> exportBackup(File backup) async {
    try {
      // Read bytes first (required for Android/iOS)
      final bytes = await backup.readAsBytes();

      final result = await FilePicker.platform.saveFile(
        fileName: backup.path.split('/').last,
        bytes: bytes,
      );

      if (result != null) {
        log.i('Exported backup to: $result');
      } else {
        log.i('Export cancelled by user');
      }
    } catch (e, stack) {
      log.e('Failed to export backup', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Import backup from user-chosen location
  Future<File?> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [backupFileExt],
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        final sourceFile = File(sourcePath);

        // Copy to temp directory
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/${sourceFile.path.split('/').last}',
        );
        await sourceFile.copy(tempFile.path);

        log.i('Imported backup from: $sourcePath');
        return tempFile;
      }

      log.i('Import cancelled by user');
      return null;
    } catch (e, stack) {
      log.e('Failed to import backup', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Clean up old backups, keeping only the N most recent
  Future<void> cleanupOldBackups(int keepCount) async {
    try {
      final files = await getAllBackupFiles();

      if (files.length <= keepCount) {
        return; // Nothing to clean up
      }

      // Sort by modification date (newest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // Delete old backups beyond keepCount
      final filesToDelete = files.skip(keepCount);
      for (final file in filesToDelete) {
        await file.delete();
        log.i('Deleted old backup: ${file.path}');
      }

      log.i('Cleaned up old backups, kept $keepCount most recent');
    } catch (e, stack) {
      log.e('Failed to cleanup old backups', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get all backup files
  Future<List<File>> getAllBackupFiles() async {
    try {
      final backupsDir = await getBackupsDirectory();
      final files = await backupsDir
          .list()
          .where(
            (entity) =>
                entity is File && entity.path.endsWith('.$backupFileExt'),
          )
          .cast<File>()
          .toList();

      return files;
    } catch (e, stack) {
      log.e('Failed to get all backup files', error: e, stackTrace: stack);
      return [];
    }
  }
}
