import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/model/tag_turnover_sort.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/turnover/widgets/filter_chips.dart';
import 'package:uuid/uuid.dart';

/// Displays active filter and sort chips for the tag turnovers list.
class TagTurnoversFilterChips extends StatelessWidget {
  const TagTurnoversFilterChips({
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
    this.lockedFilters = TagTurnoversFilter.empty,
    super.key,
  });

  final TagTurnoversFilter filter;
  final TagTurnoverSort sort;
  final ValueChanged<TagTurnoversFilter> onFilterChanged;
  final ValueChanged<TagTurnoverSort> onSortChanged;

  /// Filters that are locked and cannot be cleared by the user.
  final TagTurnoversFilter lockedFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (filter.period != null) ...[
            PeriodFilterWidget(
              locked: lockedFilters.period != null,
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
                  if (sort != TagTurnoverSort.defaultSort)
                    SortFilterChip(
                      label: sort.orderBy.label(),
                      isAscending:
                          sort.direction == TagTurnoverSortDirection.asc,
                      onDeleted: () =>
                          onSortChanged(TagTurnoverSort.defaultSort),
                      onPressed: () {
                        onSortChanged(sort.toggleDirection());
                      },
                    ),
                  if (filter.searchQuery?.isNotEmpty == true)
                    SearchFilterChip(
                      query: filter.searchQuery!,
                      locked: lockedFilters.searchQuery != null,
                      onDeleted: () =>
                          onFilterChanged(filter.copyWith(searchQuery: null)),
                    ),
                  if (filter.transferTagOnly == true)
                    TextFilterChip(
                      label: 'Has Transfer Tag',
                      locked: lockedFilters.transferTagOnly == true,
                      onDeleted: () => onFilterChanged(
                        filter.copyWith(transferTagOnly: null),
                      ),
                    ),
                  if (filter.unfinishedTransfersOnly == true)
                    TextFilterChip(
                      label: 'Unfinished Transfers',
                      locked: lockedFilters.unfinishedTransfersOnly == true,
                      onDeleted: () => onFilterChanged(
                        filter.copyWith(unfinishedTransfersOnly: null),
                      ),
                    ),
                  if (filter.isMatched == true)
                    TextFilterChip(
                      label: 'Done',
                      locked: lockedFilters.isMatched != null,
                      onDeleted: () =>
                          onFilterChanged(filter.copyWith(isMatched: null)),
                    ),
                  if (filter.isMatched == false)
                    TextFilterChip(
                      label: 'Pending',
                      locked: lockedFilters.isMatched != null,
                      onDeleted: () =>
                          onFilterChanged(filter.copyWith(isMatched: null)),
                    ),
                  if (filter.sign != null)
                    TextFilterChip(
                      avatar: filter.sign!.icon(),
                      label: filter.sign!.title(),
                      locked: lockedFilters.sign != null,
                      onDeleted: () =>
                          onFilterChanged(filter.copyWith(sign: null)),
                    ),
                  if (filter.tagIds != null)
                    ...filter.tagIds!.map(
                      (tagId) => TagFilterChip(
                        tag: tagById[tagId],
                        locked: lockedFilters.tagIds?.contains(tagId) ?? false,
                        onDeleted: () => _removeTagFilter(tagId),
                      ),
                    ),
                  if (filter.accountIds != null)
                    ...filter.accountIds!.map(
                      (accountId) => AccountFilterChip(
                        accountId: accountId,
                        locked:
                            lockedFilters.accountIds?.contains(accountId) ??
                            false,
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
