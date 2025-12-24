import 'package:decimal/decimal.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/turnover/model/tag_suggestion.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/turnover/cubit/turnover_tags_state.freezed.dart';

@freezed
abstract class TurnoverTagsState with _$TurnoverTagsState {
  const TurnoverTagsState._();

  const factory TurnoverTagsState({
    @Default(Status.initial) Status status,
    Turnover? turnover,
    Turnover? initialTurnover,
    @Default({}) Map<UuidValue, TagTurnover> currentTagTurnoversById,
    @Default([]) List<TagTurnover> initialTagTurnovers,
    @Default([]) List<TagSuggestion> suggestions,
    String? errorMessage,
    @Default(false) bool isManualAccount,
    @Default([]) List<TagTurnover> associatedPendingTagTurnovers,
    @Default([]) List<TagTurnover> unlinkedTagTurnovers,
    @Default({}) Map<UuidValue, TransferWithDetails> transferByTagTurnoverId,
  }) = _TurnoverTagsState;

  /// Returns the sum of all tag turnover amounts.
  Decimal get totalTagAmount {
    return currentTagTurnoversById.values.fold<Decimal>(
      Decimal.zero,
      (sum, tt) => sum + tt.amountValue,
    );
  }

  /// Returns true if the sum of tag turnovers exceeds the turnover amount.
  bool get isAmountExceeded {
    final t = turnover;
    if (t == null) return false;

    final sum = totalTagAmount;

    // Compare absolute values to handle both positive and negative turnovers
    return sum.abs() > t.amountValue.abs();
  }

  /// Returns the amount by which the total exceeds the turnover amount.
  /// Returns Decimal.zero if not exceeded.
  Decimal get exceededAmount {
    final t = turnover;
    if (t == null) return Decimal.zero;

    final sum = totalTagAmount;
    final difference = sum.abs() - t.amountValue.abs();

    return difference > Decimal.zero ? difference : Decimal.zero;
  }

  /// Returns true if the current state differs from the initial state.
  bool get isDirty {
    // Check if turnover has been modified
    if (turnover != initialTurnover) return true;

    // Different number of tag turnovers
    if (currentTagTurnoversById.length != initialTagTurnovers.length) {
      return true;
    }

    // Compare with initial TagTurnovers - this uses freezed's generated equality for TagTurnover
    // which automatically compares ALL fields (amount, note, etc.)
    // Order matters to users, so we check each position
    final tagTurnovers = currentTagTurnoversById.values.toList();
    for (var i = 0; i < currentTagTurnoversById.length; i++) {
      if (tagTurnovers[i] != initialTagTurnovers[i]) {
        return true;
      }
    }

    return false;
  }

  /// Checks if adding new tag turnovers would exceed the turnover amount.
  ///
  /// Returns a record with:
  /// - wouldExceed: true if the combined total would exceed the turnover amount
  /// - combinedTotal: the combined absolute total of existing and new tag turnovers
  /// - exceedingAmount: the amount by which it would exceed (zero if not exceeding)
  ({bool wouldExceed, Decimal combinedTotal, Decimal exceedingAmount})
  checkIfWouldExceed(List<TagTurnover> newTagTurnovers) {
    final t = turnover;
    if (t == null) {
      return (
        wouldExceed: false,
        combinedTotal: Decimal.zero,
        exceedingAmount: Decimal.zero,
      );
    }

    final existingTotal = totalTagAmount.abs();
    final newTotal = newTagTurnovers.fold<Decimal>(
      Decimal.zero,
      (sum, tt) => sum + tt.amountValue.abs(),
    );
    final combinedTotal = existingTotal + newTotal;
    final turnoverAbsAmount = t.amountValue.abs();

    final wouldExceed = combinedTotal > turnoverAbsAmount;
    final exceedingAmount = wouldExceed
        ? combinedTotal - turnoverAbsAmount
        : Decimal.zero;

    return (
      wouldExceed: wouldExceed,
      combinedTotal: combinedTotal,
      exceedingAmount: exceedingAmount,
    );
  }
}
