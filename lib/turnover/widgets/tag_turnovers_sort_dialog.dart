import 'package:finanalyzer/turnover/model/tag_turnover_sort.dart';
import 'package:flutter/material.dart';

/// Dialog for editing tag turnover sort options.
class TagTurnoversSortDialog extends StatefulWidget {
  const TagTurnoversSortDialog({required this.initialSort, super.key});

  final TagTurnoverSort initialSort;

  @override
  State<TagTurnoversSortDialog> createState() => _TagTurnoversSortDialogState();
}

class _TagTurnoversSortDialogState extends State<TagTurnoversSortDialog> {
  late TagTurnoverSortField _sortField;
  late TagTurnoverSortDirection _sortDirection;

  @override
  void initState() {
    super.initState();
    _sortField = widget.initialSort.orderBy;
    _sortDirection = widget.initialSort.direction;
  }

  void _applySort() {
    final sort = TagTurnoverSort(orderBy: _sortField, direction: _sortDirection);
    Navigator.of(context).pop(sort);
  }

  void _clear() {
    final sort = TagTurnoverSort.defaultSort;
    setState(() {
      _sortField = sort.orderBy;
      _sortDirection = sort.direction;
    });
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
                  Text('Sort', style: theme.textTheme.titleLarge),
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
                  Text('Sort by', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownMenu<TagTurnoverSortField>(
                    key: const ValueKey('sort_field_dropdown'),
                    initialSelection: _sortField,
                    label: const Text('Field'),
                    expandedInsets: EdgeInsets.zero,
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(
                        value: TagTurnoverSortField.bookingDate,
                        label: 'Booking Date',
                      ),
                      DropdownMenuEntry(
                        value: TagTurnoverSortField.amount,
                        label: 'Amount',
                      ),
                      DropdownMenuEntry(
                        value: TagTurnoverSortField.createdAt,
                        label: 'Created',
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
                  Text('Direction', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  RadioGroup<TagTurnoverSortDirection>(
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
                          leading: const Radio<TagTurnoverSortDirection>(
                            value: TagTurnoverSortDirection.asc,
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.arrow_downward, size: 18),
                              SizedBox(width: 8),
                              Text('Ascending'),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _sortDirection = TagTurnoverSortDirection.asc;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        ListTile(
                          leading: const Radio<TagTurnoverSortDirection>(
                            value: TagTurnoverSortDirection.desc,
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.arrow_upward, size: 18),
                              SizedBox(width: 8),
                              Text('Descending'),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _sortDirection = TagTurnoverSortDirection.desc;
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
                  TextButton(onPressed: _clear, child: const Text('Clear')),
                  const Spacer(),
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
