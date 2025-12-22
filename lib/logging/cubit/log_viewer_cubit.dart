import 'dart:async';

import 'package:finanalyzer/logging/log_viewer_state.dart';
import 'package:finanalyzer/logging/model/log_level_setting.dart';
import 'package:finanalyzer/logging/services/log_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

class LogViewerCubit extends Cubit<LogViewerState> {
  final LogService _logService;
  final Logger log;
  StreamSubscription<void>? _logsUpdatedSubscription;

  LogViewerCubit(this._logService, this.log) : super(const LogViewerState()) {
    _logsUpdatedSubscription = _logService.logsUpdated.listen((_) {
      loadLogs();
    });
    loadLogs();
  }

  Future<void> loadLogs() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final logs = await _logService.readLogsPage();

      final filtered = state.filterLevel != null
          ? logs.where((log) => log.level == state.filterLevel).toList()
          : logs;

      emit(state.copyWith(logs: filtered, isLoading: false));
    } catch (e, stack) {
      log.e('Failed to load logs', error: e, stackTrace: stack);
      emit(state.copyWith(isLoading: false, error: 'Failed to load logs: $e'));
    }
  }

  void setFilterLevel(LogLevelSetting level) {
    emit(state.copyWith(filterLevel: level));
    loadLogs();
  }

  Future<void> clearLogs() async {
    try {
      await _logService.clearLogs();
      await loadLogs();
    } catch (e, stack) {
      log.e('Failed to clear logs', error: e, stackTrace: stack);
      emit(state.copyWith(error: 'Failed to clear logs: $e'));
    }
  }

  @override
  Future<void> close() {
    _logsUpdatedSubscription?.cancel();
    return super.close();
  }
}
