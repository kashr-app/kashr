import 'package:decimal/decimal.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/transfer.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/model/transfer_with_details.freezed.dart';

/// Reasons why a transfer needs review.
enum TransferReviewReason {
  missingBothSides,
  missingFromSide,
  missingToSide,

  fromTagNotTransfer,
  toTagNotTransfer,
  tagMismatch,

  sameAccount,

  /// Different currencies and not confirmed
  differentCurrencies,

  /// Same currency but amounts don't match and not confirmed
  amountMismatch,

  fromSignMustBeNegative,
  toSignMustBePositive;

  String get description {
    switch (this) {
      case TransferReviewReason.missingBothSides:
        return 'Missing both sides';
      case TransferReviewReason.missingFromSide:
        return 'Missing FROM side';
      case TransferReviewReason.missingToSide:
        return 'Missing TO side';
      case TransferReviewReason.fromTagNotTransfer:
        return 'From side has a non-transfer tag';
      case TransferReviewReason.toTagNotTransfer:
        return 'To side has a non-transfer tag';
      case TransferReviewReason.tagMismatch:
        return 'Tags don\'t match';
      case TransferReviewReason.sameAccount:
        return 'Same account';
      case TransferReviewReason.differentCurrencies:
        return 'Different currencies';
      case TransferReviewReason.amountMismatch:
        return 'Amounts don\'t match';
      case TransferReviewReason.fromSignMustBeNegative:
        return 'FROM amount must be negative';
      case TransferReviewReason.toSignMustBePositive:
        return 'TO amount must be positive';
    }
  }

  /// See also [TransferWithDetails.canConfirm]
  bool get canConfirm {
    return switch (this) {
      TransferReviewReason.missingBothSides => false,
      TransferReviewReason.missingFromSide => false,
      TransferReviewReason.missingToSide => false,
      TransferReviewReason.fromTagNotTransfer => false,
      TransferReviewReason.toTagNotTransfer => false,
      TransferReviewReason.tagMismatch => false,
      TransferReviewReason.sameAccount => false,
      TransferReviewReason.differentCurrencies => true,
      TransferReviewReason.amountMismatch => true,
      TransferReviewReason.fromSignMustBeNegative => false,
      TransferReviewReason.toSignMustBePositive => false,
    };
  }
}

/// Transfer with its associated [TagTurnover]s and [Tag]s for display.
@freezed
abstract class TransferWithDetails with _$TransferWithDetails {
  const TransferWithDetails._();

  const factory TransferWithDetails({
    required Transfer transfer,
    required TagTurnover? fromTagTurnover,
    required TagTurnover? toTagTurnover,
    required Tag? fromTag,
    required Tag? toTag,
  }) = _TransferWithDetails;

  /// Returns the review reason if this transfer needs review, null otherwise.
  ///
  /// A transfer needs review if:
  /// - Missing from or to side
  /// - from.tagId.semantic != transfer
  /// - to.tagId.semantic != transfer
  /// - from.tagId != to.tagId
  /// - from.amount.sign == to.amount.sign && SUM(from.amount, to.amount) <> 0
  /// - Not confirmed and (amounts mismatch in same currency OR different currencies)
  ///
  /// The logic must be consistent with [TransferRepository.countTransfersNeedingReview].
  TransferReviewReason? get needsReview {
    final fromTT = fromTagTurnover;
    final toTT = toTagTurnover;
    // Missing from or to
    if (fromTT == null && toTT == null) {
      return TransferReviewReason.missingBothSides;
    }
    if (fromTT == null) return TransferReviewReason.missingFromSide;
    if (toTT == null) return TransferReviewReason.missingToSide;

    final fTag = fromTag;
    final tTag = toTag;
    if (fTag == null || !fTag.isTransfer) {
      return TransferReviewReason.fromTagNotTransfer;
    }
    if (tTag == null || !tTag.isTransfer) {
      return TransferReviewReason.toTagNotTransfer;
    }
    if (fTag.id != tTag.id) return TransferReviewReason.tagMismatch;

    if (fromTT.accountId == toTT.accountId) {
      return TransferReviewReason.sameAccount;
    }

    final fromAmount = fromTT.amountValue;
    final toAmount = toTT.amountValue;

    if (fromAmount.sign >= 0) {
      return TransferReviewReason.fromSignMustBeNegative;
    }
    if (toAmount.sign < 0) {
      return TransferReviewReason.toSignMustBePositive;
    }

    // The rest of the issues can be confirmed to be ok, hence we do not need
    // to check hem if the user confirmed the differences to be okay.
    if (transfer.confirmed) return null;

    // Check if amounts cancel out (sum should be zero if currencies match)
    final sum = fromAmount + toAmount;
    final isCurrencyMatch = fromTT.amountUnit == toTT.amountUnit;
    if (isCurrencyMatch && sum != Decimal.zero) {
      // Same currency but amounts don't match
      return TransferReviewReason.amountMismatch;
    }

    // Different currencies always need confirmation as we cannot tell the
    // exact exchange rate
    if (!isCurrencyMatch) {
      return TransferReviewReason.differentCurrencies;
    }

    return null;
  }

  bool get canConfirm => needsReview?.canConfirm ?? false;
}
