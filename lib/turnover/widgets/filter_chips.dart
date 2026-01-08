import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/core/color_utils.dart';
import 'package:kashr/core/widgets/period_selector.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:uuid/uuid_value.dart';

/// Displays the current sort configuration as a chip.
///
/// Shows an arrow icon indicating sort direction. Tapping toggles the
/// direction, and the delete button clears the sort.
class SortFilterChip extends StatelessWidget {
  const SortFilterChip({
    required this.label,
    required this.isAscending,
    required this.onDeleted,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isAscending;
  final VoidCallback onDeleted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Icon(
        size: 18,
        isAscending ? Icons.arrow_downward : Icons.arrow_upward,
      ),
      label: Text(label),
      onDeleted: onDeleted,
      onPressed: onPressed,
    );
  }
}

/// Displays a search query as a filter chip.
class SearchFilterChip extends StatelessWidget {
  const SearchFilterChip({
    required this.query,
    required this.onDeleted,
    this.locked = false,
    super.key,
  });

  final String query;
  final VoidCallback onDeleted;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return TextFilterChip(
      avatar: const Icon(Icons.search, size: 18),
      label: query,
      locked: locked,
      onDeleted: onDeleted,
    );
  }
}

/// Displays a simple text label as a filter chip.
class TextFilterChip extends StatelessWidget {
  const TextFilterChip({
    required this.label,
    required this.onDeleted,
    this.locked = false,
    this.avatar,
    super.key,
  });

  final String label;
  final VoidCallback onDeleted;
  final bool locked;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: avatar,
      label: Text(label),
      onDeleted: locked ? null : onDeleted,
    );
  }
}

/// Displays a period selector for filtering.
///
/// Includes navigation buttons, period selection, and a clear action.
class PeriodFilterWidget extends StatelessWidget {
  const PeriodFilterWidget({
    required this.period,
    required this.onChanged,
    required this.onClear,
    this.locked = false,
    super.key,
  });

  final Period period;
  final ValueChanged<Period> onChanged;
  final VoidCallback onClear;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return PeriodSelector(
      locked: locked,
      selectedPeriod: period,
      onPeriodSelected: onChanged,
      onAction: OnAction(
        tooltip: 'Clear period filter',
        onAction: onClear,
        icon: const Icon(Icons.delete),
      ),
    );
  }
}

class TagFilterChip extends StatelessWidget {
  const TagFilterChip({
    super.key,
    required this.tag,
    required this.onDeleted,
    this.locked = false,
  });

  final Tag? tag;
  final VoidCallback? onDeleted;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final tagName = tag?.name ?? 'Unknown';
    final tagColor = ColorUtils.parseColor(tag?.color) ?? Colors.grey;

    return Chip(
      label: Text(tagName),
      backgroundColor: tagColor.withValues(alpha: 0.2),
      side: BorderSide(color: tagColor, width: 1.5),
      onDeleted: locked ? null : onDeleted,
    );
  }
}

class AccountFilterChip extends StatelessWidget {
  const AccountFilterChip({
    super.key,
    required this.accountId,
    required this.onDeleted,
    this.locked = false,
  });

  final UuidValue accountId;
  final VoidCallback? onDeleted;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final account = state.accountById[accountId];
        final accountName = account?.name ?? 'Unknown';

        return Chip(
          avatar: Icon(
            account?.accountType.icon ?? Icons.account_balance,
            size: 18,
          ),
          label: Text(accountName),
          onDeleted: locked ? null : onDeleted,
        );
      },
    );
  }
}

/// Removes [itemToRemove] from [list].
///
/// returns null if the result would be an empty list
List<T>? removeItem<T>(List<T>? list, T itemToRemove) {
  final updated = list?.where(((it) => it != itemToRemove));
  return updated?.isNotEmpty == false ? updated!.toList() : null;
}
