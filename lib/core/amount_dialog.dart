import 'package:kashr/core/currency.dart';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:kashr/turnover/model/turnover.dart';

/// A dialog for entering currency amounts using scaled integer logic.
///
/// This dialog allows users to input amounts by typing digits, where each
/// digit shifts the previous value one magnitude up. The amount is stored
/// internally as a scaled integer (cents).
class AmountDialog extends StatefulWidget {
  /// Currency unit for display.
  final String currencyUnit;

  /// Whether to show a sign switch (positive/negative).
  final bool showSignSwitch;

  /// Initial amount in scaled integer (cents).
  final int initialAmountScaled;

  /// Optional maximum amount in scaled integer (cents).
  final int? maxAmountScaled;

  const AmountDialog({
    required this.currencyUnit,
    required this.showSignSwitch,
    this.initialAmountScaled = 0,
    this.maxAmountScaled,
    super.key,
  });

  @override
  State<AmountDialog> createState() => _AmountDialogState();

  /// Shows the bottom sheet and returns the entered amount as scaled integer.
  static Future<int?> show(
    BuildContext context, {
    required String currencyUnit,
    required bool showSignSwitch,
    int initialAmountScaled = 0,
    int? maxAmountScaled,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: AmountDialog(
          currencyUnit: currencyUnit,
          showSignSwitch: showSignSwitch,
          initialAmountScaled: initialAmountScaled,
          maxAmountScaled: maxAmountScaled,
        ),
      ),
    );
  }
}

const buttonWidth = 72.0;
const buttonHeight = 56.0;

class _AmountDialogState extends State<AmountDialog> {
  late TextEditingController _controller;
  late int _amountScaledNoSign;
  late bool _isNegative;

  @override
  void initState() {
    super.initState();
    _amountScaledNoSign = widget.initialAmountScaled.abs();
    _isNegative = widget.initialAmountScaled < 0;
    _controller = TextEditingController(
      text: _formatAmount(_amountScaledNoSign),
    );
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

  int get _amountWithSign =>
      _isNegative ? -_amountScaledNoSign : _amountScaledNoSign;

  void _onDigitPressed(String digit) {
    setState(() {
      _amountScaledNoSign = _amountScaledNoSign * 10 + int.parse(digit);
      _controller.text = _formatAmount(_amountScaledNoSign);
    });
  }

  void _onBackspace() {
    setState(() {
      _amountScaledNoSign = _amountScaledNoSign ~/ 10;
      _controller.text = _formatAmount(_amountScaledNoSign);
    });
  }

  void _onClear() {
    setState(() {
      _amountScaledNoSign = 0;
      _controller.text = _formatAmount(_amountScaledNoSign);
    });
  }

  void _setMaxAmount() {
    final max = widget.maxAmountScaled;
    if (max != null) {
      setState(() {
        _amountScaledNoSign = max;
        _controller.text = _formatAmount(_amountScaledNoSign);
      });
    }
  }

  bool get _isAmountExceeded {
    final max = widget.maxAmountScaled;
    return max != null && _amountScaledNoSign > max;
  }

  bool get _canConfirm => !_isAmountExceeded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currency = Currency.currencyFrom(widget.currencyUnit);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.0,
        right: 16.0,
        top: 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 36),
          // Amount display
          Text(
            '${_isNegative && widget.showSignSwitch ? '-' : ''}${currency.symbol()} ${_controller.text}',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: _isAmountExceeded ? colorScheme.error : null,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (widget.showSignSwitch) ...[
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Text(TurnoverSign.expense.title()),
                  icon: TurnoverSign.expense.icon(),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(TurnoverSign.income.title()),
                  icon: TurnoverSign.income.icon(),
                ),
              ],
              selected: {_isNegative},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _isNegative = selection.first;
                });
              },
            ),
          ],
          const SizedBox(height: 24),

          // Maximum amount indicator (if set)
          if (widget.maxAmountScaled != null) ...[
            Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: buttonWidth, height: buttonHeight),
                    const SizedBox(width: buttonWidth, height: buttonHeight),
                    const SizedBox(width: buttonWidth, height: buttonHeight),
                    _ActionButton(
                      onPressed: _amountScaledNoSign == widget.maxAmountScaled
                          ? null
                          : _setMaxAmount,
                      style: _isAmountExceeded
                          ? IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.errorContainer,
                              foregroundColor:
                                  theme.colorScheme.onErrorContainer,
                            )
                          : null,
                      child: Icon(
                        _amountScaledNoSign == widget.maxAmountScaled
                            ? Icons.check
                            : _isAmountExceeded
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Maximum',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _isAmountExceeded ? colorScheme.error : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatAmountWithCurrency(widget.maxAmountScaled!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _isAmountExceeded ? colorScheme.error : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
          ],
          // Number pad with integrated controls
          _NumberPad(
            onDigitPressed: _onDigitPressed,
            onBackspace: _onBackspace,
            onClear: _onClear,
            showSignSwitch: widget.showSignSwitch,
            isNegative: _isNegative,
            onToggleSign: () {
              setState(() {
                _isNegative = !_isNegative;
              });
            },
            currencyUnit: widget.currencyUnit,
            canConfirm: _canConfirm,
            onConfirm: () => Navigator.of(context).pop(_amountWithSign),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final void Function(String digit) onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool showSignSwitch;
  final bool isNegative;
  final VoidCallback onToggleSign;
  final String currencyUnit;
  final bool canConfirm;
  final VoidCallback onConfirm;

  const _NumberPad({
    required this.onDigitPressed,
    required this.onBackspace,
    required this.onClear,
    required this.showSignSwitch,
    required this.isNegative,
    required this.onToggleSign,
    required this.currencyUnit,
    required this.canConfirm,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Row 1: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton('7', onDigitPressed),
            _NumberButton('8', onDigitPressed),
            _NumberButton('9', onDigitPressed),
            _ActionButton(
              onPressed: onBackspace,
              child: Icon(Icons.backspace_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton('4', onDigitPressed),
            _NumberButton('5', onDigitPressed),
            _NumberButton('6', onDigitPressed),
            _ActionButton(onPressed: onClear, child: Icon(Icons.clear)),
          ],
        ),
        const SizedBox(height: 8),
        // Row 3: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NumberButton('1', onDigitPressed),
            _NumberButton('2', onDigitPressed),
            _NumberButton('3', onDigitPressed),
            if (showSignSwitch)
              _SignToggleButton(isNegative: isNegative, onToggle: onToggleSign)
            else
              const SizedBox(width: buttonWidth, height: buttonHeight),
            // _CurrencyButton(currencyUnit),
          ],
        ),
        const SizedBox(height: 8),
        // Bottom row: +/-, 0, OK
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: buttonWidth, height: buttonHeight),
            _NumberButton('0', onDigitPressed),
            const SizedBox(width: buttonWidth, height: buttonHeight),
            _ConfirmButton(canConfirm: canConfirm, onConfirm: onConfirm),
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
      width: buttonWidth,
      height: buttonHeight,
      child: FilledButton.tonal(
        onPressed: () => onPressed(digit),
        child: Text(digit, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;

  const _ActionButton({required this.child, this.onPressed, this.style});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: FilledButton(
        onPressed: onPressed,
        style:
            style ??
            FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              foregroundColor: Theme.of(
                context,
              ).colorScheme.onTertiaryContainer,
            ),
        child: child,
      ),
    );
  }
}

class _CurrencyButton extends StatelessWidget {
  final String currencyUnit;

  const _CurrencyButton(this.currencyUnit);

  @override
  Widget build(BuildContext context) {
    final currency = Currency.currencyFrom(currencyUnit);
    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: FilledButton(
        onPressed: () {
          // TODO: Implement currency selection if needed
        },
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
        child: Text(
          currency.symbol(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

class _SignToggleButton extends StatelessWidget {
  final bool isNegative;
  final VoidCallback onToggle;

  const _SignToggleButton({required this.isNegative, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: FilledButton(
        onPressed: onToggle,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.tertiaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
        child: Text('±', style: theme.textTheme.titleLarge),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final bool canConfirm;
  final VoidCallback onConfirm;

  const _ConfirmButton({required this.canConfirm, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: FilledButton(
        onPressed: canConfirm ? onConfirm : null,
        child: const Text('OK'),
      ),
    );
  }
}
