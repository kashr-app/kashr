import 'dart:async';
import 'dart:convert';
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

  Stream<void> get logsUpdated => _logsUpdatedController.stream;

  Future<void> initialize() async {
    try {
      _logFile = await _getLogFile();
      await _cleanupOldLogs();
      log.i('LogService initialized at ${_logFile?.path}');
    } catch (e, stack) {
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

    // Append the new log as a single line
    await _logFile!.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
    );

    // Trim the file if it grows too large
    await _trimLogsIfNeeded();

    _logsUpdatedController.add(null);
  }

  /// Read logs with optional pagination.
  ///
  /// Reads complete file into memory, but only parses json for selected page.
  Future<List<LogEntry>> readLogsPage({int offset = 0, int limit = 100}) async {
    if (_logFile == null || !await _logFile!.exists()) return [];

    final lines = await _logFile!.readAsLines();

    final selectedLines = lines.reversed.skip(offset).take(limit);
    return selectedLines
        .map(
          (line) => LogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>),
        )
        .toList();
  }

  // Trim logs if file is too large
  Future<void> _trimLogsIfNeeded() async {
    if (_logFile == null || !await _logFile!.exists()) return;

    final lines = await _logFile!.readAsLines();

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
    final lines = await _logFile!.readAsLines();

    final filteredLines = lines.where((line) {
      final entry = LogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>);
      return entry.timestamp.isAfter(cutoffDate);
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
