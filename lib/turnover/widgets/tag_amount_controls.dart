import 'package:finanalyzer/core/amount_dialog.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
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

        return Row(
          children: [
            Expanded(
              child: Text(
                tagTurnover.format(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isPerfect &&
                ((isExceeded && currentAbsolute > 0) ||
                    (!isExceeded && currentAbsolute < maxAbsolute)))
              IconButton(
                icon: Icon(
                  isExceeded ? Icons.remove : Icons.add,
                  size: 20,
                ),
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
      newAbsoluteAmount =
          (currentAbsolute - exceededAmountScaled).clamp(0, maxAbsolute);
    } else {
      // Calculate remaining uncovered amount
      final totalTagAmountScaled = decimalScale(state.totalTagAmount) ?? 0;
      final remainingScaled = maxAbsolute - totalTagAmountScaled.abs();
      // Add remaining to current amount, clamped to max
      newAbsoluteAmount = (currentAbsolute + remainingScaled)
          .clamp(0, maxAbsolute);
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
    );

    if (result != null && context.mounted) {
      // Apply the sign of the turnover to the result
      final signedResult = isNegative ? -result : result;
      context
          .read<TurnoverTagsCubit>()
          .updateTagTurnoverAmount(tagTurnover.id, signedResult);
    }
  }
}
