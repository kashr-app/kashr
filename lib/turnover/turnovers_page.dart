import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/widgets/turnover_card.dart';
import 'package:finanalyzer/turnover/widgets/turnover_filter_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TurnoversRoute extends GoRouteData with $TurnoversRoute {
  const TurnoversRoute({
    this.filter,
    this.sort,
  });

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

  Future<void> _openFilterEditor() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TurnoverFilterEditorDialog(
        initialFilter: _filter,
        initialSort: _sort,
      ),
    );

    if (result != null) {
      setState(() {
        _filter = result['filter'] as TurnoverFilter;
        _sort = result['sort'] as TurnoverSort;
      });
      await _refresh();
    }
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
              icon: const Icon(Icons.filter_list),
              onPressed: _openFilterEditor,
              tooltip: 'Filter & Sort',
            ),
          ],
        ),
        body: Column(
          children: [
            if (_filter.hasFilters || _sort != TurnoverSort.defaultSort)
              _buildFilterChips(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Sort indicator chip (not deletable, shows current sort)
          if (_sort != TurnoverSort.defaultSort)
            Chip(
              avatar: Icon(
                _sort.direction == SortDirection.asc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 18,
              ),
              label: Text(_getSortFieldName(_sort.orderBy)),
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

          // Month/Year filter chip
          if (_filter.year != null && _filter.month != null)
            Chip(
              label: Text('${_getMonthName(_filter.month!)} ${_filter.year}'),
              onDeleted: () {
                setState(() {
                  _filter = _filter.copyWith(year: null, month: null);
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
                  final tagName = snapshot.data?.name ?? tagId.substring(0, 8);
                  return Chip(
                    label: Text(tagName),
                    onDeleted: () {
                      setState(() {
                        final updatedTagIds = List<String>.from(
                          _filter.tagIds ?? [],
                        )..remove(tagId);
                        _filter = _filter.copyWith(
                          tagIds: updatedTagIds.isEmpty ? null : updatedTagIds,
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
    );
  }

  String _getSortFieldName(SortField field) {
    return switch (field) {
      SortField.bookingDate => 'Date',
      SortField.amount => 'Amount',
      SortField.counterPart => 'Counter Party',
    };
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

  Widget _buildBody() {
    // Show error on first page
    if (_items.isEmpty && _error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
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
            child: Center(
              child: CircularProgressIndicator(),
            ),
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
