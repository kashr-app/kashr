import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_suggestion.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/cubit/turnover_tags_state.freezed.dart';
part '../../_gen/turnover/cubit/turnover_tags_state.g.dart';

/// Represents a TagTurnover with its associated Tag.
@freezed
abstract class TagTurnoverWithTag with _$TagTurnoverWithTag {
  const factory TagTurnoverWithTag({
    required TagTurnover tagTurnover,
    required Tag tag,
  }) = _TagTurnoverWithTag;

  factory TagTurnoverWithTag.fromJson(Map<String, dynamic> json) =>
      _$TagTurnoverWithTagFromJson(json);
}

@freezed
abstract class TurnoverTagsState with _$TurnoverTagsState {
  const TurnoverTagsState._();

  const factory TurnoverTagsState({
    @Default(Status.initial) Status status,
    Turnover? turnover,
    Turnover? initialTurnover,
    @Default([]) List<TagTurnoverWithTag> tagTurnovers,
    @Default([]) List<TagTurnoverWithTag> initialTagTurnovers,
    @Default([]) List<Tag> availableTags,
    @Default([]) List<TagSuggestion> suggestions,
    String? errorMessage,
    @Default(false) bool isManualAccount,
  }) = _TurnoverTagsState;

  factory TurnoverTagsState.fromJson(Map<String, dynamic> json) =>
      _$TurnoverTagsStateFromJson(json);

  /// Returns the sum of all tag turnover amounts.
  Decimal get totalTagAmount {
    return tagTurnovers.fold<Decimal>(
      Decimal.zero,
      (sum, tt) => sum + tt.tagTurnover.amountValue,
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
    if (tagTurnovers.length != initialTagTurnovers.length) return true;

    // Compare index by index - this uses freezed's generated equality for TagTurnover
    // which automatically compares ALL fields (amount, note, etc.)
    // Order matters to users, so we check each position
    for (var i = 0; i < tagTurnovers.length; i++) {
      if (tagTurnovers[i].tagTurnover != initialTagTurnovers[i].tagTurnover) {
        return true;
      }
    }

    return false;
  }
}
