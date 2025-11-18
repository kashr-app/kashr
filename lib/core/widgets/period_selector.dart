import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OnAction {
  final String tooltip;
  final VoidCallback? onAction;
  final Widget icon;

  OnAction({required this.tooltip, required this.onAction, required this.icon});
}

/// A widget for selecting and navigating between periods (months).
///
/// Displays a card with the current period and navigation controls to move
/// between periods. Optionally supports an action button.
class PeriodSelector extends StatelessWidget {
  /// Creates a period selector.
  ///
  /// [selectedPeriod] is the currently selected period to display.
  /// [onPreviousMonth] is called when the user taps the previous month button.
  /// [onNextMonth] is called when the user taps the next month button.
  /// [onAction] is optionally called when the user taps the delete button.
  /// If [onAction] is null, the delete button will not be shown.
  const PeriodSelector({
    required this.selectedPeriod,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.onAction,
    super.key,
  });

  final YearMonth selectedPeriod;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final OnAction? onAction;

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.yMMMM().format(selectedPeriod.toDateTime());

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
            if (onAction != null)
              IconButton(
                icon: onAction!.icon,
                onPressed: onAction!.onAction,
                tooltip: onAction!.tooltip,
              ),
          ],
        ),
      ),
    );
  }
}
