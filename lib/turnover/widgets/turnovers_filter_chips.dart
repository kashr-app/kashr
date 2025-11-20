import 'package:finanalyzer/core/widgets/period_selector.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
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
    required this.onSortDirectionToggled,
    super.key,
  });

  final TurnoverFilter filter;
  final TurnoverSort sort;
  final ValueChanged<TurnoverFilter> onFilterChanged;
  final VoidCallback onSortDirectionToggled;

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
              onAction: OnAction(
                tooltip: 'Clear period filter',
                onAction: () => onFilterChanged(filter.copyWith(period: null)),
                icon: const Icon(Icons.delete),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (sort != TurnoverSort.defaultSort)
                ActionChip(
                  avatar: Icon(
                    sort.direction == SortDirection.asc
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 18,
                  ),
                  label: Text(_getSortFieldName(sort.orderBy)),
                  onPressed: onSortDirectionToggled,
                ),
              if (filter.unallocatedOnly == true)
                Chip(
                  label: const Text('Unallocated'),
                  onDeleted: () => onFilterChanged(
                    filter.copyWith(unallocatedOnly: null),
                  ),
                ),
              if (filter.tagIds != null)
                ...filter.tagIds!.map((tagId) => _TagFilterChip(
                      tagId: tagId,
                      onDeleted: () => _removeTagFilter(tagId),
                    )),
            ],
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

  void _removeTagFilter(String tagId) {
    final updatedTagIds = List<String>.from(filter.tagIds ?? [])..remove(tagId);
    onFilterChanged(
      filter.copyWith(tagIds: updatedTagIds.isEmpty ? null : updatedTagIds),
    );
  }

  String _getSortFieldName(SortField field) {
    return switch (field) {
      SortField.bookingDate => 'Date',
      SortField.amount => 'Amount',
      SortField.counterPart => 'Counter Party',
    };
  }
}

class _TagFilterChip extends StatelessWidget {
  const _TagFilterChip({required this.tagId, required this.onDeleted});

  final String tagId;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<TagRepository>().getTagById(
            UuidValue.fromString(tagId),
          ),
      builder: (context, snapshot) {
        final tag = snapshot.data;
        final tagName = tag?.name ?? tagId.substring(0, 8);
        final tagColor = tag?.color != null
            ? Color(int.parse(tag!.color!.replaceFirst('#', '0xff')))
            : null;

        return Chip(
          label: Text(tagName),
          backgroundColor: tagColor?.withValues(alpha: 0.2),
          side: tagColor != null ? BorderSide(color: tagColor, width: 1.5) : null,
          onDeleted: onDeleted,
        );
      },
    );
  }
}
