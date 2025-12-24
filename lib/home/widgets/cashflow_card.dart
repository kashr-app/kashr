import 'package:decimal/decimal.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/year_month.dart';
import 'package:kashr/turnover/tag_turnovers_page.dart';
import 'package:flutter/material.dart';

/// A card widget that displays the cashflow (income - expenses) for the month.
class CashflowCard extends StatelessWidget {
  final YearMonth period;
  final Decimal totalIncome;
  final Decimal totalExpenses;
  final int tagTurnoverCount;
  final String currencyCode;

  const CashflowCard({
    required this.period,
    required this.totalIncome,
    required this.totalExpenses,
    required this.tagTurnoverCount,
    this.currencyCode = 'EUR',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final currency = Currency.currencyFrom(currencyCode);
    final theme = Theme.of(context);
    final cashflow = totalIncome - totalExpenses;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cashflow',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  child: Row(
                    children: [
                      Text(
                        '$tagTurnoverCount',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onPressed: () => TagTurnoversRoute(
                    filter: TagTurnoversFilter(period: period),
                  ).push(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currency.format(cashflow),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).decimalColor(cashflow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
