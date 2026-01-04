import 'package:decimal/decimal.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/home/widgets/turnover_summary_card.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';

/// A card widget that displays income summary with total and per-tag breakdown.
class IncomeSummaryCard extends StatelessWidget {
  final Decimal totalIncome;
  final Decimal unallocatedIncome;
  final List<TagSummary> tagSummaries;
  final Period period;
  final String currencyCode;

  const IncomeSummaryCard({
    required this.totalIncome,
    required this.unallocatedIncome,
    required this.tagSummaries,
    required this.period,
    this.currencyCode = 'EUR',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TurnoverSummaryCard(
      totalAmount: totalIncome,
      unallocatedAmount: unallocatedIncome,
      tagSummaries: tagSummaries,
      period: period,
      currencyCode: currencyCode,
      title: 'Total Income',
      subtitle: 'Income by Tag',
      emptyMessage: 'No income this period',
      turnoverSign: TurnoverSign.income,
      onHeaderTap: () {
        TurnoversRoute(
          filter: TurnoverFilter(sign: TurnoverSign.income, period: period),
        ).go(context);
      },
    );
  }
}
