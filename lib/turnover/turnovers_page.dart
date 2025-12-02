import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/widgets/batch_tag_dialog.dart';
import 'package:finanalyzer/turnover/widgets/turnover_filter_dialog.dart';
import 'package:finanalyzer/turnover/widgets/turnover_sort_dialog.dart';
import 'package:finanalyzer/turnover/widgets/turnovers_filter_chips.dart';
import 'package:finanalyzer/turnover/widgets/turnovers_list_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

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
  final _log = Logger();
  final _scrollController = ScrollController();
  final List<TurnoverWithTags> _items = [];

  static const _pageSize = 10;
  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  late TurnoverFilter _filter;
  late TurnoverSort _sort;

  final Set<String> _selectedTurnoverIds = {};
  bool get _isBatchMode => _selectedTurnoverIds.isNotEmpty;

  late final TurnoverRepository _repository;
  late final TagTurnoverRepository _tagTurnoverRepository;

  @override
  void initState() {
    super.initState();
    _repository = context.read<TurnoverRepository>();
    _tagTurnoverRepository = context.read<TagTurnoverRepository>();
    _filter = widget.initialFilter;
    _sort = widget.initialSort;
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

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
      _log.e(
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

  void _updateFilter(TurnoverFilter newFilter) {
    setState(() => _filter = newFilter);
    _refresh();
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

  Future<void> _openFilterDialog() async {
    final result = await showDialog<TurnoverFilter>(
      context: context,
      builder: (context) => TurnoverFilterDialog(initialFilter: _filter),
    );
    if (result != null) _updateFilter(result);
  }

  Future<void> _openSortDialog() async {
    final result = await showDialog<TurnoverSort>(
      context: context,
      builder: (context) => TurnoverSortDialog(initialSort: _sort),
    );
    if (result != null) {
      setState(() => _sort = result);
      _refresh();
    }
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
    setState(() => _selectedTurnoverIds.clear());
  }

  List<TurnoverWithTags> get _selectedTurnovers => _items
      .where((item) => _selectedTurnoverIds.contains(item.turnover.id.uuid))
      .toList();

  Future<void> _batchAddTag() async {
    if (_selectedTurnoverIds.isEmpty) return;

    final allTags = await context.read<TagRepository>().getAllTags();
    if (!mounted) return;

    final selectedTag = await showDialog<Tag>(
      context: context,
      builder: (context) =>
          BatchTagDialog(availableTags: allTags, mode: BatchTagMode.add),
    );

    if (selectedTag == null || !mounted) return;
    await _applyBatchTagOperation(selectedTag, isAdd: true);
  }

  Future<void> _batchRemoveTag() async {
    if (_selectedTurnoverIds.isEmpty) return;

    final tagsMap = <String, Tag>{};
    for (final turnoverWithTags in _selectedTurnovers) {
      for (final tagTurnover in turnoverWithTags.tagTurnovers) {
        final tag = tagTurnover.tag;
        if (tag.id != null) {
          tagsMap[tag.id!.uuid] = tag;
        }
      }
    }

    if (tagsMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tags found on selected turnovers')),
      );
      return;
    }

    if (!mounted) return;

    final selectedTag = await showDialog<Tag>(
      context: context,
      builder: (context) => BatchTagDialog(
        availableTags: tagsMap.values.toList(),
        mode: BatchTagMode.remove,
      ),
    );

    if (selectedTag == null || !mounted) return;
    await _applyBatchTagOperation(selectedTag, isAdd: false);
  }

  Future<void> _applyBatchTagOperation(Tag tag, {required bool isAdd}) async {
    final turnovers = _selectedTurnovers.map((t) => t.turnover).toList();

    try {
      if (isAdd) {
        await _tagTurnoverRepository.batchAddTagToTurnovers(turnovers, tag);
      } else {
        await _tagTurnoverRepository.batchRemoveTagFromTurnovers(
          turnovers,
          tag,
        );
      }

      _clearSelection();
      await _refresh();

      if (mounted) {
        final action = isAdd ? 'Added' : 'Removed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$action tag "${tag.name}" ${isAdd ? 'to' : 'from'} '
              '${turnovers.length} turnovers',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      _log.e(
        'Error batch ${isAdd ? 'adding' : 'removing'} tag',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${isAdd ? 'adding' : 'removing'} tag: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleItemTap(TurnoverWithTags item) async {
    final id = item.turnover.id;

    if (_isBatchMode) {
      _toggleTurnoverSelection(id.uuid);
    } else {
      await TurnoverTagsRoute(turnoverId: id.uuid).push(context);
      _refresh();
    }
  }

  void _handleItemLongPress(TurnoverWithTags item) {
    final id = item.turnover.id;
    _toggleTurnoverSelection(id.uuid);
  }

  @override
  Widget build(BuildContext context) {
    final showFilterChips =
        _filter.hasFilters || _sort != TurnoverSort.defaultSort;

    return Scaffold(
      appBar: _isBatchMode ? _buildBatchAppBar() : _buildNormalAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (showFilterChips)
              TurnoversFilterChips(
                filter: _filter,
                sort: _sort,
                onFilterChanged: _updateFilter,
                onSortDirectionToggled: _toggleSortDirection,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: TurnoversListContent(
                  items: _items,
                  isLoading: _isLoading,
                  hasMore: _hasMore,
                  error: _error,
                  scrollController: _scrollController,
                  selectedIds: _selectedTurnoverIds,
                  isBatchMode: _isBatchMode,
                  onItemTap: _handleItemTap,
                  onItemLongPress: _handleItemLongPress,
                  onRetry: _refresh,
                  onLoadMore: _loadMore,
                ),
              ),
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
}
