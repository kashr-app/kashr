import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A widget for selecting and navigating between periods (months).
///
/// Displays a card with the current period and navigation controls to move
/// between periods. Optionally supports a delete button to clear the period
/// filter.
class PeriodSelector extends StatelessWidget {
  /// Creates a period selector.
  ///
  /// [selectedPeriod] is the currently selected period to display.
  /// [onPreviousMonth] is called when the user taps the previous month button.
  /// [onNextMonth] is called when the user taps the next month button.
  /// [onDelete] is optionally called when the user taps the delete button.
  /// If [onDelete] is null, the delete button will not be shown.
  const PeriodSelector({
    required this.selectedPeriod,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onDelete,
    super.key,
  });

  final YearMonth selectedPeriod;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.yMMMM().format(
      selectedPeriod.toDateTime(),
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
            Expanded(
              child: Text(
                monthName,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNextMonth,
              tooltip: 'Next month',
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onDelete,
                tooltip: 'Clear period filter',
              ),
          ],
        ),
      ),
    );
  }
}
