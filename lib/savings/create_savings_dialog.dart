import 'package:decimal/decimal.dart';
import 'package:kashr/core/amount_dialog.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/savings/cubit/savings_cubit.dart';
import 'package:kashr/savings/model/savings.dart';
import 'package:kashr/turnover/dialogs/add_tag_dialog.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class CreateSavingsDialog extends StatefulWidget {
  const CreateSavingsDialog({super.key});

  @override
  State<CreateSavingsDialog> createState() => _CreateSavingsDialogState();
}

class _CreateSavingsDialogState extends State<CreateSavingsDialog> {
  final _formKey = GlobalKey<FormState>();

  Tag? _selectedTag;
  bool _hasGoal = false;
  int? _goalAmountScaled;
  final Currency _goalCurrency = Currency.EUR;
  bool _isLoading = false;
  String? _errorMessage;

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

    if (_selectedTag == null) {
      setState(() {
        _errorMessage = 'Please select a tag';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final savingsCubit = context.read<SavingsCubit>();

      // Create savings
      final savings = Savings(
        id: const Uuid().v4obj(),
        tagId: _selectedTag!.id,
        goalValue: _hasGoal && _goalAmountScaled != null
            ? (Decimal.fromInt(_goalAmountScaled!) / Decimal.fromInt(100))
                .toDecimal(scaleOnInfinitePrecision: 2)
            : null,
        goalUnit: _hasGoal && _goalAmountScaled != null
            ? _goalCurrency.name
            : null,
        createdAt: DateTime.now(),
      );

      await savingsCubit.createSavings(savings);

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
      title: const Text('Create Savings'),
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

                // Tag selection
                InkWell(
                  onTap: () async {
                    final selectedTag = await AddTagDialog.show(context);
                    if (selectedTag != null) {
                      setState(() {
                        _selectedTag = selectedTag;
                        _errorMessage = null;
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
                            'Tap to select or create tag',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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
              : const Text('Create'),
        ),
      ],
    );
  }
}
