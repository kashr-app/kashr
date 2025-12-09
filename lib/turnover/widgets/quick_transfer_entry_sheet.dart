import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/amount_dialog.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/dialogs/add_tag_dialog.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/services/turnover_matching_service.dart';
import 'package:finanalyzer/turnover/widgets/quick_turnover_entry_sheet.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

  int? _amountScaled;

  Tag? _selectedTag;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    _counterpartController.dispose();
    super.dispose();
  }

  Future<void> _selectAmount() async {
    final result = await AmountDialog.show(
      context,
      currencyUnit: widget.fromAccount.currency,
      initialAmountScaled: _amountScaled?.abs() ?? 0,
      showSignSwitch: false,
      initialIsNegative: false,
    );

    if (result != null) {
      setState(() {
        _amountScaled = result;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTag == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a tag')));
      return;
    }
    if (_amountScaled == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

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

      final tagTurnoverRepository = context.read<TagTurnoverRepository>();
      final turnoverRepository = context.read<TurnoverRepository>();
      final matchingService = context.read<TurnoverMatchingService>();

      await createTurnoverAndTagTurnoverOnAccount(
        router,
        widget.fromAccount,
        -amount,
        note,
        counterpart,
        _selectedDate,
        _selectedTag!,
        turnoverRepository,
        tagTurnoverRepository,
        scaffoldMessenger,
        theme,
        matchingService,
      );

      await createTurnoverAndTagTurnoverOnAccount(
        router,
        widget.toAccount,
        amount,
        note,
        counterpart,
        _selectedDate,
        _selectedTag!,
        turnoverRepository,
        tagTurnoverRepository,
        scaffoldMessenger,
        theme,
        matchingService,
      );

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
              InkWell(
                onTap: _selectAmount,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.edit),
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
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final selectedTag = await AddTagDialog.show(context);
                  if (selectedTag != null) {
                    setState(() {
                      _selectedTag = selectedTag;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tag',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
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
              const SizedBox(height: 16),
              if (isManual) ...[
                TextFormField(
                  controller: _counterpartController,
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
    );
  }
}
