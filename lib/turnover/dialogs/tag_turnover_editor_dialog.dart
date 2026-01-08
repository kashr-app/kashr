import 'package:decimal/decimal.dart';
import 'package:kashr/account/account_selector_dialog.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/amount_dialog.dart';
import 'package:kashr/core/constants.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/settings/extensions.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/dialogs/tag_picker_dialog.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Result of editing a tag turnover
sealed class EditTagTurnoverResult {}

class EditTagTurnoverUpdated extends EditTagTurnoverResult {
  final TagTurnover tagTurnover;
  EditTagTurnoverUpdated(this.tagTurnover);
}

class EditTagTurnoverDeleted extends EditTagTurnoverResult {}

/// Dialog for editing tag turnovers
class TagTurnoverEditorDialog extends StatefulWidget {
  final TagTurnover tagTurnover;

  const TagTurnoverEditorDialog({required this.tagTurnover, super.key});

  static Future<EditTagTurnoverResult?> show(
    BuildContext context, {
    required TagTurnover tagTurnover,
  }) {
    return showDialog<EditTagTurnoverResult>(
      context: context,
      builder: (context) => TagTurnoverEditorDialog(tagTurnover: tagTurnover),
    );
  }

  @override
  State<TagTurnoverEditorDialog> createState() =>
      _TagTurnoverEditorDialogState();
}

class _TagTurnoverEditorDialogState extends State<TagTurnoverEditorDialog> {
  late TextEditingController _noteController;
  late TextEditingController _counterPartController;
  late Decimal _amountValue;
  late UuidValue _selectedTagId;
  late UuidValue _selectedAccountId;
  late DateTime _bookingDate;
  final _formKey = GlobalKey<FormState>();
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _amountValue = widget.tagTurnover.amountValue;
    _selectedTagId = widget.tagTurnover.tagId;
    _selectedAccountId = widget.tagTurnover.accountId;
    _bookingDate = widget.tagTurnover.bookingDate;
    _noteController = TextEditingController(
      text: widget.tagTurnover.note ?? '',
    );
    _noteController.addListener(_triggerRebuild);
    _counterPartController = TextEditingController(
      text: widget.tagTurnover.counterPart ?? '',
    );
    _counterPartController.addListener(_triggerRebuild);
  }

  void _triggerRebuild() {
    setState(() {
      // Trigger rebuild to update _isDirty
    });
  }

  @override
  void dispose() {
    _noteController.removeListener(_triggerRebuild);
    _noteController.dispose();
    _counterPartController.removeListener(_triggerRebuild);
    _counterPartController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    if (_amountValue != widget.tagTurnover.amountValue) return true;
    if (_selectedTagId != widget.tagTurnover.tagId) return true;
    if (_selectedAccountId != widget.tagTurnover.accountId) return true;
    if (_bookingDate != widget.tagTurnover.bookingDate) return true;
    final currentNote = _noteController.text.isEmpty
        ? null
        : _noteController.text;
    if (currentNote != widget.tagTurnover.note) return true;
    final currentCounterPart = _counterPartController.text.isEmpty
        ? null
        : _counterPartController.text;
    if (currentCounterPart != widget.tagTurnover.counterPart) return true;
    return false;
  }

  Future<void> _selectAmount(Account account) async {
    final initialAmountScaled = decimalScale(_amountValue) ?? 0;

    final result = await AmountDialog.show(
      context,
      currencyUnit: account.currency,
      initialAmountScaled: initialAmountScaled,
      showSignSwitch: true,
    );

    if (result != null) {
      setState(() {
        _amountValue = decimalUnscale(result) ?? Decimal.zero;
      });
    }
  }

  Future<void> _selectTag() async {
    final selectedTag = await TagPickerDialog.show(context);
    if (selectedTag != null) {
      setState(() {
        _selectedTagId = selectedTag.id;
      });
    }
  }

  Future<void> _selectAccount() async {
    final selectedAccount = await AccountSelectorDialog.show(
      context,
      selectedId: _selectedAccountId,
    );
    if (selectedAccount != null) {
      setState(() {
        _selectedAccountId = selectedAccount.id;
      });
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: minDate,
      lastDate: maxDate,
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
          'Are you sure you want to delete this tag turnover?',
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

      Navigator.of(context).pop(EditTagTurnoverDeleted());
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

  void _save(Account account) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updatedTagTurnover = widget.tagTurnover.copyWith(
      amountValue: _amountValue,
      amountUnit: account.currency,
      tagId: _selectedTagId,
      accountId: _selectedAccountId,
      bookingDate: _bookingDate,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      counterPart: _counterPartController.text.isEmpty
          ? null
          : _counterPartController.text,
    );

    Navigator.of(context).pop(EditTagTurnoverUpdated(updatedTagTurnover));
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
            const Expanded(child: Text('Edit Tag Turnover')),
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
          child: BlocBuilder<AccountCubit, AccountState>(
            builder: (context, accountState) {
              return BlocBuilder<TagCubit, TagState>(
                builder: (context, tagState) {
                  final account = accountState.accountById[_selectedAccountId];
                  if (account == null) {
                    return Center(child: Text('Account not found'));
                  }
                  final tag = tagState.tagById[_selectedTagId];
                  if (tag == null) {
                    return Center(child: Text('Tag not found'));
                  }
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _selectAmount(account),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.edit),
                            ),
                            child: Text(
                              Currency.currencyFrom(
                                account.currency,
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
                                TagAvatar(tag: tag, radius: 12),
                                const SizedBox(width: 8),
                                Expanded(child: Text(tag.name, overflow: TextOverflow.ellipsis,)),
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
                                    Icon(account.accountType.icon, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(account.name, overflow: TextOverflow.ellipsis,)),
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
                            child: Text(context.dateFormat.format(_bookingDate)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _counterPartController,
                          decoration: const InputDecoration(
                            labelText: 'Counter Part (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.sentences,
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
                  );
                },
              );
            },
          ),
        ),
        actions: [
          Row(
            children: [
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
              SizedBox(width: 8),
              BlocBuilder<AccountCubit, AccountState>(
                builder: (context, accountState) {
                  final account = accountState.accountById[_selectedAccountId];
                  return FilledButton(
                    onPressed: account != null && _isDirty
                        ? () => _save(account)
                        : null,
                    child: const Text('Save'),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
