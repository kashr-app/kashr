import 'package:finanalyzer/core/widgets/period_selector.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/widgets/turnover_card.dart';
import 'package:finanalyzer/turnover/widgets/turnover_filter_dialog.dart';
import 'package:finanalyzer/turnover/widgets/turnover_sort_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TurnoversRoute extends GoRouteData with $TurnoversRoute {
  const TurnoversRoute({this.filter, this.sort});

  final TurnoverFilter? filter;
  final TurnoverSort? sort;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TurnoversPage(
      initialFilter: filter ?? TurnoverFilter.empty,
      initialSort: sort ?? TurnoverSort.defaultSort,
    );
  }
}

class TurnoversPage extends StatefulWidget {
  const TurnoversPage({
    this.initialFilter = TurnoverFilter.empty,
    this.initialSort = TurnoverSort.defaultSort,
    super.key,
  });

  final TurnoverFilter initialFilter;
  final TurnoverSort initialSort;

  @override
  State<TurnoversPage> createState() => _TurnoversPageState();
}

class _TurnoversPageState extends State<TurnoversPage> {
  final log = Logger();
  final ScrollController _scrollController = ScrollController();
  final List<TurnoverWithTags> _items = [];

  static const _pageSize = 10;
  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  // Filter and sort state
  late TurnoverFilter _filter;
  late TurnoverSort _sort;

  // Batch selection state
  final Set<String> _selectedTurnoverIds = {};
  bool get _isBatchMode => _selectedTurnoverIds.isNotEmpty;

  late final TurnoverRepository _repository;
  late final TagTurnoverRepository _tagTurnoverRepository;

  @override
  void initState() {
    super.initState();
    _repository = context.read<TurnoverRepository>();
    _tagTurnoverRepository = context.read<TagTurnoverRepository>();

    // Initialize filter and sort from widget parameters
    _filter = widget.initialFilter;
    _sort = widget.initialSort;

    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Load more when we're 200 pixels from the bottom
    if (maxScroll - currentScroll <= 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newItems = await _repository.getTurnoversWithTagsPaginated(
        limit: _pageSize,
        offset: _currentOffset,
        filter: _filter,
        sort: _sort,
      );

      setState(() {
        _items.addAll(newItems);
        _currentOffset += newItems.length;
        _hasMore = newItems.length >= _pageSize;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      log.e(
        'Error fetching turnovers page',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _currentOffset = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openFilterDialog() async {
    final result = await showDialog<TurnoverFilter>(
      context: context,
      builder: (context) => TurnoverFilterDialog(initialFilter: _filter),
    );

    if (result != null) {
      setState(() {
        _filter = result;
      });
      await _refresh();
    }
  }

  Future<void> _openSortDialog() async {
    final result = await showDialog<TurnoverSort>(
      context: context,
      builder: (context) => TurnoverSortDialog(initialSort: _sort),
    );

    if (result != null) {
      setState(() {
        _sort = result;
      });
      await _refresh();
    }
  }

  void _toggleSortDirection() {
    setState(() {
      _sort = TurnoverSort(
        orderBy: _sort.orderBy,
        direction: _sort.direction == SortDirection.asc
            ? SortDirection.desc
            : SortDirection.asc,
      );
    });
    _refresh();
  }

  void _toggleTurnoverSelection(String turnoverId) {
    setState(() {
      if (_selectedTurnoverIds.contains(turnoverId)) {
        _selectedTurnoverIds.remove(turnoverId);
      } else {
        _selectedTurnoverIds.add(turnoverId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTurnoverIds.clear();
    });
  }

  Future<void> _batchAddTag() async {
    if (_selectedTurnoverIds.isEmpty) return;

    final tagRepository = context.read<TagRepository>();
    final allTags = await tagRepository.getAllTags();

    if (!mounted) return;

    final selectedTag = await showDialog<Tag>(
      context: context,
      builder: (context) => _BatchAddTagDialog(availableTags: allTags),
    );

    if (selectedTag == null || !mounted) return;

    try {
      // Get selected turnovers
      final selectedTurnovers = _items
          .where(
            (item) =>
                item.turnover.id != null &&
                _selectedTurnoverIds.contains(item.turnover.id!.uuid),
          )
          .toList();

      // Create tag turnovers for each selected turnover
      await _tagTurnoverRepository.batchAddTagToTurnovers(
        selectedTurnovers
            .map((t) => t.turnover)
            .toList(),
        selectedTag,
      );

      _clearSelection();
      await _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added tag "${selectedTag.name}" to '
              '${selectedTurnovers.length} turnovers',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      log.e(
        'Error batch adding tag',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding tag: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _batchRemoveTag() async {
    if (_selectedTurnoverIds.isEmpty) return;

    // Get all tags that are associated with at least one of the
    // selected turnovers
    final selectedTurnovers = _items
        .where(
          (item) =>
              item.turnover.id != null &&
              _selectedTurnoverIds.contains(item.turnover.id!.uuid),
        )
        .toList();

    // Collect all unique tags from the selected turnovers
    final tagsMap = <String, Tag>{};
    for (final turnoverWithTags in selectedTurnovers) {
      for (final tagTurnover in turnoverWithTags.tagTurnovers) {
        final tag = tagTurnover.tag;
        if (tag.id != null) {
          tagsMap[tag.id!.uuid] = tag;
        }
      }
    }

    if (tagsMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tags found on selected turnovers'),
        ),
      );
      return;
    }

    final availableTags = tagsMap.values.toList();

    if (!mounted) return;

    final selectedTag = await showDialog<Tag>(
      context: context,
      builder: (context) => _BatchRemoveTagDialog(availableTags: availableTags),
    );

    if (selectedTag == null || !mounted) return;

    try {
      // Remove the tag from all selected turnovers
      await _tagTurnoverRepository.batchRemoveTagFromTurnovers(
        selectedTurnovers.map((t) => t.turnover).toList(),
        selectedTag,
      );

      _clearSelection();
      await _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed tag "${selectedTag.name}" from '
              '${selectedTurnovers.length} turnovers',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      log.e(
        'Error batch removing tag',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing tag: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _previousPeriod() {
    if (_filter.period == null) return;

    final currentPeriod = _filter.period!;
    final newPeriod = currentPeriod.month == 1
        ? YearMonth(year: currentPeriod.year - 1, month: 12)
        : YearMonth(year: currentPeriod.year, month: currentPeriod.month - 1);

    setState(() {
      _filter = _filter.copyWith(period: newPeriod);
    });
    _refresh();
  }

  void _nextPeriod() {
    if (_filter.period == null) return;

    final currentPeriod = _filter.period!;
    final newPeriod = currentPeriod.month == 12
        ? YearMonth(year: currentPeriod.year + 1, month: 1)
        : YearMonth(year: currentPeriod.year, month: currentPeriod.month + 1);

    setState(() {
      _filter = _filter.copyWith(period: newPeriod);
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isBatchMode ? _buildBatchAppBar() : _buildNormalAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (_filter.hasFilters || _sort != TurnoverSort.defaultSort)
              _buildFilterChips(),
            Expanded(
              child: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('Turnovers'),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: _openSortDialog,
          tooltip: 'Sort',
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _openFilterDialog,
          tooltip: 'Filter',
        ),
      ],
    );
  }

  AppBar _buildBatchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
        tooltip: 'Cancel selection',
      ),
      title: Text('${_selectedTurnoverIds.length} selected'),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.label),
          onPressed: _batchAddTag,
          tooltip: 'Add tag',
        ),
        IconButton(
          icon: const Icon(Icons.label_off),
          onPressed: _batchRemoveTag,
          tooltip: 'Remove tag',
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period selector (if period filter is set)
          if (_filter.period != null) ...[
            PeriodSelector(
              selectedPeriod: _filter.period!,
              onPreviousMonth: _previousPeriod,
              onNextMonth: _nextPeriod,
              onAction: OnAction(
                tooltip: 'Clear period filter',
                onAction: () {
                  setState(() {
                    _filter = _filter.copyWith(period: null);
                  });
                  _refresh();
                },
                icon: Icon(Icons.delete),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Other filter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Sort indicator chip (tappable to toggle direction)
              if (_sort != TurnoverSort.defaultSort)
                ActionChip(
                  avatar: Icon(
                    _sort.direction == SortDirection.asc
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 18,
                  ),
                  label: Text(_getSortFieldName(_sort.orderBy)),
                  onPressed: _toggleSortDirection,
                ),

              // Unallocated filter chip
              if (_filter.unallocatedOnly == true)
                Chip(
                  label: const Text('Unallocated'),
                  onDeleted: () {
                    setState(() {
                      _filter = _filter.copyWith(unallocatedOnly: null);
                    });
                    _refresh();
                  },
                ),

              // Tag filter chips (one per tag)
              if (_filter.tagIds != null)
                ..._filter.tagIds!.map((tagId) {
                  return FutureBuilder(
                    future: context.read<TagRepository>().getTagById(
                      UuidValue.fromString(tagId),
                    ),
                    builder: (context, snapshot) {
                      final tag = snapshot.data;
                      final tagName = tag?.name ?? tagId.substring(0, 8);
                      final tagColor = tag?.color != null
                          ? Color(
                              int.parse(tag!.color!.replaceFirst('#', '0xff')),
                            )
                          : null;

                      return Chip(
                        label: Text(tagName),
                        backgroundColor: tagColor?.withValues(alpha: 0.2),
                        side: tagColor != null
                            ? BorderSide(color: tagColor, width: 1.5)
                            : null,
                        onDeleted: () {
                          setState(() {
                            final updatedTagIds = List<String>.from(
                              _filter.tagIds ?? [],
                            )..remove(tagId);
                            _filter = _filter.copyWith(
                              tagIds: updatedTagIds.isEmpty
                                  ? null
                                  : updatedTagIds,
                            );
                          });
                          _refresh();
                        },
                      );
                    },
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }

  String _getSortFieldName(SortField field) {
    return switch (field) {
      SortField.bookingDate => 'Date',
      SortField.amount => 'Amount',
      SortField.counterPart => 'Counter Party',
    };
  }

  Widget _buildBody() {
    // Show error on first page
    if (_items.isEmpty && _error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading turnovers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (_items.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No turnovers found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your turnovers will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Show list
    return ListView.builder(
      controller: _scrollController,
      itemCount: _items.length + (_hasMore || _isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the bottom
        if (index >= _items.length) {
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final turnoverWithTags = _items[index];
        final turnoverId = turnoverWithTags.turnover.id?.uuid;
        final isSelected =
            turnoverId != null && _selectedTurnoverIds.contains(turnoverId);

        return TurnoverCard(
          turnoverWithTags: turnoverWithTags,
          isSelected: isSelected,
          isBatchMode: _isBatchMode,
          onTap: () async {
            final id = turnoverWithTags.turnover.id;
            if (id == null) {
              log.e('Turnover has no id');
              return;
            }

            if (_isBatchMode) {
              _toggleTurnoverSelection(id.uuid);
            } else {
              await TurnoverTagsRoute(turnoverId: id.uuid).push(context);
              _refresh();
            }
          },
          onLongPress: () {
            final id = turnoverWithTags.turnover.id;
            if (id == null) {
              log.e('Turnover has no id');
              return;
            }
            _toggleTurnoverSelection(id.uuid);
          },
        );
      },
    );
  }
}

/// Dialog for selecting a tag to add to multiple turnovers.
class _BatchAddTagDialog extends StatefulWidget {
  final List<Tag> availableTags;

  const _BatchAddTagDialog({required this.availableTags});

  @override
  State<_BatchAddTagDialog> createState() => _BatchAddTagDialogState();
}

class _BatchAddTagDialogState extends State<_BatchAddTagDialog> {
  late TextEditingController _searchController;
  List<Tag> _filteredTags = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredTags = widget.availableTags;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredTags = widget.availableTags;
      } else {
        _filteredTags = widget.availableTags
            .where((tag) => tag.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Tag to Add',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search tags',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Divider(),
            Flexible(
              child: _filteredTags.isEmpty
                  ? const Center(child: Text('No tags found'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];
                        final tagColor = _parseColor(tag.color);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tagColor.withValues(alpha: 0.3),
                            child: Icon(
                              Icons.label,
                              color: tagColor,
                              size: 20,
                            ),
                          ),
                          title: Text(tag.name),
                          onTap: () {
                            Navigator.of(context).pop(tag);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey.shade400;
    }

    try {
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.grey.shade400;
    }
  }
}

/// Dialog for selecting a tag to remove from multiple turnovers.
class _BatchRemoveTagDialog extends StatefulWidget {
  final List<Tag> availableTags;

  const _BatchRemoveTagDialog({required this.availableTags});

  @override
  State<_BatchRemoveTagDialog> createState() => _BatchRemoveTagDialogState();
}

class _BatchRemoveTagDialogState extends State<_BatchRemoveTagDialog> {
  late TextEditingController _searchController;
  List<Tag> _filteredTags = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredTags = widget.availableTags;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredTags = widget.availableTags;
      } else {
        _filteredTags = widget.availableTags
            .where((tag) => tag.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Tag to Remove',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search tags',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Divider(),
            Flexible(
              child: _filteredTags.isEmpty
                  ? const Center(child: Text('No tags found'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredTags.length,
                      itemBuilder: (context, index) {
                        final tag = _filteredTags[index];
                        final tagColor = _parseColor(tag.color);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tagColor.withValues(alpha: 0.3),
                            child: Icon(
                              Icons.label_off,
                              color: tagColor,
                              size: 20,
                            ),
                          ),
                          title: Text(tag.name),
                          onTap: () {
                            Navigator.of(context).pop(tag);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey.shade400;
    }

    try {
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.grey.shade400;
    }
  }
}
