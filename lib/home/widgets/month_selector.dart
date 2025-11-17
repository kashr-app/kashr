import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A widget for selecting and navigating between months.
class MonthSelector extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const MonthSelector({
    required this.selectedYear,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.yMMMM().format(
      DateTime(selectedYear, selectedMonth),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPreviousMonth,
              tooltip: 'Previous month',
            ),
            Text(
              monthName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNextMonth,
              tooltip: 'Next month',
            ),
          ],
        ),
      ),
    );
  }
}
