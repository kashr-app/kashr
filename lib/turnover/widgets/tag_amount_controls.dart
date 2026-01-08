import 'dart:math';

import 'package:kashr/core/amount_dialog.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/turnover/cubit/turnover_tags_cubit.dart';
import 'package:kashr/turnover/cubit/turnover_tags_state.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Controls for adjusting the amount allocated to a tag turnover.
///
/// Displays the current amount and provides buttons to:
/// - Add remaining uncovered amount
/// - Reduce by exceeded amount
/// - Manually edit the amount
class TagAmountControls extends StatelessWidget {
  final TagTurnover tagTurnover;
  final int maxAmountScaled;
  final String currencyUnit;

  const TagAmountControls({
    required this.tagTurnover,
    required this.maxAmountScaled,
    required this.currencyUnit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountScaled = decimalScale(tagTurnover.amountValue) ?? 0;
    final isNegative = maxAmountScaled < 0;
    final maxAbsolute = maxAmountScaled.abs();
    final currentAbsolute = amountScaled.abs();

    return BlocBuilder<TurnoverTagsCubit, TurnoverTagsState>(
      builder: (context, state) {
        final exceededAmountScaled = decimalScale(state.exceededAmount) ?? 0;
        final isExceeded = state.isAmountExceeded;
        final totalAbsolute = state.totalTagAmount.abs();
        final turnoverAbsolute = (state.turnover?.amountValue.abs());
        final isPerfect = totalAbsolute == turnoverAbsolute;

        return Column(
          children: [
            _AmountSlider(
              tagTurnover: tagTurnover,
              currentAbsolute: currentAbsolute,
              maxAbsolute: maxAbsolute,
              isNegative: isNegative,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tagTurnover.formatAmount(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isPerfect &&
                    ((isExceeded && currentAbsolute > 0) ||
                        (!isExceeded && currentAbsolute < maxAbsolute)))
                  IconButton(
                    icon: Icon(isExceeded ? Icons.remove : Icons.add, size: 20),
                    tooltip: isExceeded
                        ? 'Reduce by exceeded amount'
                        : 'Fill remaining',
                    onPressed: () => _adjustAmount(
                      context,
                      state,
                      isExceeded,
                      isNegative,
                      currentAbsolute,
                      maxAbsolute,
                      exceededAmountScaled,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editAmount(
                    context,
                    isNegative,
                    maxAbsolute,
                    currentAbsolute,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _adjustAmount(
    BuildContext context,
    TurnoverTagsState state,
    bool isExceeded,
    bool isNegative,
    int currentAbsolute,
    int maxAbsolute,
    int exceededAmountScaled,
  ) {
    final cubit = context.read<TurnoverTagsCubit>();
    int newAbsoluteAmount;

    if (isExceeded) {
      // Reduce by exceeded amount, but at most to 0
      newAbsoluteAmount = (currentAbsolute - exceededAmountScaled).clamp(
        0,
        maxAbsolute,
      );
    } else {
      // Calculate remaining uncovered amount
      final totalTagAmountScaled = decimalScale(state.totalTagAmount) ?? 0;
      final remainingScaled = maxAbsolute - totalTagAmountScaled.abs();
      // Add remaining to current amount, clamped to max
      newAbsoluteAmount = (currentAbsolute + remainingScaled).clamp(
        0,
        maxAbsolute,
      );
    }

    final signedValue = isNegative ? -newAbsoluteAmount : newAbsoluteAmount;
    cubit.updateTagTurnoverAmount(tagTurnover.id, signedValue);
  }

  Future<void> _editAmount(
    BuildContext context,
    bool isNegative,
    int maxAbsolute,
    int currentAbsolute,
  ) async {
    final result = await AmountDialog.show(
      context,
      currencyUnit: currencyUnit,
      maxAmountScaled: maxAbsolute,
      initialAmountScaled: currentAbsolute,
      showSignSwitch: false,
    );

    if (result != null && context.mounted) {
      // Apply the sign of the turnover to the result
      final signedResult = isNegative ? -result : result;
      context.read<TurnoverTagsCubit>().updateTagTurnoverAmount(
        tagTurnover.id,
        signedResult,
      );
    }
  }
}

/// A slider for adjusting the amount allocated to a tag turnover.
///
/// Provides smooth value adjustment with intelligent step sizing based on
/// the maximum amount to balance precision and usability.
class _AmountSlider extends StatelessWidget {
  final TagTurnover tagTurnover;
  final int currentAbsolute;
  final int maxAbsolute;
  final bool isNegative;

  const _AmountSlider({
    required this.tagTurnover,
    required this.currentAbsolute,
    required this.maxAbsolute,
    required this.isNegative,
  });

  /// Maximum slider divisions to balance granularity and selectability.
  ///
  /// Step size is calculated to keep divisions under this limit.
  /// Divisions = `2 × maxAbsolute / stepSize` where the 2× ensures the gap
  /// between slider divisions is at most half the step size, allowing reliable
  /// snapping to every intended step value.
  ///
  /// Example: maxAbsolute=2145, maxDivisions=300
  /// - Initial stepSize=10 → divisions = 2×2145/10 = 429 > 300
  /// - Increases to stepSize=50 → divisions = 2×2145/50 = 86 ✓
  static const maxDivisions = 300;

  @override
  Widget build(BuildContext context) {
    final stepSize = _calculateStepSize(maxAbsolute);

    return Slider(
      value: currentAbsolute.toDouble(),
      min: 0,
      max: maxAbsolute.toDouble(),
      divisions: _calculateDivisions(maxAbsolute, stepSize),
      label: tagTurnover.formatAmount(),
      onChanged: (value) {
        // Snap to nearest multiple of step size
        final snappedValue = _snapToStep(value.toInt(), stepSize, maxAbsolute);
        // Apply the sign back when updating
        final signedValue = isNegative ? -snappedValue : snappedValue;
        context.read<TurnoverTagsCubit>().updateTagTurnoverAmount(
          tagTurnover.id,
          signedValue,
        );
      },
    );
  }

  /// Calculates the step size for the slider based on maximum value.
  ///
  /// Returns a "nice" step size (1, 5, 10, 50, 100, 500, etc. in cents)
  /// that respects the maximum division limit.
  int _calculateStepSize(int maxAbsolute) {
    if (maxAbsolute == 0) return 1;

    // Calculate minimum step size to satisfy division constraint:
    // divisions = 2 * maxAbsolute / stepSize <= maxDivisions
    // stepSize >= 2 * maxAbsolute / maxDivisions
    final minStepSize = (2 * maxAbsolute / maxDivisions).ceil();

    // Round up to the next nice value
    return _roundUpToNiceStep(minStepSize);
  }

  /// Rounds up to the next "nice" step size.
  ///
  /// Nice values follow the pattern: 1, 5, 10, 50, 100, 500, 1000, etc.
  /// Returns the smallest nice value >= minStepSize.
  int _roundUpToNiceStep(int minStepSize) {
    if (minStepSize <= 1) return 1;

    // Find the order of magnitude
    final logValue = log(minStepSize) / ln10;
    final orderOfMagnitude = pow(10, logValue.floor()).toInt();

    // Check candidates in order: 1×magnitude, 5×magnitude, 10×magnitude
    final candidates = [
      orderOfMagnitude,
      5 * orderOfMagnitude,
      10 * orderOfMagnitude,
    ];

    // Return first candidate >= minStepSize
    for (final candidate in candidates) {
      if (candidate >= minStepSize) {
        return candidate;
      }
    }

    // Fallback (shouldn't happen due to 10× candidate)
    return 10 * orderOfMagnitude;
  }

  /// Calculates the number of divisions for the slider.
  ///
  /// Ensures enough divisions exist so that the slider can get within
  /// half a step of any target value, allowing _snapToStep to work correctly.
  int _calculateDivisions(int maxAbsolute, int stepSize) {
    if (maxAbsolute == 0 || stepSize == 0) return 1;

    // To reliably snap to every step, we need the slider resolution
    // (maxAbsolute / divisions) to be at most stepSize / 2.
    // This ensures we can get within half a step of any target.
    // Solving: maxAbsolute / divisions <= stepSize / 2
    // divisions >= 2 * maxAbsolute / stepSize
    final minDivisions = (2 * maxAbsolute / stepSize).ceil();

    final divisions = minDivisions < maxDivisions ? minDivisions : maxDivisions;

    return divisions > 0 ? divisions : 1;
  }

  /// Snaps a value to the nearest multiple of step size.
  ///
  /// Always allows selecting the exact maxAbsolute value.
  int _snapToStep(int value, int stepSize, int maxAbsolute) {
    // If we're exactly at max, return it
    if (value == maxAbsolute) {
      return maxAbsolute;
    }

    // If we're very close to max (within half a step), snap to max
    if (value > maxAbsolute - stepSize ~/ 2) {
      return maxAbsolute;
    }

    // Round to nearest multiple of step size
    final remainder = value % stepSize;
    final snapped = remainder < stepSize / 2
        ? value - remainder
        : value - remainder + stepSize;

    // Don't exceed maxAbsolute
    return snapped > maxAbsolute ? maxAbsolute : snapped;
  }
}
