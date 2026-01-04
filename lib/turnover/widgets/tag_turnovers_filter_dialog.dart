import 'package:kashr/account/account_selector_dialog.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/core/widgets/period_selector.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/dialogs/tag_picker_dialog.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Dialog for editing tag turnover filters.
class TagTurnoversFilterDialog extends StatefulWidget {
  const TagTurnoversFilterDialog({
    required this.initialFilter,
    this.lockedFilters = TagTurnoversFilter.empty,
    super.key,
  });

  final TagTurnoversFilter initialFilter;

  /// Filters that cannot be edited by the user.
  /// These filters are displayed but their controls are disabled.
  final TagTurnoversFilter lockedFilters;

  @override
  State<TagTurnoversFilterDialog> createState() =>
      _TagTurnoversFilterDialogState();
}

class _TagTurnoversFilterDialogState extends State<TagTurnoversFilterDialog> {
  late bool _transferTagOnly;
  late bool _unfinishedTransfersOnly;
  late Period? _period;
  late Set<UuidValue> _selectedTagIds;
  late Set<UuidValue> _selectedAccountIds;
  late TurnoverSign? _sign;
  late bool? _isMatched;

  bool get _isTransferTagOnlyLocked =>
      widget.lockedFilters.transferTagOnly != null;
  bool get _isUnfinishedTransfersOnlyLocked =>
      widget.lockedFilters.unfinishedTransfersOnly != null;
  bool get _isPeriodLocked => widget.lockedFilters.period != null;
  bool get _isSignLocked => widget.lockedFilters.sign != null;
  bool get _isMatchedLocked => widget.lockedFilters.isMatched != null;
  bool get _areTagsLocked =>
      widget.lockedFilters.tagIds != null &&
      widget.lockedFilters.tagIds!.isNotEmpty;
  bool get _areAccountsLocked =>
      widget.lockedFilters.accountIds != null &&
      widget.lockedFilters.accountIds!.isNotEmpty;

  @override
  void initState() {
    super.initState();

    // Initialize from widget parameters
    _transferTagOnly = widget.initialFilter.transferTagOnly ?? false;
    _unfinishedTransfersOnly =
        widget.initialFilter.unfinishedTransfersOnly ?? false;
    _period = widget.initialFilter.period;
    _selectedTagIds = widget.initialFilter.tagIds?.toSet() ?? {};
    _selectedAccountIds = widget.initialFilter.accountIds?.toSet() ?? {};
    _sign = widget.initialFilter.sign;
    _isMatched = widget.initialFilter.isMatched;
  }

  Future<void> _pickTag() async {
    final tag = await TagPickerDialog.showWithExclusions(
      context,
      excludeTagIds: _selectedTagIds,
      allowCreate: false,
      title: 'Select Tag',
      subtitle: 'Choose a tag to filter by:',
    );

    if (tag != null) {
      setState(() {
        _selectedTagIds.add(tag.id);
      });
    }
  }

  Future<void> _pickAccount() async {
    final account = await AccountSelectorDialog.show(context);

    if (account != null && !_selectedAccountIds.contains(account.id)) {
      setState(() {
        _selectedAccountIds.add(account.id);
      });
    }
  }

  void _applyFilters() {
    final filter = TagTurnoversFilter(
      transferTagOnly: _transferTagOnly ? true : null,
      unfinishedTransfersOnly: _unfinishedTransfersOnly ? true : null,
      period: _period,
      tagIds: _selectedTagIds.isEmpty ? null : _selectedTagIds.toList(),
      accountIds: _selectedAccountIds.isEmpty
          ? null
          : _selectedAccountIds.toList(),
      sign: _sign,
      isMatched: _isMatched,
    );

    Navigator.of(context).pop(filter);
  }

  void _clearFilters() {
    setState(() {
      // Only clear filters that are not locked
      if (!_isTransferTagOnlyLocked) _transferTagOnly = false;
      if (!_unfinishedTransfersOnly) _unfinishedTransfersOnly = false;
      if (!_isPeriodLocked) _period = null;
      if (!_isSignLocked) _sign = null;
      if (!_isMatchedLocked) _isMatched = null;

      // For tags and accounts, only remove non-locked ones
      final lockedTagIds = widget.lockedFilters.tagIds?.toSet() ?? {};
      final lockedAccountIds = widget.lockedFilters.accountIds?.toSet() ?? {};

      _selectedTagIds.removeWhere((id) => !lockedTagIds.contains(id));
      _selectedAccountIds.removeWhere((id) => !lockedAccountIds.contains(id));
    });
  }

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
                  Text('Filter', style: theme.textTheme.titleLarge),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sign filter
                    Row(
                      children: [
                        Text('Type', style: theme.textTheme.titleMedium),
                        if (_isSignLocked) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock, size: 16),
                        ],
                        const Spacer(),
                        DropdownButton<TurnoverSign?>(
                          value: _sign,
                          items: const [
                            DropdownMenuItem(value: null, child: Text("All")),
                            DropdownMenuItem(
                              value: TurnoverSign.expense,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_downward,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Expense'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: TurnoverSign.income,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_upward,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Income'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: _isSignLocked
                              ? null
                              : (value) {
                                  setState(() {
                                    _sign = value;
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Period filter
                    CheckboxListTile(
                      title: Row(
                        children: [
                          Text(
                            'Filter by period',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (_isPeriodLocked) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.lock, size: 16),
                          ],
                        ],
                      ),
                      value: _period != null,
                      onChanged: _isPeriodLocked
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _period = Period.now(PeriodType.month);
                                } else {
                                  _period = null;
                                }
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_period != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => PeriodPickerDialog.show(context, _period!)
                            .then((v) {
                              if (v != null) {
                                setState(() {
                                  _period = v;
                                });
                              }
                            }),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Period',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(_period!.format()),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Status filter
                    Row(
                      children: [
                        Text('Status', style: theme.textTheme.titleMedium),
                        if (_isMatchedLocked) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<bool?>(
                      groupValue: _isMatched,
                      onChanged: (value) {
                        if (!_isMatchedLocked) {
                          setState(() {
                            _isMatched = value;
                          });
                        }
                      },
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Radio<bool?>(value: null),
                            title: const Text('All'),
                            onTap: _isMatchedLocked
                                ? null
                                : () {
                                    setState(() {
                                      _isMatched = null;
                                    });
                                  },
                            enabled: !_isMatchedLocked,
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
                            onTap: _isMatchedLocked
                                ? null
                                : () {
                                    setState(() {
                                      _isMatched = true;
                                    });
                                  },
                            enabled: !_isMatchedLocked,
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
                            onTap: _isMatchedLocked
                                ? null
                                : () {
                                    setState(() {
                                      _isMatched = false;
                                    });
                                  },
                            enabled: !_isMatchedLocked,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text('Transfers', style: theme.textTheme.titleMedium),
                    // Transfer tags filter
                    CheckboxListTile(
                      title: Row(
                        children: [
                          const Text('Has transfer tag'),
                          if (_isTransferTagOnlyLocked) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.lock, size: 16),
                          ],
                        ],
                      ),
                      value: _transferTagOnly,
                      onChanged: _isTransferTagOnlyLocked
                          ? null
                          : (value) {
                              setState(() {
                                if (value != true) {
                                  _unfinishedTransfersOnly = false;
                                }
                                _transferTagOnly = value ?? false;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                    ),
                    // Non-complete Transfer filter
                    CheckboxListTile(
                      title: Row(
                        children: [
                          const Text('Unfinished only'),
                          if (_isUnfinishedTransfersOnlyLocked) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.lock, size: 16),
                          ],
                        ],
                      ),
                      value: _unfinishedTransfersOnly,
                      onChanged: _isUnfinishedTransfersOnlyLocked
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _transferTagOnly = true;
                                }
                                _unfinishedTransfersOnly = value ?? false;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),

                    // Tag filters
                    Row(
                      children: [
                        Text('Tags', style: theme.textTheme.titleMedium),
                        if (_areTagsLocked) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    BlocBuilder<TagCubit, TagState>(
                      builder: (context, tagState) {
                        final lockedTagIds =
                            widget.lockedFilters.tagIds?.toSet() ?? {};
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedTagIds.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _selectedTagIds.map((id) {
                                  final tag = tagState.tagById[id]!;
                                  final isLocked = lockedTagIds.contains(id);
                                  final tagColor = tag.color != null
                                      ? Color(
                                          int.parse(
                                            tag.color!.replaceFirst(
                                              '#',
                                              '0xff',
                                            ),
                                          ),
                                        )
                                      : null;

                                  return Chip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(child: Text(tag.name)),
                                        if (isLocked) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.lock, size: 14),
                                        ],
                                      ],
                                    ),
                                    backgroundColor: tagColor?.withValues(
                                      alpha: 0.2,
                                    ),
                                    side: tagColor != null
                                        ? BorderSide(
                                            color: tagColor,
                                            width: 1.5,
                                          )
                                        : null,
                                    onDeleted: isLocked
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedTagIds.remove(tag.id);
                                            });
                                          },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: _areTagsLocked ? null : _pickTag,
                              icon: const Icon(Icons.add),
                              label: const Text('Add tag filter'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Account filters
                    Row(
                      children: [
                        Text('Accounts', style: theme.textTheme.titleMedium),
                        if (_areAccountsLocked) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    BlocBuilder<AccountCubit, AccountState>(
                      builder: (context, accountState) {
                        final lockedAccountIds =
                            widget.lockedFilters.accountIds?.toSet() ?? {};
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedAccountIds.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _selectedAccountIds.map((id) {
                                  final account = accountState.accountById[id]!;
                                  final isLocked = lockedAccountIds.contains(
                                    id,
                                  );
                                  return Chip(
                                    avatar: Icon(
                                      account.accountType.icon,
                                      size: 18,
                                    ),
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(child: Text(account.name)),
                                        if (isLocked) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.lock, size: 14),
                                        ],
                                      ],
                                    ),
                                    onDeleted: isLocked
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedAccountIds.remove(
                                                account.id,
                                              );
                                            });
                                          },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: _areAccountsLocked
                                  ? null
                                  : _pickAccount,
                              icon: const Icon(Icons.add),
                              label: const Text('Add account filter'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _applyFilters,
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
