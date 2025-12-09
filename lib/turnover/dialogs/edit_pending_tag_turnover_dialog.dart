import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/account_selector_dialog.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/amount_dialog.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/turnover/dialogs/add_tag_dialog.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Result of editing a pending tag turnover
sealed class EditPendingTagTurnoverResult {}

class EditPendingTagTurnoverUpdated extends EditPendingTagTurnoverResult {
  final TagTurnover tagTurnover;
  EditPendingTagTurnoverUpdated(this.tagTurnover);
}

class EditPendingTagTurnoverDeleted extends EditPendingTagTurnoverResult {}

/// Dialog for editing pending tag turnovers
class EditPendingTagTurnoverDialog extends StatefulWidget {
  final TagTurnover tagTurnover;
  final Account account;
  final Tag tag;

  const EditPendingTagTurnoverDialog({
    required this.tagTurnover,
    required this.account,
    required this.tag,
    super.key,
  });

  static Future<EditPendingTagTurnoverResult?> show(
    BuildContext context, {
    required TagTurnover tagTurnover,
    required Account account,
    required Tag tag,
  }) {
    return showDialog<EditPendingTagTurnoverResult>(
      context: context,
      builder: (context) => EditPendingTagTurnoverDialog(
        tagTurnover: tagTurnover,
        account: account,
        tag: tag,
      ),
    );
  }

  @override
  State<EditPendingTagTurnoverDialog> createState() =>
      _EditPendingTagTurnoverDialogState();
}

class _EditPendingTagTurnoverDialogState
    extends State<EditPendingTagTurnoverDialog> {
  late TextEditingController _noteController;
  late Decimal _amountValue;
  late Tag _selectedTag;
  late Account _selectedAccount;
  late DateTime _bookingDate;
  final _formKey = GlobalKey<FormState>();
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _amountValue = widget.tagTurnover.amountValue;
    _selectedTag = widget.tag;
    _selectedAccount = widget.account;
    _bookingDate = widget.tagTurnover.bookingDate;
    _noteController = TextEditingController(
      text: widget.tagTurnover.note ?? '',
    );
    _noteController.addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    setState(() {
      // Trigger rebuild to update _isDirty
    });
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    if (_amountValue != widget.tagTurnover.amountValue) return true;
    if (_selectedTag.id != widget.tagTurnover.tagId) return true;
    if (_selectedAccount.id != widget.tagTurnover.accountId) return true;
    if (_bookingDate != widget.tagTurnover.bookingDate) return true;
    final currentNote = _noteController.text.isEmpty
        ? null
        : _noteController.text;
    if (currentNote != widget.tagTurnover.note) return true;
    return false;
  }

  Future<void> _selectAmount() async {
    final initialAmountScaled = decimalScale(_amountValue.abs()) ?? 0;
    final initialIsNegative = _amountValue < Decimal.zero;

    final result = await AmountDialog.show(
      context,
      currencyUnit: _selectedAccount.currency,
      initialAmountScaled: initialAmountScaled,
      showSignSwitch: true,
      initialIsNegative: initialIsNegative,
    );

    if (result != null) {
      setState(() {
        _amountValue = decimalUnscale(result) ?? Decimal.zero;
      });
    }
  }

  Future<void> _selectTag() async {
    final selectedTag = await AddTagDialog.show(context);
    if (selectedTag != null) {
      setState(() {
        _selectedTag = selectedTag;
      });
    }
  }

  Future<void> _selectAccount() async {
    final selectedAccount = await showDialog<Account>(
      context: context,
      builder: (context) =>
          AccountSelectorDialog(selectedId: _selectedAccount.id),
    );
    if (selectedAccount != null) {
      setState(() {
        _selectedAccount = selectedAccount;
      });
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _bookingDate = pickedDate;
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Turnover'),
        content: const Text(
          'Are you sure you want to delete this pending turnover?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isDeleting = true;
      });

      Navigator.of(context).pop(EditPendingTagTurnoverDeleted());
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updatedTagTurnover = widget.tagTurnover.copyWith(
      amountValue: _amountValue,
      amountUnit: _selectedAccount.currency,
      tagId: _selectedTag.id,
      accountId: _selectedAccount.id,
      bookingDate: _bookingDate,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    Navigator.of(
      context,
    ).pop(EditPendingTagTurnoverUpdated(updatedTagTurnover));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _isDirty) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Edit Pending Turnover')),
            if (_isDirty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Edited',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _selectAmount,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.edit),
                    ),
                    child: Text(
                      Currency.currencyFrom(
                        _selectedAccount.currency,
                      ).format(_amountValue),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectTag,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tag',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Row(
                      children: [
                        TagAvatar(tag: _selectedTag, radius: 12),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_selectedTag.name)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<AccountCubit, AccountState>(
                  builder: (context, state) {
                    return InkWell(
                      onTap: _selectAccount,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Account',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Row(
                          children: [
                            Icon(_selectedAccount.accountType.icon, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_selectedAccount.name)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Booking Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(dateFormat.format(_bookingDate)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _isDeleting ? null : _delete,
            color: theme.colorScheme.error,
            tooltip: 'Delete',
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isDirty ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
