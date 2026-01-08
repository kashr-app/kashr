import 'package:decimal/decimal.dart';
import 'package:kashr/core/amount_dialog.dart';
import 'package:kashr/core/constants.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/settings/extensions.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:flutter/material.dart';

class EditTurnoverDialog extends StatefulWidget {
  final Turnover turnover;

  const EditTurnoverDialog({required this.turnover, super.key});

  static Future<Turnover?> show(
    BuildContext context, {
    required Turnover turnover,
  }) {
    return showDialog<Turnover>(
      context: context,
      builder: (context) => EditTurnoverDialog(turnover: turnover),
    );
  }

  @override
  State<EditTurnoverDialog> createState() => _EditTurnoverDialogState();
}

class _EditTurnoverDialogState extends State<EditTurnoverDialog> {
  late TextEditingController _counterPartController;
  late TextEditingController _purposeController;
  late DateTime? _bookingDate;
  late Decimal _amountValue;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amountValue = widget.turnover.amountValue;
    _counterPartController = TextEditingController(
      text: widget.turnover.counterPart ?? '',
    );
    _purposeController = TextEditingController(text: widget.turnover.purpose);
    _bookingDate = widget.turnover.bookingDate;
  }

  @override
  void dispose() {
    _counterPartController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _bookingDate ?? DateTime.now(),
      firstDate: minDate,
      lastDate: maxDate,
    );

    if (pickedDate != null) {
      setState(() {
        _bookingDate = pickedDate;
      });
    }
  }

  Future<void> _editAmount() async {
    final initialAmountScaled = decimalScale(_amountValue) ?? 0;

    final result = await AmountDialog.show(
      context,
      currencyUnit: widget.turnover.amountUnit,
      initialAmountScaled: initialAmountScaled,
      showSignSwitch: true,
      preferredSign: TurnoverSign.expense,
    );

    if (result != null) {
      setState(() {
        _amountValue = decimalUnscale(result) ?? Decimal.zero;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updatedTurnover = widget.turnover.copyWith(
      amountValue: _amountValue,
      counterPart: _counterPartController.text.isEmpty
          ? null
          : _counterPartController.text,
      purpose: _purposeController.text,
      bookingDate: _bookingDate,
    );

    Navigator.of(context).pop(updatedTurnover);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Turnover'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _editAmount,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.edit),
                  ),
                  child: Text(
                    Currency.currencyFrom(
                      widget.turnover.amountUnit,
                    ).format(_amountValue),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
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
                  child: Text(
                    _bookingDate != null
                        ? context.dateFormat.format(_bookingDate!)
                        : 'No date',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _counterPartController,
                decoration: const InputDecoration(
                  labelText: 'Counter Part (Optional)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a purpose';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Continue')),
      ],
    );
  }
}
