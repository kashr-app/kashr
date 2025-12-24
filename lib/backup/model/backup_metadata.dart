import 'package:kashr/backup/services/backup_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/backup/model/backup_metadata.freezed.dart';
part '../../_gen/backup/model/backup_metadata.g.dart';

/// Metadata for a backup file
@freezed
abstract class BackupMetadata with _$BackupMetadata {
  // private empty constructor required to enable the generated code
  // to extend/subclass our class, instead of implementing it
  // this enables us to define custom getters
  // ignore: unused_element
  const BackupMetadata._();

  const factory BackupMetadata({
    required String id,
    required DateTime createdAt,
    required int dbVersion,
    required String appVersion,
    required bool encrypted,
    int? fileSizeBytes,
    String? checksum,
    String? localPath,
  }) = _BackupMetadata;

  factory BackupMetadata.fromJson(Map<String, dynamic> json) =>
      _$BackupMetadataFromJson(json);

  String get filename => BackupService.createFilename(createdAt);
}
