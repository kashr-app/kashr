import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/backup/model/backup_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/backup/cubit/backup_state.freezed.dart';

/// State for backup management
@freezed
abstract class BackupState with _$BackupState {
  const factory BackupState.initial() = BackupInitial;

  const factory BackupState.loading({
    required String operation,
    @Default(0.0) double progress,
  }) = BackupLoading;

  const factory BackupState.loaded({
    required List<BackupMetadata> localBackups,
    required BackupConfig config,
    @Default({}) Map<String, bool> isOnNextcloudById,
    @Default([]) List<String> nextcloudOnly,
    @Default(false) bool nextcloudConfigured,
  }) = BackupLoaded;

  const factory BackupState.success({
    required String message,
    BackupMetadata? backup,
  }) = BackupSuccess;

  const factory BackupState.error({
    required String message,
    Exception? exception,
  }) = BackupError;
}
