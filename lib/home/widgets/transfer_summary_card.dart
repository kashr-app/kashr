import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/home/widgets/tag_summary_row.dart';
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

/// A card widget that displays transfer summary with per-tag breakdown.
class TransferSummaryCard extends StatelessWidget {
  final Decimal totalTransfers;
  final List<TagSummary> tagSummaries;
  final YearMonth selectedPeriod;
  final String currencyCode;

  const TransferSummaryCard({
    required this.totalTransfers,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Transfers',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currency.format(totalTransfers),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (tagSummaries.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Transfers by Tag',
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
                        children: _buildSortedRows(context, currency, tagById),
                      );
                    })(),
                  };
                },
              ),
            ],
            if (tagSummaries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No transfers this month',
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
    Map<UuidValue, Tag> tagById,
  ) {
    // Create a list of items with their amounts for sorting
    final items = <({Decimal amount, Widget widget})>[];

    // Add all tag items
    for (final summary in tagSummaries) {
      final tagId = summary.tagId;
      items.add((
        amount: summary.totalAmount.abs(),
        widget: TagSummaryRow(
          tag: tagById[tagId],
          amount: summary.totalAmount,
          totalAmount: totalTransfers,
          currency: currency,
          onTap: () {
            TurnoversRoute(
              filter: TurnoverFilter(
                tagIds: [tagId],
                period: selectedPeriod,
              ),
            ).go(context);
          },
          // No onTap for transfers - they're not filtered in turnovers
        ),
      ));
    }

    // Sort by amount descending
    items.sort((a, b) => b.amount.compareTo(a.amount));

    // Return just the widgets
    return items.map((item) => item.widget).toList();
  }
}
