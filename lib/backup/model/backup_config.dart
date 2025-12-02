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
  const factory BackupConfig({
    // Automatic backup settings
    @Default(false) bool autoBackupEnabled,
    @Default(BackupFrequency.weekly) BackupFrequency frequency,
    DateTime? lastAutoBackup,

    // Encryption settings
    @Default(false) bool encryptionEnabled,

    // Local backup settings
    @Default(5) int maxLocalBackups,

    // Cloud backup settings
    @Default(false) bool autoBackupToCloud,
  }) = _BackupConfig;

  factory BackupConfig.fromJson(Map<String, dynamic> json) =>
      _$BackupConfigFromJson(json);
}

/// Cloud provider configuration
@freezed
abstract class CloudProviderConfig with _$CloudProviderConfig {
  const factory CloudProviderConfig.nextcloud({
    required String url,
    required String username,
    required String passwordKey, // Key in secure storage
    @Default('/Backups/Finanalyzer/') String backupPath,
  }) = NextcloudConfig;

  // Future providers can be added here
  // const factory CloudProviderConfig.googleDrive(...) = GoogleDriveConfig;

  factory CloudProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$CloudProviderConfigFromJson(json);
}
