import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/account_selector_dialog.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/amount_dialog.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// A dialog for creating or editing virtual savings bookings.
///
/// Virtual bookings allow users to allocate or deallocate funds to/from
/// savings without actual transactions.
///
/// When [booking] is null, the dialog operates in create mode.
/// When [booking] is provided, the dialog operates in edit mode with
/// pre-filled values and a delete option.
///
/// Returns `true` if a booking was created, updated, or deleted.
/// Returns `null` if the dialog was cancelled without changes.
///
/// Example usage:
/// ```dart
/// // Create a new booking
/// final result = await showDialog<bool>(
///   context: context,
///   builder: (context) => VirtualBookingDialog(savings: savings),
/// );
///
/// // Edit an existing booking
/// final result = await showDialog<bool>(
///   context: context,
///   builder: (context) => VirtualBookingDialog(
///     savings: savings,
///     booking: existingBooking,
///   ),
/// );
///
/// if (result == true) {
///   // Reload data to reflect changes
/// }
/// ```
class VirtualBookingDialog extends StatefulWidget {
  /// The savings instance to create or edit bookings for.
  final Savings savings;

  /// The booking to edit. If null, creates a new booking.
  final SavingsVirtualBooking? booking;

  const VirtualBookingDialog({required this.savings, this.booking, super.key});

  @override
  State<VirtualBookingDialog> createState() => _VirtualBookingDialogState();
}

class _VirtualBookingDialogState extends State<VirtualBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  Account? _selectedAccount;
  int? _amountScaled;
  bool _isAllocating =
      true; // true = add to savings, false = remove from savings
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.booking != null) {
      _initializeFromBooking();
    }
  }

  void _initializeFromBooking() {
    final booking = widget.booking!;
    final absAmount = booking.amountValue.abs();
    _amountScaled = (absAmount * Decimal.fromInt(100)).toBigInt().toInt();
    _isAllocating = booking.amountValue >= Decimal.zero;
    _noteController.text = booking.note ?? '';
  }

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
    final decimal = decimalUnscale(scaledAmount)!;
    final currencyUnit =
        widget.booking?.amountUnit ?? _selectedAccount?.currency;
    if (currencyUnit == null) {
      return decimal.toString();
    }
    final currency = Currency.currencyFrom(currencyUnit);
    return currency.format(decimal);
  }

  Future<void> _delete() async {
    if (widget.booking == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Adjustment'),
        content: Text(
          'Are you sure you want to delete this adjustment of ${widget.booking!.format()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await context.read<SavingsVirtualBookingRepository>().delete(
          widget.booking!.id,
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
        id: widget.booking?.id ?? const Uuid().v4obj(),
        savingsId: widget.savings.id,
        accountId: _selectedAccount!.id,
        amountValue: adjustedAmount,
        amountUnit: _selectedAccount!.currency,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        bookingDate: widget.booking?.bookingDate ?? DateTime.now(),
        createdAt: widget.booking?.createdAt ?? DateTime.now(),
      );

      final repository = context.read<SavingsVirtualBookingRepository>();
      if (widget.booking != null) {
        await repository.update(booking);
      } else {
        await repository.create(booking);
      }

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
    final isEditMode = widget.booking != null;

    return AlertDialog(
      title: Text(isEditMode ? 'Edit Adjustment' : 'Adjust Savings'),
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

                // Account
                InkWell(
                  onTap: () async {
                    final a = await showDialog<Account>(
                      context: context,
                      builder: (context) => AccountSelectorDialog(
                        selectedId: _selectedAccount?.id,
                      ),
                    );
                    if (a != null) {
                      setState(() {
                        _selectedAccount = a;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Account',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _selectedAccount != null
                          ? _selectedAccount!.name
                          : 'Select account',
                      style: _selectedAccount == null
                          ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                  ),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
        if (isEditMode)
          TextButton(
            onPressed: _isLoading ? null : _delete,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        const Spacer(),
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
