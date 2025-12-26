import 'package:decimal/decimal.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/home/widgets/dashboard_hint.dart';
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

    return DashboardHint(
      icon: Icon(Icons.pending_outlined),
      title: '$count pending (${currency.formatCompact(totalAmount)})',
      color: theme.colorScheme.onSecondaryContainer,
      colorBackground: theme.colorScheme.secondaryContainer.withValues(
        alpha: 0.5,
      ),
      onTap: () => const PendingTurnoversRoute().go(context),
    );
  }
}
