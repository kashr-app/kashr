import 'package:decimal/decimal.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/home/widgets/turnover_summary_card.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';

/// A card widget that displays expenses summary with total and per-tag breakdown.
class SpendingSummaryCard extends StatelessWidget {
  final Decimal totalExpenses;
  final Decimal unallocatedExpenses;
  final List<TagSummary> tagSummaries;
  final Period period;
  final String currencyCode;

  const SpendingSummaryCard({
    required this.totalExpenses,
    required this.unallocatedExpenses,
    required this.tagSummaries,
    required this.period,
    this.currencyCode = 'EUR',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TurnoverSummaryCard(
      totalAmount: totalExpenses,
      unallocatedAmount: unallocatedExpenses,
      tagSummaries: tagSummaries,
      period: period,
      currencyCode: currencyCode,
      title: 'Total Expenses',
      subtitle: 'Spending by Tag',
      emptyMessage: 'No expenses this period',
      turnoverSign: TurnoverSign.expense,
      onHeaderTap: () {
        TurnoversRoute(
          filter: TurnoverFilter(sign: TurnoverSign.expense, period: period),
        ).go(context);
      },
    );
  }
}
