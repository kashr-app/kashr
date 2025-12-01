import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:flutter/material.dart';

/// A dialog for confirming savings deletion with clear implications.
///
/// Reusable dialog that shows what happens when savings are deleted:
/// - Virtual bookings are returned to account balances
/// - Tag turnovers remain but no longer count toward savings
class DeleteSavingsDialog extends StatelessWidget {
  final Savings savings;
  final Tag tag;
  final Decimal currentBalance;

  const DeleteSavingsDialog({
    super.key,
    required this.savings,
    required this.tag,
    required this.currentBalance,
  });

  /// Shows the dialog and returns true if user confirms deletion.
  static Future<bool> show(
    BuildContext context, {
    required Savings savings,
    required Tag tag,
    required Decimal currentBalance,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteSavingsDialog(
        savings: savings,
        tag: tag,
        currentBalance: currentBalance,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasGoal = savings.goalValue != null;
    final goalCurrency =
        savings.goalUnit != null ? Currency.currencyFrom(savings.goalUnit!) : null;

    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
        size: 48,
      ),
      title: const Text('Delete Savings?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              label: 'Tag',
              value: tag.name,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Current Balance',
              value: Currency.EUR.format(currentBalance),
            ),
            if (hasGoal && savings.goalValue != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Goal',
                value: goalCurrency?.format(savings.goalValue!) ??
                    savings.goalValue!.toString(),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action will:',
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BulletPoint(
                    text: 'Return all virtual bookings to the account balances where they were allocated from',
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 4),
                  _BulletPoint(
                    text: 'Keep all tag turnovers, but they will no longer count toward savings',
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(height: 4),
                  _BulletPoint(
                    text: 'This action cannot be undone',
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: const Text('Delete Savings'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final Color color;

  const _BulletPoint({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Icons.circle,
            size: 6,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
