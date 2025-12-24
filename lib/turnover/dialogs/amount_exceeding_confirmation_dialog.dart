import 'package:decimal/decimal.dart';
import 'package:kashr/core/currency.dart';
import 'package:flutter/material.dart';

enum AmountExceedingAction {
  scaleDown,
  cancel,
}

class AmountExceedingConfirmationDialog extends StatelessWidget {
  final Decimal totalAmount;
  final Decimal turnoverAmount;
  final Decimal exceedingAmount;
  final String currencyUnit;

  const AmountExceedingConfirmationDialog({
    required this.totalAmount,
    required this.turnoverAmount,
    required this.exceedingAmount,
    required this.currencyUnit,
    super.key,
  });

  static Future<AmountExceedingAction?> show(
    BuildContext context, {
    required Decimal totalAmount,
    required Decimal turnoverAmount,
    required Decimal exceedingAmount,
    required String currencyUnit,
  }) {
    return showDialog<AmountExceedingAction>(
      context: context,
      builder: (context) => AmountExceedingConfirmationDialog(
        totalAmount: totalAmount,
        turnoverAmount: turnoverAmount,
        exceedingAmount: exceedingAmount,
        currencyUnit: currencyUnit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = Currency.currencyFrom(currencyUnit);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Amount Exceeded')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The total amount of selected tag turnovers exceeds the turnover amount.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _AmountRow(
            label: 'Turnover Amount',
            amount: turnoverAmount,
            currency: currency,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          _AmountRow(
            label: 'Total Tag Turnovers',
            amount: totalAmount,
            currency: currency,
            color: theme.colorScheme.error,
            bold: true,
          ),
          const SizedBox(height: 8),
          _AmountRow(
            label: 'Exceeding By',
            amount: exceedingAmount,
            currency: currency,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The newly selected tag turnovers will be scaled down proportionally to fit within the available amount.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(AmountExceedingAction.cancel),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(AmountExceedingAction.scaleDown),
          child: const Text('Scale Down & Add'),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final Decimal amount;
  final Currency currency;
  final Color color;
  final bool bold;

  const _AmountRow({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          currency.format(amount),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
