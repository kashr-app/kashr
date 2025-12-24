import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/amount_dialog.dart';
import 'package:kashr/core/constants.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:kashr/turnover/dialogs/add_tag_dialog.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/transfer.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/services/turnover_matching_service.dart';
import 'package:kashr/turnover/widgets/quick_turnover_entry_sheet.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class QuickTransferEntrySheet extends StatefulWidget {
  final Account fromAccount;
  final Account toAccount;

  const QuickTransferEntrySheet({
    required this.fromAccount,
    required this.toAccount,
    super.key,
  });

  @override
  State<QuickTransferEntrySheet> createState() =>
      _QuickTransferEntrySheetState();
}

class _QuickTransferEntrySheetState extends State<QuickTransferEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _counterpartController = TextEditingController();
  final _counterpartFocusNode = FocusNode();
  final _noteFocusNode = FocusNode();

  int? _amountScaled;
  String? _amountError;

  Tag? _selectedTag;
  String? _tagError;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  late final Logger log;

  @override
  void initState() {
    super.initState();
    log = context.read<LogService>().log;

    // Trigger auto-flow after first frame if setting is enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final autoFlowEnabled = context.read<SettingsCubit>().state.fastFormMode;
      if (autoFlowEnabled) {
        _runAutoFlow();
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _counterpartController.dispose();
    _counterpartFocusNode.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  /// Returns if updated (true) or canceled (false)
  Future<bool> _selectAmount() async {
    final result = await AmountDialog.show(
      context,
      currencyUnit: widget.fromAccount.currency,
      initialAmountScaled: _amountScaled?.abs() ?? 0,
      showSignSwitch: false,
      initialIsNegative: false,
    );

    if (result != null && mounted) {
      setState(() {
        _amountScaled = result;
        _amountError = null;
      });
      return true;
    }
    return false;
  }

  /// Returns if updated (true) or canceled (false)
  Future<bool> _selectTag() async {
    final selectedTag = await AddTagDialog.show(
      context,
      filter: (tag) => tag.isTransfer,
      defaultSemantic: TagSemantic.transfer,
    );
    if (selectedTag != null && mounted) {
      setState(() {
        _selectedTag = selectedTag;
        _tagError = null;
      });
      return true;
    }
    return false;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: minDate,
      lastDate: maxDate,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    bool hasError = false;
    if (_selectedTag == null) {
      setState(() {
        _tagError = 'Please select a tag';
      });
      hasError = true;
    }
    if (_amountScaled == null) {
      setState(() {
        _amountError = 'Please enter an amount';
      });
      hasError = true;
    }
    if (hasError) return;

    setState(() {
      _isSubmitting = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final theme = Theme.of(context);
    try {
      final Decimal amount = decimalUnscale(_amountScaled)!;
      final note = _noteController.text.trim();
      final counterpart = _counterpartController.text.trim();
      final tag = _selectedTag!;

      final tagTurnoverRepository = context.read<TagTurnoverRepository>();
      final turnoverRepository = context.read<TurnoverRepository>();
      final matchingService = context.read<TurnoverMatchingService>();
      final transferRepository = context.read<TransferRepository>();

      // Create both tag turnovers and link them via Transfer entity
      final (
        fromTurnover,
        fromTagTurnover,
      ) = await createTurnoverAndTagTurnoverOnAccount(
        log,
        router,
        widget.fromAccount,
        -amount,
        note,
        counterpart,
        _selectedDate,
        tag,
        turnoverRepository,
        tagTurnoverRepository,
        scaffoldMessenger,
        theme,
        matchingService,
      );

      final (
        toTurnover,
        toTagTurnover,
      ) = await createTurnoverAndTagTurnoverOnAccount(
        log,
        router,
        widget.toAccount,
        amount,
        note,
        counterpart,
        _selectedDate,
        tag,
        turnoverRepository,
        tagTurnoverRepository,
        scaffoldMessenger,
        theme,
        matchingService,
      );

      // Create Transfer entity linking the two tagTurnovers
      final transfer = Transfer(
        id: const Uuid().v4obj(),
        fromTagTurnoverId: fromTagTurnover.id,
        toTagTurnoverId: toTagTurnover.id,
        createdAt: DateTime.now(),
      );

      final transferWithDetails = TransferWithDetails(
        transfer: transfer,
        fromTagTurnover: fromTagTurnover,
        toTagTurnover: toTagTurnover,
        fromTag: tag,
        toTag: tag,
      );

      await transferRepository.createTransfer(transferWithDetails);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Status.error.snack2(scaffoldMessenger, theme, 'Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatAmount(int scaledAmount) {
    final decimal = (Decimal.fromInt(scaledAmount) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 2);
    final currency = Currency.currencyFrom(widget.fromAccount.currency);
    return currency.format(decimal);
  }

  Future<void> _runAutoFlow() async {
    final steps = [
      //
      _selectAmount,
      _selectTag,
      _focusFirstTextField,
    ];
    for (final step in steps) {
      final continueAutoFlow = await step();
      if (!continueAutoFlow || !mounted) {
        // stop auto-flow
        return;
      }
    }
  }

  Future<bool> _focusFirstTextField() async {
    final c = Completer<bool>();
    // Use addPostFrameCallback to ensure the form is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final isManual = widget.fromAccount.syncSource == SyncSource.manual;
      if (isManual) {
        // Focus counterpart field for manual accounts
        FocusScope.of(context).requestFocus(_counterpartFocusNode);
      } else {
        // Focus note field for linked accounts
        FocusScope.of(context).requestFocus(_noteFocusNode);
      }
      c.complete(true);
    });
    return c.future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isManual = widget.fromAccount.syncSource == SyncSource.manual;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Log Transfer', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'From ${widget.fromAccount.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'To ${widget.toAccount.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _selectAmount,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _amountError != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _amountError != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          suffixIcon: const Icon(Icons.edit),
                        ),
                        child: Text(
                          _amountScaled != null
                              ? _formatAmount(_amountScaled!)
                              : 'Tap to enter amount',
                          style: _amountScaled == null
                              ? theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (_amountError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text(
                          _amountError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _selectTag,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tag',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _tagError != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _tagError != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                        ),
                        child: _selectedTag != null
                            ? Row(
                                children: [
                                  TagAvatar(tag: _selectedTag!, radius: 12),
                                  const SizedBox(width: 8),
                                  Text(_selectedTag!.name),
                                ],
                              )
                            : Text(
                                'Tap to select tag',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                    ),
                    if (_tagError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text(
                          _tagError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isManual) ...[
                  TextFormField(
                    controller: _counterpartController,
                    focusNode: _counterpartFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Counterpart (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Store name, Person',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _noteController,
                  focusNode: _noteFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
