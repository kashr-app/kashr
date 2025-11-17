import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:flutter/material.dart';

/// A card widget that displays the cashflow (income - expenses) for the month.
class CashflowCard extends StatelessWidget {
  final Decimal totalIncome;
  final Decimal totalExpenses;
  final String currencyCode;

  const CashflowCard({
    required this.totalIncome,
    required this.totalExpenses,
    this.currencyCode = 'EUR',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final currency = Currency.currencyFrom(currencyCode);
    final theme = Theme.of(context);
    final cashflow = totalIncome - totalExpenses;

    // Determine color based on cashflow value
    final Color cashflowColor;
    if (cashflow > Decimal.zero) {
      cashflowColor = theme.colorScheme.primary;
    } else if (cashflow < Decimal.zero) {
      cashflowColor = theme.colorScheme.error;
    } else {
      cashflowColor = theme.colorScheme.onSurfaceVariant;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cashflow',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currency.format(cashflow),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cashflowColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
