import 'package:decimal/decimal.dart';
import 'package:finanalyzer/home/widgets/turnover_summary_card.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';

/// A card widget that displays income summary with total and per-tag breakdown.
class IncomeSummaryCard extends StatelessWidget {
  final Decimal totalIncome;
  final Decimal unallocatedIncome;
  final List<TagSummary> tagSummaries;
  final YearMonth selectedPeriod;
  final String currencyCode;

  const IncomeSummaryCard({
    required this.totalIncome,
    required this.unallocatedIncome,
    required this.tagSummaries,
    required this.selectedPeriod,
    this.currencyCode = 'EUR',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TurnoverSummaryCard(
      totalAmount: totalIncome,
      unallocatedAmount: unallocatedIncome,
      tagSummaries: tagSummaries,
      selectedPeriod: selectedPeriod,
      currencyCode: currencyCode,
      title: 'Total Income',
      amountColor: theme.colorScheme.primary,
      subtitle: 'Income by Tag',
      emptyMessage: 'No income this month',
      turnoverSign: TurnoverSign.income,
      onHeaderTap: () {
        TurnoversRoute(
          filter: TurnoverFilter(
            sign: TurnoverSign.income,
            period: selectedPeriod,
          ),
        ).go(context);
      },
    );
  }
}
