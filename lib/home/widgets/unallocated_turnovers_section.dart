import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/turnovers_page.dart';
import 'package:finanalyzer/turnover/widgets/turnover_card.dart';
import 'package:flutter/material.dart';

/// A section widget that displays unallocated turnovers requiring user attention.
class UnallocatedTurnoversSection extends StatelessWidget {
  final List<TurnoverWithTags> unallocatedTurnovers;
  final int unallocatedCount;
  final VoidCallback onRefresh;
  final YearMonth selectedPeriod;

  const UnallocatedTurnoversSection({
    required this.unallocatedTurnovers,
    required this.unallocatedCount,
    required this.onRefresh,
    required this.selectedPeriod,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (unallocatedTurnovers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.local_offer_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Tag ($unallocatedCount)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => TurnoversRoute(
                filter: TurnoverFilter(
                  unallocatedOnly: true,
                  period: selectedPeriod,
                ),
                sort: const TurnoverSort(
                  orderBy: SortField.amount,
                  direction: SortDirection.desc,
                ),
              ).go(context),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Display only ONE TurnoverCard (the first item, which is highest amount)
        TurnoverCard(
          turnoverWithTags: unallocatedTurnovers.first,
          onTap: () async {
            final turnoverId = unallocatedTurnovers.first.turnover.id;
            if (turnoverId != null) {
              await TurnoverTagsRoute(
                turnoverId: turnoverId.uuid,
              ).push(context);
              onRefresh();
            }
          },
        ),
      ],
    );
  }
}
