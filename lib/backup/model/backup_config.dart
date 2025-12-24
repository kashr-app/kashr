import 'package:kashr/core/bool_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/backup/model/backup_config.freezed.dart';
part '../../_gen/backup/model/backup_config.g.dart';

/// Frequency for automatic backups
enum BackupFrequency {
  @JsonValue('daily')
  daily,
  @JsonValue('weekly')
  weekly,
  @JsonValue('monthly')
  monthly,
}

/// Configuration for backup feature
@freezed
abstract class BackupConfig with _$BackupConfig {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory BackupConfig({
    @BoolJsonConverter() required bool autoBackupEnabled,

    required BackupFrequency frequency,

    DateTime? lastAutoBackup,

    @BoolJsonConverter() required bool encryptionEnabled,

    required int maxLocalBackups,

    @BoolJsonConverter() required bool autoBackupToCloud,
  }) = _BackupConfig;

  factory BackupConfig.fromJson(Map<String, dynamic> json) =>
      _$BackupConfigFromJson(json);

  static BackupConfig defaultConfig() => const BackupConfig(
    autoBackupEnabled: false,
    frequency: BackupFrequency.weekly,
    encryptionEnabled: false,
    maxLocalBackups: 5,
    autoBackupToCloud: false,
  );
}

/// Cloud provider configuration
@freezed
abstract class CloudProviderConfig with _$CloudProviderConfig {
  const factory CloudProviderConfig.nextcloud({
    required String url,
    required String username,
    required String passwordKey, // Key in secure storage
    @Default('/Backups/Kashr/') String backupPath,
  }) = NextcloudConfig;

  // Future providers can be added here
  // const factory CloudProviderConfig.googleDrive(...) = GoogleDriveConfig;

  factory CloudProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$CloudProviderConfigFromJson(json);
}
