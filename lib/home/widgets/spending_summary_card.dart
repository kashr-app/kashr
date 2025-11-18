import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home/widgets/tag_summary_row.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
              'Total Expenses',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currency.format(totalExpenses),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
            if (tagSummaries.isNotEmpty || unallocatedExpenses != Decimal.zero) ...[
              const SizedBox(height: 24),
              Text(
                'Spending by Tag',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ..._buildSortedRows(context, currency, theme),
            ],
            if (tagSummaries.isEmpty && unallocatedExpenses == Decimal.zero)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No expenses this month',
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
    if (unallocatedExpenses != Decimal.zero) {
      items.add((
        amount: unallocatedExpenses.abs(),
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
      totalAmount: totalExpenses,
      currency: currency,
      onTap: tagId != null
          ? () {
              TurnoversRoute(
                filter: TurnoverFilter(
                  tagIds: [tagId.uuid],
                  sign: TurnoverSign.expense,
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
      amount: unallocatedExpenses,
      totalAmount: totalExpenses,
      currency: currency,
      onTap: () {
        TurnoversRoute(
          filter: TurnoverFilter(
            unallocatedOnly: true,
            sign: TurnoverSign.expense,
            period: selectedPeriod,
          ),
        ).go(context);
      },
    );
  }
}
