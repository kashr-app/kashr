import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:kashr/logging/model/log_entry.dart';
import 'package:kashr/logging/model/log_level_setting.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LogService {
  late final Logger log;

  /// Prefer using `context.read<LogService>()`.
  static LogService? instance;

  LogService() {
    log = Logger(
      level: Level.all,
      output: LogServiceOutput(this),
      printer: PrettyPrinter(colors: false),
      filter: ProductionFilter(),
    );
    instance = this;
  }

  LogLevelSetting _currentLogLevel = LogLevelSetting.error;
  File? _logFile;
  final _maxFileSize = 5 * 1024 * 1024;
  final _retentionDays = 7;

  final _logsUpdatedController = StreamController<void>.broadcast();

  bool _isCleanupRunning = false;
  bool _hasRunInitialCleanup = false;
  int _logWriteCount = 0;
  final List<LogEntry> _writeBuffer = [];

  Stream<void> get logsUpdated => _logsUpdatedController.stream;

  Future<void> initialize() async {
    try {
      final startTime = DateTime.now();
      developer.log(
        'LogService.initialize() started',
        name: 'kashr.log_service',
      );

      _logFile = await _getLogFile();
      developer.log(
        'Log file ready: ${DateTime.now().difference(startTime).inMilliseconds}ms',
        name: 'kashr.log_service',
      );

      // Don't run cleanup on startup to avoid blocking
      // Cleanup will run lazily when needed or can be triggered manually

      log.i('LogService initialized at ${_logFile?.path}');
      developer.log(
        'LogService.initialize() completed: ${DateTime.now().difference(startTime).inMilliseconds}ms',
        name: 'kashr.log_service',
      );
    } catch (e, stack) {
      developer.log(
        'CRITICAL: LogService initialization failed',
        name: 'kashr.log_service',
        level: 1000,
        error: e,
        stackTrace: stack,
      );
      debugPrint('CRITICAL: LogService initialization failed: $e\n$stack');
      rethrow;
    }
  }

  void dispose() {
    _logsUpdatedController.close();
  }

  void setLogLevel(LogLevelSetting level) {
    _currentLogLevel = level;
    log.i('Log level set to ${level.name}');
  }

  Future<File> _getLogFile() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(path.join(appDocDir.path, 'logs'));

    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    return File(path.join(logsDir.path, 'log.json'));
  }

  Future<void> logToFile({
    required LogLevelSetting level,
    required String message,
    String? loggerName,
    String? error,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    try {
      if (!_currentLogLevel.shouldLog(level)) {
        return;
      }

      final entry = LogEntry(
        timestamp: DateTime.now().toUtc(),
        level: level,
        message: message,
        loggerName: loggerName,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );

      await _appendLogEntry(entry);
    } catch (e, stack) {
      debugPrint('Failed to write log entry: $e\n$stack');
    }
  }

  Future<void> _appendLogEntry(LogEntry entry) async {
    if (_logFile == null) {
      debugPrint('WARNING: Cannot write log - LogService not initialized');
      return;
    }

    // If cleanup is running, buffer the entry to avoid file corruption
    if (_isCleanupRunning) {
      _writeBuffer.add(entry);
      return;
    }

    // Write directly to file
    await _writeLogEntryToFile(entry);

    _logWriteCount++;

    // Run cleanup lazily: after first 50 writes, then every 500 writes
    // This prevents blocking on every log write
    if (!_hasRunInitialCleanup && _logWriteCount >= 50) {
      _hasRunInitialCleanup = true;
      _runCleanupIfNeeded();
    } else if (_hasRunInitialCleanup && _logWriteCount % 500 == 0) {
      _runCleanupIfNeeded();
    }

    _logsUpdatedController.add(null);
  }

  Future<void> _writeLogEntryToFile(LogEntry entry) async {
    await _logFile!.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
    );
  }

  void _runCleanupIfNeeded() {
    if (_isCleanupRunning) return;

    _isCleanupRunning = true;

    // Run cleanup in background without blocking
    unawaited(_performCleanup());
  }

  Future<void> _performCleanup() async {
    try {
      await _trimLogsIfNeeded();
      await _cleanupOldLogs();
    } catch (e, stack) {
      developer.log(
        'Cleanup failed (non-critical)',
        name: 'kashr.log_service',
        level: 900,
        error: e,
        stackTrace: stack,
      );
    } finally {
      // Mark cleanup as complete first
      _isCleanupRunning = false;

      // Flush any buffered entries that accumulated during cleanup
      await _flushWriteBuffer();
    }
  }

  Future<void> _flushWriteBuffer() async {
    if (_writeBuffer.isEmpty) return;

    developer.log(
      'Flushing ${_writeBuffer.length} buffered log entries',
      name: 'kashr.log_service',
    );

    // Copy and clear buffer to avoid modifications during iteration
    final bufferedEntries = List<LogEntry>.from(_writeBuffer);
    _writeBuffer.clear();

    // Write all buffered entries
    for (final entry in bufferedEntries) {
      try {
        await _writeLogEntryToFile(entry);
        _logWriteCount++;
      } catch (e, stack) {
        developer.log(
          'Failed to flush buffered log entry',
          name: 'kashr.log_service',
          level: 900,
          error: e,
          stackTrace: stack,
        );
      }
    }

    _logsUpdatedController.add(null);
  }

  /// Reads file lines with resilient UTF-8 decoding.
  ///
  /// Handles files with invalid UTF-8 by replacing bad bytes instead of failing.
  Future<List<String>> _readLinesResilient(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      return const LineSplitter().convert(content);
    } catch (e, stack) {
      developer.log(
        'Failed to read log file resiliently',
        name: 'kashr.log_service',
        level: 900,
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  /// Read logs with optional pagination.
  ///
  /// Reads complete file into memory, but only parses json for selected page.
  Future<List<LogEntry>> readLogsPage({int offset = 0, int limit = 100}) async {
    if (_logFile == null || !await _logFile!.exists()) return [];

    final lines = await _readLinesResilient(_logFile!);

    final selectedLines = lines.reversed.skip(offset).take(limit);
    return selectedLines
        .map((line) {
          try {
            if (line.trim().isEmpty) return null;
            return LogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>);
          } catch (e) {
            developer.log(
              'Skipping malformed log entry\n$line',
              name: 'kashr.log_service',
              level: 900,
            );
            return null;
          }
        })
        .nonNulls
        .toList();
  }

  // Trim logs if file is too large
  Future<void> _trimLogsIfNeeded() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    final lines = await _readLinesResilient(_logFile!);

    // Estimate each entry ~500 bytes (adjust if needed)
    final estimatedSize = lines.length * 500;
    if (estimatedSize <= _maxFileSize) return;

    final keepCount = (_maxFileSize / 500).floor();
    final trimmedLines = lines.take(keepCount);

    await _logFile!.writeAsString('${trimmedLines.join('\n')}\n');
    log.i('Trimmed logs to $keepCount entries');
  }

  // Cleanup old logs based on retention
  Future<void> _cleanupOldLogs() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    final cutoffDate = DateTime.now().subtract(Duration(days: _retentionDays));
    final lines = await _readLinesResilient(_logFile!);

    final filteredLines = lines.where((line) {
      try {
        if (line.trim().isEmpty) return false;
        final entry = LogEntry.fromJson(
          jsonDecode(line) as Map<String, dynamic>,
        );
        return entry.timestamp.isAfter(cutoffDate);
      } catch (e) {
        developer.log(
          'Skipping malformed log entry during cleanup',
          name: 'kashr.log_service',
          level: 500,
        );
        return false;
      }
    }).toList();

    if (filteredLines.length < lines.length) {
      await _logFile!.writeAsString('${filteredLines.join('\n')}\n');
      log.i(
        'Cleaned up ${lines.length - filteredLines.length} old log entries',
      );
    }
  }

  Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.delete();
        _logFile = await _getLogFile();
        log.i('All logs cleared');
        _logsUpdatedController.add(null);
      }
    } catch (e, stack) {
      log.e('Failed to clear logs', error: e, stackTrace: stack);
      rethrow;
    }
  }
}

class LogServiceOutput extends LogOutput {
  final LogService logService;

  LogServiceOutput(this.logService);

  @override
  void output(OutputEvent event) {
    logService.logToFile(
      level: _convertLevel(event.level),
      message: event.origin.message.toString(),
      loggerName: 'Logger',
      error: event.origin.error?.toString(),
      stackTrace: (event.origin.stackTrace ?? StackTrace.current).toString(),
      context: {'lines': event.lines},
    );
    if (kDebugMode) {
      for (final line in event.lines) {
        print(line);
      }
    }
  }

  LogLevelSetting _convertLevel(Level lvl) {
    return switch (lvl) {
      // ignore: deprecated_member_use
      Level.all || Level.verbose || Level.trace => LogLevelSetting.trace,
      Level.debug => LogLevelSetting.debug,
      Level.info => LogLevelSetting.info,
      Level.warning => LogLevelSetting.warning,
      Level.error => LogLevelSetting.error,
      // ignore: deprecated_member_use
      Level.fatal || Level.wtf => LogLevelSetting.fatal,
      // ignore: deprecated_member_use
      Level.off || Level.nothing => LogLevelSetting.off,
    };
  }
}

class ProductionLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}
