import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/amount_dialog.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/savings/cubit/savings_cubit.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dialog for editing the savings goal.
class EditSavingsGoalDialog extends StatefulWidget {
  final Savings savings;

  const EditSavingsGoalDialog({required this.savings, super.key});

  /// Shows the dialog and returns true if the goal was updated.
  static Future<bool?> show(BuildContext context, Savings savings) {
    return showDialog<bool>(
      context: context,
      builder: (context) => EditSavingsGoalDialog(savings: savings),
    );
  }

  @override
  State<EditSavingsGoalDialog> createState() => _EditSavingsGoalDialogState();
}

class _EditSavingsGoalDialogState extends State<EditSavingsGoalDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _hasGoal = false;
  int? _goalAmountScaled;
  final Currency _goalCurrency = Currency.EUR;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hasGoal = widget.savings.goalValue != null;
    if (_hasGoal && widget.savings.goalValue != null) {
      _goalAmountScaled = (widget.savings.goalValue! * Decimal.fromInt(100))
          .toBigInt()
          .toInt();
    }
  }

  Future<void> _selectGoalAmount() async {
    final result = await AmountDialog.show(
      context,
      currencyUnit: _goalCurrency.name,
      initialAmountScaled: _goalAmountScaled?.abs() ?? 0,
      showSignSwitch: false,
      initialIsNegative: false,
    );

    if (result != null) {
      setState(() {
        _goalAmountScaled = result.abs();
      });
    }
  }

  String _formatAmount(int scaledAmount) {
    final decimal = (Decimal.fromInt(scaledAmount) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 2);
    return _goalCurrency.format(decimal);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final savingsCubit = context.read<SavingsCubit>();

      final goalValue = _hasGoal && _goalAmountScaled != null
          ? decimalUnscale(_goalAmountScaled)
          : null;
      final goalUnit = _hasGoal && _goalAmountScaled != null
          ? _goalCurrency.name
          : null;

      await savingsCubit.updateGoal(
        widget.savings.id!,
        goalValue,
        goalUnit,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Savings Goal'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Goal toggle
                SwitchListTile(
                  value: _hasGoal,
                  onChanged: (value) {
                    setState(() {
                      _hasGoal = value;
                    });
                  },
                  title: const Text('Set a goal'),
                  contentPadding: EdgeInsets.zero,
                ),

                // Goal amount
                if (_hasGoal) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectGoalAmount,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Goal Amount',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.edit),
                      ),
                      child: Text(
                        _goalAmountScaled != null
                            ? _formatAmount(_goalAmountScaled!)
                            : 'Tap to enter amount',
                        style: _goalAmountScaled == null
                            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
