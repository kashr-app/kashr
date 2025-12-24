import 'package:kashr/turnover/model/year_month.dart';
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
  /// [onMonthSelected] is called when the user selects a month from the picker.
  /// [onAction] is optionally called when the user taps the delete button.
  /// [locked] if set true, the user cannot change nor remove the period.
  /// If [onAction] is null, the delete button will not be shown.
  const PeriodSelector({
    required this.selectedPeriod,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onMonthSelected,
    this.onAction,
    this.locked = false,
    super.key,
  });

  final YearMonth selectedPeriod;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final void Function(YearMonth) onMonthSelected;
  final OnAction? onAction;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.yMMMM().format(selectedPeriod.toDateTime());

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!locked)
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPreviousMonth,
                tooltip: 'Previous month',
              ),
            Expanded(
              child: InkWell(
                onTap: locked
                    ? null
                    : () async {
                        final newSelected = await MonthPickerDialog.show(
                          context,
                          selectedPeriod,
                        );
                        if (newSelected != null) {
                          onMonthSelected(newSelected);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    monthName,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (!locked)
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextMonth,
                tooltip: 'Next month',
              ),
            if (onAction != null && !locked)
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

/// A dialog for selecting a year and month.
class MonthPickerDialog extends StatefulWidget {
  const MonthPickerDialog({super.key, required this.selectedPeriod});

  final YearMonth selectedPeriod;

  static Future<YearMonth?> show(
    BuildContext context,
    YearMonth selectedPeriod,
  ) {
    return showDialog<YearMonth>(
      context: context,
      builder: (context) => MonthPickerDialog(selectedPeriod: selectedPeriod),
    );
  }

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.selectedPeriod.year;
    _selectedMonth = widget.selectedPeriod.month;
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Month', style: textTheme.headlineSmall),
              const SizedBox(height: 24),
              _YearSelector(
                selectedYear: _selectedYear,
                onYearChanged: (year) {
                  setState(() {
                    _selectedYear = year;
                  });
                },
              ),
              const SizedBox(height: 24),
              _MonthGrid(
                selectedMonth: _selectedMonth,
                onMonthSelected: (month) {
                  setState(() {
                    _selectedMonth = month;
                  });
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _selectToday,
                    icon: const Icon(Icons.today),
                    label: const Text('Today'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        YearMonth(year: _selectedYear, month: _selectedMonth),
                      );
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget for selecting a year with navigation buttons.
class _YearSelector extends StatelessWidget {
  const _YearSelector({
    required this.selectedYear,
    required this.onYearChanged,
  });

  final int selectedYear;
  final void Function(int) onYearChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => onYearChanged(selectedYear - 1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous year',
        ),
        SizedBox(
          width: 80,
          child: Text(
            selectedYear.toString(),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          onPressed: () => onYearChanged(selectedYear + 1),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next year',
        ),
      ],
    );
  }
}

/// A grid displaying all 12 months for selection.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.selectedMonth,
    required this.onMonthSelected,
    required this.colorScheme,
  });

  final int selectedMonth;
  final void Function(int) onMonthSelected;
  final ColorScheme colorScheme;

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final monthNumber = index + 1;
        final isSelected = monthNumber == selectedMonth;

        return Material(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onMonthSelected(monthNumber),
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(
                _monthNames[index],
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
