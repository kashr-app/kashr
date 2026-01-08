import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/turnover_sort.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/turnover/widgets/filter_chips.dart';
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
            PeriodFilterWidget(
              period: filter.period!,
              onChanged: (period) =>
                  onFilterChanged(filter.copyWith(period: period)),
              onClear: () => onFilterChanged(filter.copyWith(period: null)),
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
                    SortFilterChip(
                      label: sort.orderBy.label(),
                      isAscending: sort.direction == SortDirection.asc,
                      onDeleted: () => onSortChanged(TurnoverSort.defaultSort),
                      onPressed: () {
                        onSortChanged(sort.toggleDirection());
                      },
                    ),
                  if (filter.searchQuery?.isNotEmpty == true)
                    SearchFilterChip(
                      query: filter.searchQuery!,
                      onDeleted: () =>
                          onFilterChanged(filter.copyWith(searchQuery: null)),
                    ),
                  if (filter.unallocatedOnly == true)
                    TextFilterChip(
                      label: 'Unallocated',
                      onDeleted: () => onFilterChanged(
                        filter.copyWith(unallocatedOnly: null),
                      ),
                    ),
                  if (filter.sign != null)
                    TextFilterChip(
                      avatar: filter.sign!.icon(),
                      label: filter.sign!.title(),
                      onDeleted: () =>
                          onFilterChanged(filter.copyWith(sign: null)),
                    ),
                  if (filter.tagIds != null)
                    ...filter.tagIds!.map(
                      (tagId) => TagFilterChip(
                        tag: tagById[tagId],
                        onDeleted: () => _removeTagFilter(tagId),
                      ),
                    ),
                  if (filter.accountIds != null)
                    ...filter.accountIds!.map(
                      (accountId) => AccountFilterChip(
                        accountId: accountId,
                        onDeleted: () => _removeAccountFilter(accountId),
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

  void _removeTagFilter(UuidValue tagId) {
    onFilterChanged(filter.copyWith(tagIds: removeItem(filter.tagIds, tagId)));
  }

  void _removeAccountFilter(UuidValue accountId) {
    onFilterChanged(
      filter.copyWith(accountIds: removeItem(filter.accountIds, accountId)),
    );
  }
}
