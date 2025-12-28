import 'package:kashr/core/widgets/period_selector.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/dialogs/tag_picker_dialog.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/year_month.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Dialog for editing turnover filters.
class TurnoverFilterDialog extends StatefulWidget {
  const TurnoverFilterDialog({required this.initialFilter, super.key});

  final TurnoverFilter initialFilter;

  @override
  State<TurnoverFilterDialog> createState() => _TurnoverFilterDialogState();
}

class _TurnoverFilterDialogState extends State<TurnoverFilterDialog> {
  late bool _unallocatedOnly;
  late YearMonth? _period;
  late Set<UuidValue> _selectedTagIds;
  late TurnoverSign? _sign;

  @override
  void initState() {
    super.initState();

    // Initialize from widget parameters
    _unallocatedOnly = widget.initialFilter.unallocatedOnly ?? false;
    _period = widget.initialFilter.period;
    _selectedTagIds = widget.initialFilter.tagIds?.toSet() ?? {};
    _sign = widget.initialFilter.sign;
  }

  Future<void> _pickTag() async {
    final tag = await TagPickerDialog.showWithExclusions(
      context,
      excludeTagIds: _selectedTagIds,
      allowCreate: false,
      title: 'Select Tag',
      subtitle: 'Choose a tag to filter by:',
    );

    if (tag != null) {
      setState(() {
        _selectedTagIds.add(tag.id);
      });
    }
  }

  void _applyFilters() {
    final filter = TurnoverFilter(
      unallocatedOnly: _unallocatedOnly ? true : null,
      period: _period,
      tagIds: _selectedTagIds.isEmpty ? null : _selectedTagIds.toList(),
      sign: _sign,
    );

    Navigator.of(context).pop(filter);
  }

  void _clearFilters() {
    setState(() {
      _unallocatedOnly = false;
      _period = null;
      _selectedTagIds = {};
      _sign = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter', style: theme.textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sign filter
                    Row(
                      children: [
                        Text('Type', style: theme.textTheme.titleMedium),
                        Spacer(),
                        DropdownButton<TurnoverSign?>(
                          value: _sign,
                          items: [
                            DropdownMenuItem(value: null, child: Text("All")),
                            DropdownMenuItem(
                              value: TurnoverSign.income,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_upward,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Income'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: TurnoverSign.expense,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_downward,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Expense'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _sign = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Period filter (Year and Month together)
                    CheckboxListTile(
                      title: Text(
                        'Filter by period',
                        style: theme.textTheme.titleMedium,
                      ),
                      value: _period != null,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            // Enable filter with current date if not already set
                            _period = YearMonth.now();
                          } else {
                            // Disable filter
                            _period = null;
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_period != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () =>
                            MonthPickerDialog.show(context, _period!).then((v) {
                              if (v != null) {
                                setState(() {
                                  _period = v;
                                });
                              }
                            }),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Period',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(
                            '${_period!.year} ${_getMonthName(_period!.month)}',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Tag filters
                    Text('Tags', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),

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
                    // Selected tags
                    BlocBuilder<TagCubit, TagState>(
                      builder: (context, tagState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedTagIds.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _selectedTagIds.map((id) {
                                  final tag = tagState.tagById[id]!;
                                  final tagColor = tag.color != null
                                      ? Color(
                                          int.parse(
                                            tag.color!.replaceFirst(
                                              '#',
                                              '0xff',
                                            ),
                                          ),
                                        )
                                      : null;

                                  return Chip(
                                    label: Text(tag.name),
                                    backgroundColor: tagColor?.withValues(
                                      alpha: 0.2,
                                    ),
                                    side: tagColor != null
                                        ? BorderSide(
                                            color: tagColor,
                                            width: 1.5,
                                          )
                                        : null,
                                    onDeleted: () {
                                      setState(() {
                                        _selectedTagIds.remove(tag.id);
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: _pickTag,
                              icon: const Icon(Icons.add),
                              label: const Text('Add tag filter'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                  Row(
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
          ],
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
