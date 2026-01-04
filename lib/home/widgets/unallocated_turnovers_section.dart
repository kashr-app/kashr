import 'package:kashr/core/model/period.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/turnover_sort.dart';
import 'package:kashr/turnover/model/turnover_with_tag_turnovers.dart';
import 'package:kashr/turnover/turnover_tags_page.dart';
import 'package:kashr/turnover/turnovers_page.dart';
import 'package:kashr/turnover/widgets/turnover_card.dart';
import 'package:flutter/material.dart';

/// A section widget that displays unallocated turnovers requiring user attention.
class UnallocatedTurnoversSection extends StatelessWidget {
  final TurnoverWithTagTurnovers? firstUnallocatedTurnover;
  final int unallocatedCountInPeriod;
  final VoidCallback onRefresh;
  final Period period;

  const UnallocatedTurnoversSection({
    required this.firstUnallocatedTurnover,
    required this.unallocatedCountInPeriod,
    required this.onRefresh,
    required this.period,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final turnover = firstUnallocatedTurnover;

    if (turnover == null) {
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
                  'Quick Tag ($unallocatedCountInPeriod)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => TurnoversRoute(
                filter: TurnoverFilter(unallocatedOnly: true, period: period),
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
        TurnoverCard(
          turnoverWithTags: turnover,
          onTap: () async {
            final turnoverId = turnover.turnover.id;
            await TurnoverTagsRoute(turnoverId: turnoverId.uuid).push(context);
            onRefresh();
          },
        ),
      ],
    );
  }
}
