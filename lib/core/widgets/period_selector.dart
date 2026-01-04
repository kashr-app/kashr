import 'package:kashr/core/model/period.dart';
import 'package:kashr/turnover/model/year_month.dart';
import 'package:kashr/turnover/model/year_week.dart';
import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';

class OnAction {
  final String tooltip;
  final VoidCallback? onAction;
  final Widget icon;

  OnAction({required this.tooltip, required this.onAction, required this.icon});
}

/// A widget for selecting and navigating between periods.
///
/// Displays a card with the current period and navigation controls to move
/// between periods. Optionally supports an action button.
class PeriodSelector extends StatelessWidget {
  /// Creates a period selector.
  ///
  /// [selectedPeriod] is the currently selected period to display.
  /// [onPreviousPeriod] is called when the user taps the previous period button.
  /// [onNextPeriod] is called when the user taps the next period button.
  /// [onPeriodSelected] is called when the user selects a period from the picker.
  /// [onAction] is optionally called when the user taps the delete button.
  /// [locked] if set true, the user cannot change nor remove the period.
  /// If [onAction] is null, the delete button will not be shown.
  const PeriodSelector({
    required this.selectedPeriod,
    required this.onPreviousPeriod,
    required this.onNextPeriod,
    required this.onPeriodSelected,
    this.onAction,
    this.locked = false,
    super.key,
  });

  final Period selectedPeriod;
  final VoidCallback onPreviousPeriod;
  final VoidCallback onNextPeriod;
  final void Function(Period period) onPeriodSelected;
  final OnAction? onAction;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!locked)
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPreviousPeriod,
                tooltip: 'Previous period',
              ),
            Expanded(
              child: InkWell(
                onTap: locked
                    ? null
                    : () async {
                        final newSelected = await PeriodPickerDialog.show(
                          context,
                          selectedPeriod,
                        );
                        if (newSelected != null) {
                          onPeriodSelected(newSelected);
                        }
                      },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    selectedPeriod.format(),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (!locked)
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextPeriod,
                tooltip: 'Next period',
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

/// A unified dialog for selecting periods (week, month, or year).
///
/// Allows users to switch between period types and select the appropriate
/// time period based on the selected type.
class PeriodPickerDialog extends StatefulWidget {
  const PeriodPickerDialog({super.key, required this.initialPeriod});

  final Period initialPeriod;

  static Future<Period?> show(BuildContext context, Period initialPeriod) {
    return showDialog<Period>(
      context: context,
      builder: (context) => PeriodPickerDialog(initialPeriod: initialPeriod),
    );
  }

  @override
  State<PeriodPickerDialog> createState() => _PeriodPickerDialogState();
}

class _PeriodPickerDialogState extends State<PeriodPickerDialog> {
  late PeriodType _periodType;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedWeek;

  @override
  void initState() {
    super.initState();
    _periodType = widget.initialPeriod.type;
    _selectedYear = widget.initialPeriod.startInclusive.year;
    _selectedMonth = widget.initialPeriod.startInclusive.month;
    _selectedWeek = YearWeek.of(widget.initialPeriod.startInclusive).week;
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      _selectedYear = now.year;
      _selectedMonth = now.month;
      _selectedWeek = YearWeek.of(now).week;
    });
  }

  Period _buildPeriod() {
    return switch (_periodType) {
      PeriodType.week => YearWeek(
        year: _selectedYear,
        week: _selectedWeek,
      ).period,
      PeriodType.month => YearMonth(
        year: _selectedYear,
        month: _selectedMonth,
      ).period,
      PeriodType.year => Period.of(DateTime(_selectedYear), PeriodType.year),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Period', style: textTheme.headlineSmall),
              const SizedBox(height: 16),
              SegmentedButton<PeriodType>(
                segments: [
                  ButtonSegment(
                    value: PeriodType.week,
                    label: Text(PeriodType.week.title(context)),
                    icon: const Icon(Icons.view_week),
                  ),
                  ButtonSegment(
                    value: PeriodType.month,
                    label: Text(PeriodType.month.title(context)),
                    icon: const Icon(Icons.calendar_month),
                  ),
                  ButtonSegment(
                    value: PeriodType.year,
                    label: Text(PeriodType.year.title(context)),
                    icon: const Icon(Icons.calendar_today),
                  ),
                ],
                selected: {_periodType},
                onSelectionChanged: (Set<PeriodType> newSelection) {
                  setState(() {
                    _periodType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),
              _YearSelector(
                selectedYear: _selectedYear,
                onYearChanged: (year) {
                  setState(() {
                    _selectedYear = year;
                    if (_periodType == PeriodType.week) {
                      final maxWeeks = _getWeeksInYear(year);
                      if (_selectedWeek > maxWeeks) {
                        _selectedWeek = maxWeeks;
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              Flexible(
                child: switch (_periodType) {
                  PeriodType.month => _MonthGrid(
                    selectedMonth: _selectedMonth,
                    onMonthSelected: (month) {
                      setState(() {
                        _selectedMonth = month;
                      });
                    },
                    colorScheme: colorScheme,
                  ),
                  PeriodType.week => _WeekGrid(
                    selectedWeek: _selectedWeek,
                    weeksInYear: _getWeeksInYear(_selectedYear),
                    onWeekSelected: (week) {
                      setState(() {
                        _selectedWeek = week;
                      });
                    },
                    colorScheme: colorScheme,
                  ),
                  PeriodType.year => const SizedBox.shrink(),
                },
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
                      Navigator.of(context).pop(_buildPeriod());
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

  int _getWeeksInYear(int year) {
    final dec31 = DateTime(year, 12, 31);
    final jiffy = Jiffy.parseFromDateTime(dec31);
    final weekday = dec31.weekday;

    if (weekday == DateTime.thursday ||
        (jiffy.isLeapYear && weekday == DateTime.friday)) {
      return 53;
    }
    return 52;
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
    return Scrollbar(
      thumbVisibility: true,
      child: GridView.builder(
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
            color:
                isSelected ? colorScheme.primaryContainer : Colors.transparent,
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
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A grid displaying all weeks in a year for selection.
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.selectedWeek,
    required this.weeksInYear,
    required this.onWeekSelected,
    required this.colorScheme,
  });

  final int selectedWeek;
  final int weeksInYear;
  final void Function(int) onWeekSelected;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.5,
        ),
        itemCount: weeksInYear,
        itemBuilder: (context, index) {
          final weekNumber = index + 1;
          final isSelected = weekNumber == selectedWeek;

          return Material(
            color:
                isSelected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => onWeekSelected(weekNumber),
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: Text(
                  'W$weekNumber',
                  style: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
