import 'package:kashr/account/account_selector_dialog.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/widgets/filter_dialog_sections.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
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
    final tagId = await pickTag(context, _selectedTagIds);
    if (tagId != null) {
      setState(() {
        _selectedTagIds.add(tagId);
      });
    }
  }

  Future<void> _pickAccount() async {
    final account = await AccountSelectorDialog.show(context);
    final accountId = account?.id;
    if (accountId != null && !_selectedAccountIds.contains(accountId)) {
      setState(() {
        _selectedAccountIds.add(accountId);
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
      if (!_isUnfinishedTransfersOnlyLocked) _unfinishedTransfersOnly = false;
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
    return FilterDialogShell(
      title: 'Filter',
      onClear: _clearFilters,
      onApply: _applyFilters,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SignFilterSection(
            value: _sign,
            locked: _isSignLocked,
            onChanged: (value) {
              setState(() {
                _sign = value;
              });
            },
          ),
          PeriodFilterSection(
            period: _period,
            locked: _isPeriodLocked,
            onPeriodChanged: (value) {
              setState(() {
                _period = value;
              });
            },
          ),
          StatusRadioFilterSection(
            isMatched: _isMatched,
            locked: _isMatchedLocked,
            onChanged: (value) {
              setState(() {
                _isMatched = value;
              });
            },
          ),
          SectionHeader(title: 'Transfers'),
          const SizedBox(height: 8),
          CheckboxFilterOption(
            label: 'Has transfer tag',
            value: _transferTagOnly,
            locked: _isTransferTagOnlyLocked,
            onChanged: (value) {
              setState(() {
                if (!value) {
                  _unfinishedTransfersOnly = false;
                }
                _transferTagOnly = value;
              });
            },
          ),
          CheckboxFilterOption(
            label: 'Unfinished only',
            value: _unfinishedTransfersOnly,
            locked: _isUnfinishedTransfersOnlyLocked,
            onChanged: (value) {
              setState(() {
                if (value) {
                  _transferTagOnly = true;
                }
                _unfinishedTransfersOnly = value;
              });
            },
          ),
          const SizedBox(height: 24),
          TagFilterSection(
            selectedTagIds: _selectedTagIds,
            lockedTagIds: widget.lockedFilters.tagIds?.toSet() ?? {},
            onAddTag: _pickTag,
            onRemoveTag: (tagId) {
              setState(() {
                _selectedTagIds.remove(tagId);
              });
            },
          ),
          AccountFilterSection(
            selectedAccountIds: _selectedAccountIds,
            lockedAccountIds: widget.lockedFilters.accountIds?.toSet() ?? {},
            onAddAccount: _pickAccount,
            onRemoveAccount: (accountId) {
              setState(() {
                _selectedAccountIds.remove(accountId);
              });
            },
          ),
        ],
      ),
    );
  }
}
