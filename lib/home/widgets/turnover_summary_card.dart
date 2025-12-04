import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/home/widgets/tag_summary_row.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// A reusable card widget that displays turnover summary with total and
/// per-tag breakdown.
///
/// This widget serves as a base for both income and expense summary cards,
/// providing common layout and functionality.
class TurnoverSummaryCard extends StatelessWidget {
  final Decimal totalAmount;
  final Decimal unallocatedAmount;
  final List<TagSummary> tagSummaries;
  final YearMonth selectedPeriod;
  final String currencyCode;
  final String title;
  final String subtitle;
  final String emptyMessage;
  final TurnoverSign turnoverSign;
  final VoidCallback? onHeaderTap;

  const TurnoverSummaryCard({
    required this.totalAmount,
    required this.unallocatedAmount,
    required this.tagSummaries,
    required this.selectedPeriod,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.turnoverSign,
    this.currencyCode = 'EUR',
    this.onHeaderTap,
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
            InkWell(
              onTap: onHeaderTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currency.format(totalAmount),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.decimalColor(totalAmount),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (tagSummaries.isNotEmpty ||
                unallocatedAmount != Decimal.zero) ...[
              const SizedBox(height: 24),
              Text(
                subtitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              BlocBuilder<TagCubit, TagState>(
                builder: (context, tagState) {
                  return switch (tagState.status) {
                    Status.initial ||
                    Status.loading => CircularProgressIndicator(),
                    Status.error => Text('Could not load tags'),
                    Status.success => (() {
                      final tagById = tagState.tagById;
                      return Column(
                        children: _buildSortedRows(
                          context,
                          currency,
                          theme,
                          tagById,
                        ),
                      );
                    })(),
                  };
                },
              ),
            ],
            if (tagSummaries.isEmpty && unallocatedAmount == Decimal.zero)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    emptyMessage,
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
    Map<UuidValue, Tag> tagById,
  ) {
    // Create a list of items with their amounts for sorting
    final items = <({Decimal amount, Widget widget})>[];

    // Add all tag items
    for (final summary in tagSummaries) {
      items.add((
        amount: summary.totalAmount.abs(),
        widget: _buildTagRow(context, summary, tagById, currency, theme),
      ));
    }

    // Add unallocated item if it exists
    if (unallocatedAmount != Decimal.zero) {
      items.add((
        amount: unallocatedAmount.abs(),
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
    Map<UuidValue, Tag> tagById,
    Currency currency,
    ThemeData theme,
  ) {
    final tagId = summary.tagId;
    return TagSummaryRow(
      tag: tagById[tagId],
      amount: summary.totalAmount,
      totalAmount: totalAmount,
      currency: currency,
      onTap: () {
        TurnoversRoute(
          filter: TurnoverFilter(
            tagIds: [tagId.uuid],
            sign: turnoverSign,
            period: selectedPeriod,
          ),
        ).go(context);
      },
    );
  }

  Widget _buildUnallocatedRow(
    BuildContext context,
    Currency currency,
    ThemeData theme,
  ) {
    return TagSummaryRow(
      isUnallocated: true,
      amount: unallocatedAmount,
      totalAmount: totalAmount,
      currency: currency,
      onTap: () {
        TurnoversRoute(
          filter: TurnoverFilter(
            unallocatedOnly: true,
            sign: turnoverSign,
            period: selectedPeriod,
          ),
        ).go(context);
      },
    );
  }
}
