import 'package:finanalyzer/core/widgets/period_selector.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
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

  late final TurnoverRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = context.read<TurnoverRepository>();

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
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
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
        ),
        body: Column(
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
        return TurnoverCard(
          turnoverWithTags: turnoverWithTags,
          onTap: () async {
            final id = turnoverWithTags.turnover.id;
            if (id == null) {
              log.e('Turnover has no id');
              return;
            }
            await TurnoverTagsRoute(turnoverId: id.uuid).push(context);
            _refresh();
          },
        );
      },
    );
  }
}
