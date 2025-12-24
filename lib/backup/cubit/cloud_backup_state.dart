import 'package:kashr/backup/model/backup_config.dart';
import 'package:kashr/core/status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/backup/cubit/cloud_backup_state.freezed.dart';

@freezed
abstract class CloudBackupState with _$CloudBackupState {
  // private empty constructor required to enable the generated code
  // to extend/subclass our class, instead of implementing it
  // this enables us to define custom methods
  // ignore: unused_element
  const CloudBackupState._();

  const factory CloudBackupState({
    @Default(Status.initial) Status status,
    @Default('') String message,
    @Default(null) double? progress,
    @Default(null) NextcloudConfig? config,
    @Default({}) Map<String, Status?> statusByFilename,
    @Default({}) Map<String, bool> isOnNextcloudByFilename,
    @Default({}) Map<String, double> progressByFilename,
    @Default(false) bool nextcloudConfigured,
  }) = _CloudBackupState;

  CloudBackupState copyWithProgress(String filename, double p) {
    return copyWith(progressByFilename: {...progressByFilename, filename: p});
  }
}
