import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/core/color_utils.dart';
import 'package:finanalyzer/core/widgets/period_selector.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_sort.dart';
import 'package:finanalyzer/turnover/model/tag_turnovers_filter.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
            PeriodSelector(
              locked: lockedFilters.period != null,
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
                  if (sort != TagTurnoverSort.defaultSort)
                    InputChip(
                      avatar: Icon(
                        size: 18,
                        sort.direction == TagTurnoverSortDirection.asc
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                      label: Text(sort.orderBy.label()),
                      onDeleted: () =>
                          onSortChanged(TagTurnoverSort.defaultSort),
                      onPressed: () {
                        onSortChanged(sort.toggleDirection());
                      },
                    ),
                  if (filter.searchQuery != null &&
                      filter.searchQuery!.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.search, size: 18),
                      label: Text(filter.searchQuery!),
                      onDeleted: lockedFilters.searchQuery == null
                          ? () => onFilterChanged(
                              filter.copyWith(searchQuery: null),
                            )
                          : null,
                    ),
                  if (filter.transferTagOnly == true)
                    Chip(
                      label: const Text('Has Transfer Tag'),
                      onDeleted: lockedFilters.transferTagOnly != true
                          ? () => onFilterChanged(
                              filter.copyWith(transferTagOnly: null),
                            )
                          : null,
                    ),
                  if (filter.unfinishedTransfersOnly == true)
                    Chip(
                      label: const Text('Unfinished Transfers'),
                      onDeleted: lockedFilters.unfinishedTransfersOnly != true
                          ? () => onFilterChanged(
                              filter.copyWith(unfinishedTransfersOnly: null),
                            )
                          : null,
                    ),
                  if (filter.isMatched == true)
                    Chip(
                      label: const Text('Done'),
                      onDeleted: lockedFilters.isMatched == null
                          ? () => onFilterChanged(
                              filter.copyWith(isMatched: null),
                            )
                          : null,
                    ),
                  if (filter.isMatched == false)
                    Chip(
                      label: const Text('Pending'),
                      onDeleted: lockedFilters.isMatched == null
                          ? () => onFilterChanged(
                              filter.copyWith(isMatched: null),
                            )
                          : null,
                    ),
                  if (filter.sign != null)
                    Chip(
                      label: Text(
                        filter.sign == TurnoverSign.income
                            ? 'Income'
                            : 'Expense',
                      ),
                      onDeleted: lockedFilters.sign == null
                          ? () => onFilterChanged(filter.copyWith(sign: null))
                          : null,
                    ),
                  if (filter.tagIds != null)
                    ...filter.tagIds!.map(
                      (tagId) => _TagFilterChip(
                        tag: tagById[tagId],
                        onDeleted: (lockedFilters.tagIds ?? []).contains(tagId)
                            ? null
                            : () => _removeTagFilter(tagId),
                      ),
                    ),
                  if (filter.accountIds != null)
                    ...filter.accountIds!.map(
                      (accountId) => _AccountFilterChip(
                        accountId: accountId,
                        onDeleted:
                            (lockedFilters.accountIds ?? []).contains(accountId)
                            ? null
                            : () => _removeAccountFilter(accountId),
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

  void _removeAccountFilter(UuidValue accountId) {
    final updatedAccountIds = List<UuidValue>.from(filter.accountIds ?? [])
      ..remove(accountId);
    onFilterChanged(
      filter.copyWith(
        accountIds: updatedAccountIds.isEmpty ? null : updatedAccountIds,
      ),
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  const _TagFilterChip({required this.tag, required this.onDeleted});

  final Tag? tag;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final tagName = tag?.name ?? 'Unknown';
    final tagColor = ColorUtils.parseColor(tag?.color) ?? Colors.grey;

    return Chip(
      label: Text(tagName),
      backgroundColor: tagColor.withValues(alpha: 0.2),
      side: BorderSide(color: tagColor, width: 1.5),
      onDeleted: onDeleted,
    );
  }
}

class _AccountFilterChip extends StatelessWidget {
  const _AccountFilterChip({required this.accountId, required this.onDeleted});

  final UuidValue accountId;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<AccountRepository>().getAccountById(accountId),
      builder: (context, snapshot) {
        final account = snapshot.data;
        final accountName = account?.name ?? 'Unknown';

        return Chip(
          avatar: Icon(
            account?.accountType.icon ?? Icons.account_balance,
            size: 18,
          ),
          label: Text(accountName),
          onDeleted: onDeleted,
        );
      },
    );
  }
}
