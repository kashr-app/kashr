import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:flutter/material.dart';

/// Displays a status message about the tag allocation progress.
///
/// Shows one of three states:
/// - Perfectly allocated (total matches turnover)
/// - Exceeded (total exceeds turnover)
/// - Remaining (total is less than turnover)
class StatusMessage extends StatelessWidget {
  final TurnoverTagsState state;
  final Turnover turnover;

  const StatusMessage({
    required this.state,
    required this.turnover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = Currency.currencyFrom(turnover.amountUnit);

    final totalAbsolute = state.totalTagAmount.abs();
    final turnoverAbsolute = turnover.amountValue.abs();
    final difference = (totalAbsolute - turnoverAbsolute).abs();

    final isExceeded = state.isAmountExceeded;
    final isPerfect = totalAbsolute == turnoverAbsolute;

    if (isPerfect) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Perfectly allocated!',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    if (isExceeded) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Exceeds by ${currency.format(difference, decimalDigits: 2)}',
              style: TextStyle(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Remaining: ${currency.format(difference, decimalDigits: 2)}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
