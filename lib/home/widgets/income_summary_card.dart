import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home/widgets/tag_summary_row.dart';
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
    final currency = Currency.currencyFrom(currencyCode);
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Income',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currency.format(totalIncome),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            if (tagSummaries.isNotEmpty || unallocatedIncome != Decimal.zero) ...[
              const SizedBox(height: 24),
              Text(
                'Income by Tag',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ..._buildSortedRows(context, currency, theme),
            ],
            if (tagSummaries.isEmpty && unallocatedIncome == Decimal.zero)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No income this month',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSortedRows(
    BuildContext context,
    Currency currency,
    ThemeData theme,
  ) {
    // Create a list of items with their amounts for sorting
    final items = <({Decimal amount, Widget widget})>[];

    // Add all tag items
    for (final summary in tagSummaries) {
      items.add((
        amount: summary.totalAmount.abs(),
        widget: _buildTagRow(context, summary, currency, theme),
      ));
    }

    // Add unallocated item if it exists
    if (unallocatedIncome != Decimal.zero) {
      items.add((
        amount: unallocatedIncome.abs(),
        widget: _buildUnallocatedRow(context, currency, theme),
      ));
    }

    // Sort by amount descending
    items.sort((a, b) => b.amount.compareTo(a.amount));

    // Return just the widgets
    return items.map((item) => item.widget).toList();
  }

  Widget _buildTagRow(
    BuildContext context,
    TagSummary summary,
    Currency currency,
    ThemeData theme,
  ) {
    final tagId = summary.tag.id;
    return TagSummaryRow(
      tag: summary.tag,
      amount: summary.totalAmount,
      totalAmount: totalIncome,
      currency: currency,
      onTap: tagId != null
          ? () {
              TurnoversRoute(
                filter: TurnoverFilter(
                  tagIds: [tagId.uuid],
                  sign: TurnoverSign.income,
                  period: selectedPeriod,
                ),
              ).go(context);
            }
          : null,
    );
  }

  Widget _buildUnallocatedRow(
    BuildContext context,
    Currency currency,
    ThemeData theme,
  ) {
    return TagSummaryRow(
      isUnallocated: true,
      amount: unallocatedIncome,
      totalAmount: totalIncome,
      currency: currency,
      onTap: () {
        TurnoversRoute(
          filter: TurnoverFilter(
            unallocatedOnly: true,
            sign: TurnoverSign.income,
            period: selectedPeriod,
          ),
        ).go(context);
      },
    );
  }
}
