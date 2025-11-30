import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/amount_dialog.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class VirtualBookingDialog extends StatefulWidget {
  final Savings savings;

  const VirtualBookingDialog({
    required this.savings,
    super.key,
  });

  @override
  State<VirtualBookingDialog> createState() => _VirtualBookingDialogState();
}

class _VirtualBookingDialogState extends State<VirtualBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  Account? _selectedAccount;
  int? _amountScaled;
  bool _isAllocating = true; // true = add to savings, false = remove from savings
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectAmount() async {
    if (_selectedAccount == null) {
      setState(() {
        _errorMessage = 'Please select an account first';
      });
      return;
    }

    final result = await AmountDialog.show(
      context,
      currencyUnit: _selectedAccount!.currency,
      initialAmountScaled: _amountScaled?.abs() ?? 0,
      showSignSwitch: false,
      initialIsNegative: false,
    );

    if (result != null) {
      setState(() {
        _amountScaled = result.abs();
        _errorMessage = null;
      });
    }
  }

  String _formatAmount(int scaledAmount) {
    final decimal = (Decimal.fromInt(scaledAmount) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 2);
    final currency = Currency.currencyFrom(_selectedAccount!.currency);
    return currency.format(decimal);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) {
      setState(() {
        _errorMessage = 'Please select an account';
      });
      return;
    }
    if (_amountScaled == null) {
      setState(() {
        _errorMessage = 'Please enter an amount';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final amount = (Decimal.fromInt(_amountScaled!) / Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 2);
      final adjustedAmount = _isAllocating ? amount : -amount;

      final booking = SavingsVirtualBooking(
        id: const Uuid().v4obj(),
        savingsId: widget.savings.id!,
        accountId: _selectedAccount!.id!,
        amountValue: adjustedAmount,
        amountUnit: _selectedAccount!.currency,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        bookingDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await context.read<SavingsVirtualBookingRepository>().create(booking);

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
      title: const Text('Adjust Savings'),
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

                // Account selection
                BlocBuilder<AccountCubit, dynamic>(
                  builder: (context, state) {
                    final accounts = state.accounts as List<Account>? ?? [];

                    if (accounts.isEmpty) {
                      return const Text('No accounts available');
                    }

                    return DropdownButtonFormField<Account>(
                      value: _selectedAccount,
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        border: OutlineInputBorder(),
                        helperText: 'Which account to allocate from/to',
                      ),
                      items: accounts.map((account) {
                        return DropdownMenuItem(
                          value: account,
                          child: Text(account.name),
                        );
                      }).toList(),
                      onChanged: (account) {
                        setState(() {
                          _selectedAccount = account;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select an account';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Amount
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
                          ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Direction: Allocate or Deallocate
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Allocate'),
                      icon: Icon(Icons.add_circle),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Deallocate'),
                      icon: Icon(Icons.remove_circle),
                    ),
                  ],
                  selected: {_isAllocating},
                  onSelectionChanged: (set) {
                    setState(() {
                      _isAllocating = set.first;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _isAllocating
                      ? 'Move money from spendable to savings'
                      : 'Move money from savings to spendable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                const SizedBox(height: 16),

                // Note
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g., End of month savings',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
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
