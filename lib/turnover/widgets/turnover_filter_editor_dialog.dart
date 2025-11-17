import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dialog for editing turnover filters and sorting options.
class TurnoverFilterEditorDialog extends StatefulWidget {
  const TurnoverFilterEditorDialog({
    required this.initialFilter,
    required this.initialSort,
    super.key,
  });

  final TurnoverFilter initialFilter;
  final TurnoverSort initialSort;

  @override
  State<TurnoverFilterEditorDialog> createState() =>
      _TurnoverFilterEditorDialogState();
}

class _TurnoverFilterEditorDialogState
    extends State<TurnoverFilterEditorDialog> {
  late bool _unallocatedOnly;
  late int? _year;
  late int? _month;
  late Set<String> _selectedTagIds;
  late TurnoverSign? _sign;
  late SortField _sortField;
  late SortDirection _sortDirection;

  List<Tag> _availableTags = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();

    // Initialize from widget parameters
    _unallocatedOnly = widget.initialFilter.unallocatedOnly ?? false;
    _year = widget.initialFilter.year;
    _month = widget.initialFilter.month;
    _selectedTagIds = widget.initialFilter.tagIds?.toSet() ?? {};
    _sign = widget.initialFilter.sign;
    _sortField = widget.initialSort.orderBy;
    _sortDirection = widget.initialSort.direction;

    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final tagRepository = context.read<TagRepository>();
      final tags = await tagRepository.getAllTags();
      setState(() {
        _availableTags = tags;
        _isLoadingTags = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTags = false;
      });
    }
  }

  void _applyFilters() {
    final filter = TurnoverFilter(
      unallocatedOnly: _unallocatedOnly ? true : null,
      year: _year,
      month: _month,
      tagIds: _selectedTagIds.isEmpty ? null : _selectedTagIds.toList(),
      sign: _sign,
    );

    final sort = TurnoverSort(
      orderBy: _sortField,
      direction: _sortDirection,
    );

    Navigator.of(context).pop({'filter': filter, 'sort': sort});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & Sort',
                    style: theme.textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Unallocated only filter
              CheckboxListTile(
                title: const Text('Show unallocated only'),
                value: _unallocatedOnly,
                onChanged: (value) {
                  setState(() {
                    _unallocatedOnly = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),

              // Sign filter
              Text(
                'Filter by Type',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<TurnoverSign?>(
                segments: const [
                  ButtonSegment(
                    value: null,
                    label: Text('All'),
                  ),
                  ButtonSegment(
                    value: TurnoverSign.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_upward, color: Colors.green),
                  ),
                  ButtonSegment(
                    value: TurnoverSign.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_downward, color: Colors.red),
                  ),
                ],
                selected: {_sign},
                emptySelectionAllowed: true,
                onSelectionChanged: (Set<TurnoverSign?> newSelection) {
                  setState(() {
                    _sign = newSelection.isEmpty ? null : newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Month/Year filter
              Text(
                'Filter by Month',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _month,
                      decoration: const InputDecoration(
                        labelText: 'Month',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Any'),
                        ),
                        ...List.generate(12, (index) {
                          final month = index + 1;
                          return DropdownMenuItem(
                            value: month,
                            child: Text(_getMonthName(month)),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _month = value;
                          if (_month != null && _year == null) {
                            _year = DateTime.now().year;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _year,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Any'),
                        ),
                        ...List.generate(5, (index) {
                          final year = DateTime.now().year - index;
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _year = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tag filters
              Text(
                'Filter by Tags',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_isLoadingTags)
                const Center(child: CircularProgressIndicator())
              else if (_availableTags.isEmpty)
                const Text('No tags available')
              else
                Wrap(
                  spacing: 8,
                  children: _availableTags.map((tag) {
                    final isSelected = _selectedTagIds.contains(tag.id?.uuid);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTagIds.add(tag.id!.uuid);
                          } else {
                            _selectedTagIds.remove(tag.id?.uuid);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),

              // Sorting options
              Text(
                'Sort By',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<SortField>(
                value: _sortField,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SortField.bookingDate,
                    child: Text('Booking Date'),
                  ),
                  DropdownMenuItem(
                    value: SortField.amount,
                    child: Text('Amount'),
                  ),
                  DropdownMenuItem(
                    value: SortField.counterPart,
                    child: Text('Counter Party'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortField = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Sort direction
              SegmentedButton<SortDirection>(
                segments: const [
                  ButtonSegment(
                    value: SortDirection.asc,
                    label: Text('Ascending'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: SortDirection.desc,
                    label: Text('Descending'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_sortDirection},
                onSelectionChanged: (Set<SortDirection> newSelection) {
                  setState(() {
                    _sortDirection = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

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
                    onPressed: _applyFilters,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return monthNames[month - 1];
  }
}
