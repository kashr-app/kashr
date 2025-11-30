import 'package:decimal/decimal.dart';
import 'package:finanalyzer/home/widgets/turnover_summary_card.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';

/// A card widget that displays expenses summary with total and per-tag breakdown.
class SpendingSummaryCard extends StatelessWidget {
  final Decimal totalExpenses;
  final Decimal unallocatedExpenses;
  final List<TagSummary> tagSummaries;
  final YearMonth selectedPeriod;
  final String currencyCode;

  const SpendingSummaryCard({
    required this.totalExpenses,
    required this.unallocatedExpenses,
    required this.tagSummaries,
    required this.selectedPeriod,
    this.currencyCode = 'EUR',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TurnoverSummaryCard(
      totalAmount: totalExpenses,
      unallocatedAmount: unallocatedExpenses,
      tagSummaries: tagSummaries,
      selectedPeriod: selectedPeriod,
      currencyCode: currencyCode,
      title: 'Total Expenses',
      subtitle: 'Spending by Tag',
      emptyMessage: 'No expenses this month',
      turnoverSign: TurnoverSign.expense,
      onHeaderTap: () {
        TurnoversRoute(
          filter: TurnoverFilter(
            sign: TurnoverSign.expense,
            period: selectedPeriod,
          ),
        ).go(context);
      },
    );
  }
}
