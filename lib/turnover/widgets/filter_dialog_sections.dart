import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/core/color_utils.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/core/widgets/period_selector.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/dialogs/tag_picker_dialog.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:uuid/uuid.dart';

/// Shell for filter dialogs with consistent header and footer.
class FilterDialogShell extends StatelessWidget {
  const FilterDialogShell({
    required this.title,
    required this.content,
    required this.onClear,
    required this.onApply,
    super.key,
  });

  final String title;
  final Widget content;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: content,
              ),
            ),

            // Action buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: onClear, child: const Text('Clear')),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onApply,
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header with optional lock icon.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.locked = false, super.key});

  final String title;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (locked) ...[
          const SizedBox(width: 8),
          const Icon(Icons.lock, size: 16),
        ],
      ],
    );
  }
}

/// Dropdown for selecting turnover sign (Income/Expense/All).
class SignFilterSection extends StatelessWidget {
  const SignFilterSection({
    required this.value,
    required this.onChanged,
    this.locked = false,
    super.key,
  });

  final TurnoverSign? value;
  final ValueChanged<TurnoverSign?> onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionHeader(title: 'Type', locked: locked),
            const Spacer(),
            DropdownButton<TurnoverSign?>(
              value: value,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...TurnoverSign.values.map(
                  (it) => DropdownMenuItem(
                    value: it,
                    child: Row(
                      children: [
                        it.icon(size: 18),
                        SizedBox(width: 8),
                        Text(it.title()),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: locked ? null : onChanged,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Period filter with checkbox and picker.
class PeriodFilterSection extends StatelessWidget {
  const PeriodFilterSection({
    required this.period,
    required this.onPeriodChanged,
    this.locked = false,
    super.key,
  });

  final Period? period;
  final ValueChanged<Period?> onPeriodChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: SectionHeader(title: 'Filter by period', locked: locked),
          value: period != null,
          onChanged: locked
              ? null
              : (value) {
                  if (value == true) {
                    onPeriodChanged(Period.now(PeriodType.month));
                  } else {
                    onPeriodChanged(null);
                  }
                },
          contentPadding: EdgeInsets.zero,
        ),
        if (period != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: locked
                ? null
                : () async {
                    final newPeriod = await PeriodPickerDialog.show(
                      context,
                      period!,
                    );
                    if (newPeriod != null) {
                      onPeriodChanged(newPeriod);
                    }
                  },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_month),
              ),
              child: Text(period!.format()),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Status filter with radio group (All/Done/Pending).
class StatusRadioFilterSection extends StatelessWidget {
  const StatusRadioFilterSection({
    required this.isMatched,
    required this.onChanged,
    this.locked = false,
    super.key,
  });

  final bool? isMatched;
  final ValueChanged<bool?> onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Status', locked: locked),
        const SizedBox(height: 8),
        RadioGroup<bool?>(
          groupValue: isMatched,
          onChanged: locked ? (_) {} : onChanged,
          child: Column(
            children: [
              ListTile(
                leading: const Radio<bool?>(value: null),
                title: const Text('All'),
                onTap: locked
                    ? null
                    : () {
                        onChanged(null);
                      },
                enabled: !locked,
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: const Radio<bool?>(value: true),
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 18),
                    SizedBox(width: 8),
                    Text('Done'),
                  ],
                ),
                onTap: locked
                    ? null
                    : () {
                        onChanged(true);
                      },
                enabled: !locked,
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: const Radio<bool?>(value: false),
                title: const Row(
                  children: [
                    Icon(Icons.pending_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Pending'),
                  ],
                ),
                onTap: locked
                    ? null
                    : () {
                        onChanged(false);
                      },
                enabled: !locked,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Generic checkbox filter option.
class CheckboxFilterOption extends StatelessWidget {
  const CheckboxFilterOption({
    required this.label,
    required this.value,
    required this.onChanged,
    this.locked = false,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Row(
        children: [
          Text(label),
          if (locked) ...[
            const SizedBox(width: 8),
            const Icon(Icons.lock, size: 16),
          ],
        ],
      ),
      value: value,
      onChanged: locked ? null : (v) => onChanged(v ?? false),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Tag filter section with chip display and add button.
class TagFilterSection extends StatelessWidget {
  const TagFilterSection({
    required this.selectedTagIds,
    required this.onAddTag,
    required this.onRemoveTag,
    this.lockedTagIds = const {},
    super.key,
  });

  final Set<UuidValue> selectedTagIds;
  final VoidCallback onAddTag;
  final ValueChanged<UuidValue> onRemoveTag;
  final Set<UuidValue> lockedTagIds;

  @override
  Widget build(BuildContext context) {
    final isLocked = lockedTagIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Tags', locked: isLocked),
        const SizedBox(height: 8),
        BlocBuilder<TagCubit, TagState>(
          builder: (context, tagState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedTagIds.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: selectedTagIds.map((id) {
                      final tag = tagState.tagById[id];
                      final isTagLocked = lockedTagIds.contains(id);
                      final tagColor =
                          ColorUtils.parseColor(tag?.color) ?? Colors.grey;

                      return Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(tag?.name ?? 'Unknown')),
                            if (isTagLocked) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.lock, size: 14),
                            ],
                          ],
                        ),
                        backgroundColor: tagColor.withValues(alpha: 0.2),
                        side: BorderSide(color: tagColor, width: 1.5),
                        onDeleted: isTagLocked
                            ? null
                            : () {
                                onRemoveTag(id);
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: isLocked ? null : onAddTag,
                  icon: const Icon(Icons.add),
                  label: const Text('Add tag filter'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Account filter section with chip display and add button.
class AccountFilterSection extends StatelessWidget {
  const AccountFilterSection({
    required this.selectedAccountIds,
    required this.onAddAccount,
    required this.onRemoveAccount,
    this.lockedAccountIds = const {},
    super.key,
  });

  final Set<UuidValue> selectedAccountIds;
  final VoidCallback onAddAccount;
  final ValueChanged<UuidValue> onRemoveAccount;
  final Set<UuidValue> lockedAccountIds;

  @override
  Widget build(BuildContext context) {
    final isLocked = lockedAccountIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Accounts', locked: isLocked),
        const SizedBox(height: 8),
        BlocBuilder<AccountCubit, AccountState>(
          builder: (context, accountState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedAccountIds.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: selectedAccountIds.map((id) {
                      final account = accountState.accountById[id];
                      final isAccountLocked = lockedAccountIds.contains(id);

                      return Chip(
                        avatar: Icon(
                          account?.accountType.icon ?? Icons.account_balance,
                          size: 18,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: Text(account?.name ?? 'Unknown')),
                            if (isAccountLocked) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.lock, size: 14),
                            ],
                          ],
                        ),
                        onDeleted: isAccountLocked
                            ? null
                            : () {
                                onRemoveAccount(id);
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: isLocked ? null : onAddAccount,
                  icon: const Icon(Icons.add),
                  label: const Text('Add account filter'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Helper function to pick a tag.
Future<UuidValue?> pickTag(
  BuildContext context,
  Set<UuidValue> excludeTagIds,
) async {
  final tag = await TagPickerDialog.showWithExclusions(
    context,
    excludeTagIds: excludeTagIds,
    allowCreate: false,
    title: 'Select Tag',
    subtitle: 'Choose a tag to filter by:',
  );
  return tag?.id;
}
