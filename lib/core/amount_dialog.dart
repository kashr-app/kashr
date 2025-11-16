import 'package:finanalyzer/core/currency.dart';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

/// A dialog for entering currency amounts using scaled integer logic.
///
/// This dialog allows users to input amounts by typing digits, where each
/// digit shifts the previous value one magnitude up. The amount is stored
/// internally as a scaled integer (cents).
class AmountDialog extends StatefulWidget {
  /// Optional maximum amount in scaled integer (cents).
  final int? maxAmountScaled;

  /// Initial amount in scaled integer (cents).
  final int initialAmountScaled;

  /// Currency unit for display.
  final String currencyUnit;

  const AmountDialog({
    required this.currencyUnit,
    this.maxAmountScaled,
    this.initialAmountScaled = 0,
    super.key,
  });

  @override
  State<AmountDialog> createState() => _AmountDialogState();

  /// Shows the dialog and returns the entered amount as scaled integer.
  static Future<int?> show(
    BuildContext context, {
    required String currencyUnit,
    int? maxAmountScaled,
    int initialAmountScaled = 0,
  }) async {
    return showDialog<int>(
      context: context,
      builder: (context) => AmountDialog(
        currencyUnit: currencyUnit,
        maxAmountScaled: maxAmountScaled,
        initialAmountScaled: initialAmountScaled,
      ),
    );
  }
}

class _AmountDialogState extends State<AmountDialog> {
  late TextEditingController _controller;
  late int _amountScaled;

  @override
  void initState() {
    super.initState();
    _amountScaled = widget.initialAmountScaled;
    _controller = TextEditingController(text: _formatAmount(_amountScaled));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatAmount(int scaledAmount) {
    final decimal = (Decimal.fromInt(scaledAmount) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 2);
    return CurrencyExtension.formatNoSymbol(decimal, decimalDigits: 2);
  }

  String _formatAmountWithCurrency(int scaledAmount) {
    final decimal = (Decimal.fromInt(scaledAmount) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 2);
    final currency = Currency.currencyFrom(widget.currencyUnit);
    return currency.format(decimal, decimalDigits: 2);
  }

  void _onDigitPressed(String digit) {
    setState(() {
      _amountScaled = _amountScaled * 10 + int.parse(digit);
      _controller.text = _formatAmount(_amountScaled);
    });
  }

  void _onBackspace() {
    setState(() {
      _amountScaled = _amountScaled ~/ 10;
      _controller.text = _formatAmount(_amountScaled);
    });
  }

  void _onClear() {
    setState(() {
      _amountScaled = 0;
      _controller.text = _formatAmount(_amountScaled);
    });
  }

  void _setMaxAmount() {
    final max = widget.maxAmountScaled;
    if (max != null) {
      setState(() {
        _amountScaled = max;
        _controller.text = _formatAmount(_amountScaled);
      });
    }
  }

  bool get _isAmountExceeded {
    final max = widget.maxAmountScaled;
    return max != null && _amountScaled > max;
  }

  bool get _canConfirm => !_isAmountExceeded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currency = Currency.currencyFrom(widget.currencyUnit);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Maximum amount indicator (if set)
            if (widget.maxAmountScaled != null) ...[
              Row(
                children: [
                  Text(
                    'Maximum',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _isAmountExceeded ? colorScheme.error : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _setMaxAmount,
                    icon: Icon(
                      _isAmountExceeded
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 16,
                    ),
                    color: _isAmountExceeded ? colorScheme.error : null,
                    tooltip: 'Set to maximum',
                  ),
                ],
              ),
              Text(
                _formatAmountWithCurrency(widget.maxAmountScaled!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isAmountExceeded ? colorScheme.error : null,
                ),
              ),
              const Divider(),
            ],

            // Amount display
            Text(
              'Enter Amount',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '${currency.symbol()} ${_controller.text}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: _isAmountExceeded ? colorScheme.error : null,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Number pad
            _NumberPad(
              onDigitPressed: _onDigitPressed,
              onBackspace: _onBackspace,
              onClear: _onClear,
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _canConfirm
                      ? () => Navigator.of(context).pop(_amountScaled)
                      : null,
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final void Function(String digit) onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _NumberPad({
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton('1', onDigitPressed),
            _NumberButton('2', onDigitPressed),
            _NumberButton('3', onDigitPressed),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton('4', onDigitPressed),
            _NumberButton('5', onDigitPressed),
            _NumberButton('6', onDigitPressed),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton('7', onDigitPressed),
            _NumberButton('8', onDigitPressed),
            _NumberButton('9', onDigitPressed),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton('C', Icons.clear, onClear),
            _NumberButton('0', onDigitPressed),
            _ActionButton('⌫', Icons.backspace_outlined, onBackspace),
          ],
        ),
      ],
    );
  }
}

class _NumberButton extends StatelessWidget {
  final String digit;
  final void Function(String digit) onPressed;

  const _NumberButton(this.digit, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 56,
      child: FilledButton.tonal(
        onPressed: () => onPressed(digit),
        child: Text(
          digit,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton(this.label, this.icon, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 56,
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Icon(icon),
      ),
    );
  }
}
