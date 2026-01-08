import 'package:kashr/account/account_selector_dialog.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/widgets/filter_dialog_sections.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Dialog for editing turnover filters.
class TurnoverFilterDialog extends StatefulWidget {
  const TurnoverFilterDialog({required this.initialFilter, super.key});

  final TurnoverFilter initialFilter;

  @override
  State<TurnoverFilterDialog> createState() => _TurnoverFilterDialogState();
}

class _TurnoverFilterDialogState extends State<TurnoverFilterDialog> {
  late bool _unallocatedOnly;
  late Period? _period;
  late Set<UuidValue> _selectedTagIds;
  late Set<UuidValue> _selectedAccountIds;
  late TurnoverSign? _sign;

  @override
  void initState() {
    super.initState();
    _unallocatedOnly = widget.initialFilter.unallocatedOnly ?? false;
    _period = widget.initialFilter.period;
    _selectedTagIds = widget.initialFilter.tagIds?.toSet() ?? {};
    _selectedAccountIds = widget.initialFilter.accountIds?.toSet() ?? {};
    _sign = widget.initialFilter.sign;
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
    final filter = widget.initialFilter.copyWith(
      unallocatedOnly: _unallocatedOnly ? true : null,
      period: _period,
      tagIds: _selectedTagIds.isEmpty ? null : _selectedTagIds.toList(),
      accountIds: _selectedAccountIds.isEmpty
          ? null
          : _selectedAccountIds.toList(),
      sign: _sign,
    );

    Navigator.of(context).pop(filter);
  }

  void _clearFilters() {
    setState(() {
      _unallocatedOnly = false;
      _period = null;
      _selectedTagIds = {};
      _selectedAccountIds = {};
      _sign = null;
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
            onChanged: (value) {
              setState(() {
                _sign = value;
              });
            },
          ),
          PeriodFilterSection(
            period: _period,
            onPeriodChanged: (value) {
              setState(() {
                _period = value;
              });
            },
          ),
          SectionHeader(title: 'Tags'),
          const SizedBox(height: 8),
          CheckboxFilterOption(
            label: 'Show unallocated only',
            value: _unallocatedOnly,
            onChanged: (value) {
              setState(() {
                _unallocatedOnly = value;
              });
            },
          ),
          const SizedBox(height: 16),
          TagFilterSection(
            selectedTagIds: _selectedTagIds,
            onAddTag: _pickTag,
            onRemoveTag: (tagId) {
              setState(() {
                _selectedTagIds.remove(tagId);
              });
            },
          ),
          AccountFilterSection(
            selectedAccountIds: _selectedAccountIds,
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
