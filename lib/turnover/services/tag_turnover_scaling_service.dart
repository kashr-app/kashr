import 'package:decimal/decimal.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';

/// Service for scaling tag turnovers to fit within a target amount.
class TagTurnoverScalingService {
  /// Scales a list of tag turnovers proportionally to fit within a target amount.
  ///
  /// Returns a new list of scaled tag turnovers. The original list is not modified.
  /// Each tag turnover's amount is scaled by the same factor to ensure the total
  /// does not exceed [targetAbsAmount].
  ///
  /// [tagTurnovers] - The list of tag turnovers to scale
  /// [targetAbsAmount] - The target absolute amount that the sum should not exceed
  /// [targetIsNegative] - Whether the target amount is negative (affects sign)
  static List<TagTurnover> scaleToFit({
    required List<TagTurnover> tagTurnovers,
    required Decimal targetAbsAmount,
    required bool targetIsNegative,
  }) {
    if (tagTurnovers.isEmpty) return [];

    // Calculate total absolute amount of all tag turnovers
    final totalTagAmount = tagTurnovers.fold<Decimal>(
      Decimal.zero,
      (sum, tt) => sum + tt.amountValue.abs(),
    );

    // If total is already within target, no scaling needed
    if (totalTagAmount <= targetAbsAmount) {
      return tagTurnovers;
    }

    // Calculate scale factor to fit tag turnovers within target amount
    final scaleFactor = (targetAbsAmount / totalTagAmount).toDecimal(
      scaleOnInfinitePrecision: 10,
    );

    // Scale each tag turnover
    return tagTurnovers.map((tt) {
      // Scale the absolute value
      final scaledAbsAmount =
          (tt.amountValue.abs() * scaleFactor).floor(scale: 2);
      // Apply the correct sign based on the target
      final signedAmount =
          targetIsNegative ? -scaledAbsAmount : scaledAbsAmount;
      return tt.copyWith(amountValue: signedAmount);
    }).toList();
  }

  /// Scales a list of TagTurnoverWithTag proportionally to fit within a target amount.
  ///
  /// Similar to [scaleToFit], but works with TagTurnoverWithTag objects.
  static List<TagTurnoverWithTag> scaleWithTagsToFit({
    required List<TagTurnoverWithTag> tagTurnovers,
    required Decimal targetAbsAmount,
    required bool targetIsNegative,
  }) {
    if (tagTurnovers.isEmpty) return [];

    // Calculate total absolute amount of all tag turnovers
    final totalTagAmount = tagTurnovers.fold<Decimal>(
      Decimal.zero,
      (sum, tt) => sum + tt.tagTurnover.amountValue.abs(),
    );

    // If total is already within target, no scaling needed
    if (totalTagAmount <= targetAbsAmount) {
      return tagTurnovers;
    }

    // Calculate scale factor to fit tag turnovers within target amount
    final scaleFactor = (targetAbsAmount / totalTagAmount).toDecimal(
      scaleOnInfinitePrecision: 10,
    );

    // Scale each tag turnover
    return tagTurnovers.map((tt) {
      // Scale the absolute value
      final scaledAbsAmount = (tt.tagTurnover.amountValue.abs() * scaleFactor)
          .floor(scale: 2);
      // Apply the correct sign based on the target
      final signedAmount =
          targetIsNegative ? -scaledAbsAmount : scaledAbsAmount;
      return tt.copyWith(
        tagTurnover: tt.tagTurnover.copyWith(amountValue: signedAmount),
      );
    }).toList();
  }
}
