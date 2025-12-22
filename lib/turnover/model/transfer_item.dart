import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/turnover/model/transfer_item.freezed.dart';

/// Unified model representing an transfer item.
@freezed
abstract class TransferItem with _$TransferItem {
  const TransferItem._();

  /// An existing Transfer entity
  const factory TransferItem.withTransfer({
    required TransferWithDetails transferWithDetails,
  }) = WithTransferItem;

  /// A tagTurnover with transfer semantic not yet linked to a Transfer
  const factory TransferItem.unlinkedFromTransfer({
    required TagTurnover tagTurnover,
    required Tag tag,
  }) = UnlinkedFromTransferItem;

  /// Unique ID for this review item (for list keys)
  UuidValue get id => when(
    withTransfer: (details) => details.transfer.id,
    unlinkedFromTransfer: (tt, tag) => tt.id,
  );

  /// User-facing description of the issue
  String get issueDescription => when(
    withTransfer: (details) =>
        details.needsReview?.description ?? 'Unknown issue',
    unlinkedFromTransfer: (_, _) => 'Not linked to transfer',
  );

  /// Booking date for sorting
  DateTime get bookingDate => when(
    withTransfer: (details) =>
        details.fromTagTurnover?.bookingDate ??
        details.toTagTurnover?.bookingDate ??
        details.transfer.createdAt,
    unlinkedFromTransfer: (tt, _) => tt.bookingDate,
  );
}
