import 'package:finanalyzer/core/uuid_json_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/turnover/model/transfer.freezed.dart';
part '../../_gen/turnover/model/transfer.g.dart';

/// Represents a transfer between two accounts.
///
/// A transfer links two TagTurnovers: one with negative amount (from)
/// and one with positive amount (to). The transfer is considered valid when:
/// - Both sides reference different accounts (R2)
/// - Both sides have opposite signs
/// - Both sides have same tag and transfer semantic (R4)
/// - Both amounts match (if same currency or user confirmedAt is not null)
///
/// See prds/20251214-transfers.md for full specification.
@freezed
abstract class Transfer with _$Transfer {
  const Transfer._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Transfer({
    @UUIDJsonConverter() required UuidValue id,
    @UUIDNullableJsonConverter() UuidValue? fromTagTurnoverId,
    @UUIDNullableJsonConverter() UuidValue? toTagTurnoverId,
    required DateTime createdAt,
    DateTime? confirmedAt,
  }) = _Transfer;

  /// Whether the user has confirmed this transfer (typically used when
  /// amounts don't match due to currency conversion or other valid reasons).
  bool get confirmed => confirmedAt != null;

  factory Transfer.fromJson(Map<String, dynamic> json) =>
      _$TransferFromJson(json);
}
