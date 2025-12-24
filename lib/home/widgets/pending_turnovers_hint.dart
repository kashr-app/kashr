import 'package:decimal/decimal.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/turnover/pending_turnovers_page.dart';
import 'package:flutter/material.dart';

class PendingTurnoversHint extends StatelessWidget {
  final int count;
  final Decimal totalAmount;
  const PendingTurnoversHint({
    super.key,
    required this.count,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = Currency.currencyFrom('EUR');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => const PendingTurnoversRoute().go(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.pending_outlined,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count pending '
                    '(${currency.format(totalAmount)})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
