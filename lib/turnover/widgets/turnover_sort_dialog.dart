import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:flutter/material.dart';

/// Dialog for editing turnover sort options.
class TurnoverSortDialog extends StatefulWidget {
  const TurnoverSortDialog({
    required this.initialSort,
    super.key,
  });

  final TurnoverSort initialSort;

  @override
  State<TurnoverSortDialog> createState() => _TurnoverSortDialogState();
}

class _TurnoverSortDialogState extends State<TurnoverSortDialog> {
  late SortField _sortField;
  late SortDirection _sortDirection;

  @override
  void initState() {
    super.initState();
    _sortField = widget.initialSort.orderBy;
    _sortDirection = widget.initialSort.direction;
  }

  void _applySort() {
    final sort = TurnoverSort(
      orderBy: _sortField,
      direction: _sortDirection,
    );
    Navigator.of(context).pop(sort);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sort Turnovers',
                    style: theme.textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort by',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownMenu<SortField>(
                    key: const ValueKey('sort_field_dropdown'),
                    initialSelection: _sortField,
                    label: const Text('Field'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(
                        value: SortField.bookingDate,
                        label: 'Booking Date',
                      ),
                      DropdownMenuEntry(
                        value: SortField.amount,
                        label: 'Amount',
                      ),
                      DropdownMenuEntry(
                        value: SortField.counterPart,
                        label: 'Counter Party',
                      ),
                    ],
                    onSelected: (value) {
                      if (value != null) {
                        setState(() {
                          _sortField = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Sort direction
                  Text(
                    'Direction',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<SortDirection>(
                    groupValue: _sortDirection,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortDirection = value;
                        });
                      }
                    },
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Radio<SortDirection>(
                            value: SortDirection.asc,
                          ),
                          title: Row(
                            children: [
                              const Icon(Icons.arrow_upward, size: 18),
                              const SizedBox(width: 8),
                              const Text('Ascending'),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _sortDirection = SortDirection.asc;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          leading: const Radio<SortDirection>(
                            value: SortDirection.desc,
                          ),
                          title: Row(
                            children: [
                              const Icon(Icons.arrow_downward, size: 18),
                              const SizedBox(width: 8),
                              const Text('Descending'),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _sortDirection = SortDirection.desc;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _applySort,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
