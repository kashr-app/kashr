import 'package:finanalyzer/core/color_utils.dart';
import 'package:finanalyzer/core/widgets/period_selector.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Displays active filter and sort chips for the turnovers list.
class TurnoversFilterChips extends StatelessWidget {
  const TurnoversFilterChips({
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
    super.key,
  });

  final TurnoverFilter filter;
  final TurnoverSort sort;
  final ValueChanged<TurnoverFilter> onFilterChanged;
  final ValueChanged<TurnoverSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filter.period != null) ...[
            PeriodSelector(
              selectedPeriod: filter.period!,
              onPreviousMonth: () => _navigatePeriod(context, -1),
              onNextMonth: () => _navigatePeriod(context, 1),
              onMonthSelected: (yearMonth) =>
                  onFilterChanged(filter.copyWith(period: yearMonth)),
              onAction: OnAction(
                tooltip: 'Clear period filter',
                onAction: () => onFilterChanged(filter.copyWith(period: null)),
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(height: 8),
          ],
          BlocBuilder<TagCubit, TagState>(
            builder: (context, tagState) {
              final tagById = tagState.tagById;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (sort != TurnoverSort.defaultSort)
                    InputChip(
                      avatar: Icon(
                        size: 18,
                        sort.direction == SortDirection.asc
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                      label: Text(sort.orderBy.label()),
                      onDeleted: () => onSortChanged(TurnoverSort.defaultSort),
                      onPressed: () {
                        onSortChanged(sort.toggleDirection());
                      },
                    ),
                  if (filter.searchQuery != null &&
                      filter.searchQuery!.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.search, size: 18),
                      label: Text(filter.searchQuery!),
                      onDeleted: () =>
                          onFilterChanged(filter.copyWith(searchQuery: null)),
                    ),
                  if (filter.unallocatedOnly == true)
                    Chip(
                      label: const Text('Unallocated'),
                      onDeleted: () => onFilterChanged(
                        filter.copyWith(unallocatedOnly: null),
                      ),
                    ),
                  if (filter.tagIds != null)
                    ...filter.tagIds!.map(
                      (tagId) => _TagFilterChip(
                        tag: tagById[tagId],
                        onDeleted: () => _removeTagFilter(tagId),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigatePeriod(BuildContext context, int delta) {
    final currentPeriod = filter.period!;
    final newMonth = currentPeriod.month + delta;

    final YearMonth newPeriod;
    if (newMonth < 1) {
      newPeriod = YearMonth(year: currentPeriod.year - 1, month: 12);
    } else if (newMonth > 12) {
      newPeriod = YearMonth(year: currentPeriod.year + 1, month: 1);
    } else {
      newPeriod = YearMonth(year: currentPeriod.year, month: newMonth);
    }

    onFilterChanged(filter.copyWith(period: newPeriod));
  }

  void _removeTagFilter(UuidValue tagId) {
    final updatedTagIds = List<UuidValue>.from(filter.tagIds ?? [])
      ..remove(tagId);
    onFilterChanged(
      filter.copyWith(tagIds: updatedTagIds.isEmpty ? null : updatedTagIds),
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  const _TagFilterChip({required this.tag, required this.onDeleted});

  final Tag? tag;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final tagName = tag?.name ?? 'Unkown';
    final tagColor = ColorUtils.parseColor(tag?.color) ?? Colors.grey;

    return Chip(
      label: Text(tagName),
      backgroundColor: tagColor.withValues(alpha: 0.2),
      side: BorderSide(color: tagColor, width: 1.5),
      onDeleted: onDeleted,
    );
  }
}
