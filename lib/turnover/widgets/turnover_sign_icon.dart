import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/model/turnover.dart';

class IconSign extends StatelessWidget {
  const IconSign({super.key, required this.sign, this.size});

  final TurnoverSign sign;
  final double? size;
  @override
  Widget build(BuildContext context) {
    return sign == TurnoverSign.income
        ? IconIncome(size: size)
        : IconExpense(size: size);
  }
}

class IconExpense extends StatelessWidget {
  const IconExpense({super.key, this.size});

  final double? size;
  @override
  Widget build(BuildContext context) {
    return Icon(
      iconExpense,
      color: Theme.of(context).decimalColor(-Decimal.one),
      size: size,
    );
  }
}

class IconIncome extends StatelessWidget {
  const IconIncome({super.key, this.size});

  final double? size;
  @override
  Widget build(BuildContext context) {
    return Icon(
      iconIncome,
      color: Theme.of(context).decimalColor(Decimal.one),
      size: size,
    );
  }
}
