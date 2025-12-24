import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:kashr/backup/model/backup_metadata.dart';
import 'package:logger/logger.dart';

/// Contents extracted from a backup archive
class BackupContents {
  final BackupMetadata metadata;
  final File database;

  BackupContents({required this.metadata, required this.database});
}

/// Service for creating and extracting backup ZIP archives
class ArchiveService {
  final Logger log;

  ArchiveService(this.log);

  /// Create a ZIP archive
  /// Returns the output file
  Future<void> createBackup({
    required File database,
    required BackupMetadata metadata,
    required File output,
  }) async {
    try {
      final archive = Archive();

      // Add database file
      final dbBytes = await database.readAsBytes();
      final dbFile = ArchiveFile('database.db', dbBytes.length, dbBytes);
      archive.addFile(dbFile);

      // Add metadata.json
      final metadataJson = jsonEncode(metadata.toJson());
      final metadataBytes = utf8.encode(metadataJson);
      final metadataFile = ArchiveFile(
        'metadata.json',
        metadataBytes.length,
        metadataBytes,
      );
      archive.addFile(metadataFile);

      // Create ZIP file
      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);

      // Write to output file
      await output.writeAsBytes(zipBytes);

      log.i('Created backup archive: ${output.path}');
    } catch (e, stack) {
      log.e('Failed to create backup archive', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Verify archive integrity
  /// Returns true if valid
  Future<bool> verifyArchive(File backupFile) async {
    try {
      final archive = await _readZip(backupFile);

      // Check required files exist
      final hasMetadata = archive.findFile('metadata.json') != null;
      final hasDatabase = archive.findFile('database.db') != null;

      return hasMetadata && hasDatabase;
    } catch (e, stack) {
      log.e('Failed to verify archive', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Extract the metadata of a ZIP archive
  Future<BackupMetadata> extractMetadata(File backupFile) async {
    return _extractMetadata(await _readZip(backupFile));
  }

  /// Extract a ZIP archive
  /// Returns the backup contents
  Future<BackupContents> extractBackup(
    File backupFile,
    Directory tempDir,
  ) async {
    try {
      final archive = await _readZip(backupFile);
      final metadata = await _extractMetadata(archive);
      final db = await _extractDatabase(archive, tempDir);

      log.i('Extracted backup archive to ${tempDir.path}');

      return BackupContents(metadata: metadata, database: db);
    } catch (e, stack) {
      log.e('Failed to extract backup archive', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<Archive> _readZip(File backupFile) async {
    try {
      final bytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      return archive;
    } catch (e, stack) {
      log.e('Failed to read archive', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Extract the metadata of a ZIP archive
  Future<BackupMetadata> _extractMetadata(Archive archive) async {
    try {
      // Extract metadata.json
      final metadataFile = archive.findFile('metadata.json');
      if (metadataFile == null) {
        throw Exception('Backup archive missing metadata.json');
      }

      final metadataJson = utf8.decode(metadataFile.content as List<int>);
      final metadataMap = jsonDecode(metadataJson) as Map<String, dynamic>;
      final metadata = BackupMetadata.fromJson(metadataMap);

      return metadata;
    } catch (e, stack) {
      log.e(
        'Failed to extract metadata from backup archive',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<File> _extractDatabase(Archive archive, Directory tempDir) async {
    try {
      // Extract database.db
      final dbFile = archive.findFile('database.db');
      if (dbFile == null) {
        throw Exception('Backup archive missing database.db');
      }

      final dbPath = '${tempDir.path}/database.db';
      final dbOutputFile = File(dbPath);
      await dbOutputFile.writeAsBytes(dbFile.content as List<int>);

      log.i('Extracted backup database archive to $dbPath');

      return dbOutputFile;
    } catch (e, stack) {
      log.e(
        'Failed to extract database from archive',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
