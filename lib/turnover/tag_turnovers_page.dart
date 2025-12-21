import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/turnover/dialogs/tag_turnover_editor_dialog.dart';
import 'package:finanalyzer/turnover/dialogs/tag_turnover_info_dialog.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_sort.dart';
import 'package:finanalyzer/turnover/model/tag_turnovers_filter.dart';
import 'package:finanalyzer/turnover/model/transfer_repository.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/services/transfer_service.dart';
import 'package:finanalyzer/turnover/transfer_editor_page.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/widgets/source_card.dart';
import 'package:finanalyzer/turnover/widgets/tag_turnovers_filter_chips.dart';
import 'package:finanalyzer/turnover/widgets/tag_turnovers_filter_dialog.dart';
import 'package:finanalyzer/turnover/widgets/tag_turnovers_list_content.dart';
import 'package:finanalyzer/turnover/widgets/tag_turnovers_sort_dialog.dart';
import 'package:finanalyzer/turnover/widgets/search_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TagTurnoversRoute extends GoRouteData with $TagTurnoversRoute {
  const TagTurnoversRoute({this.filter, this.sort});

  final TagTurnoversFilter? filter;
  final TagTurnoverSort? sort;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TagTurnoversPage(
      initialFilter: filter ?? TagTurnoversFilter.empty,
      initialSort: sort ?? TagTurnoverSort.defaultSort,
    );
  }
}

class TagTurnoversPage extends StatefulWidget {
  const TagTurnoversPage({
    this.initialFilter = TagTurnoversFilter.empty,
    this.initialSort = TagTurnoverSort.defaultSort,
    this.forSelection = false,
    this.allowMultipleSelection = false,
    this.lockedFilters = TagTurnoversFilter.empty,
    super.key,
    this.header,
  });

  final TagTurnoversFilter initialFilter;
  final TagTurnoverSort initialSort;
  final bool forSelection;

  /// When in selection mode, allow selecting multiple items.
  /// If false, selecting an item immediately returns it.
  /// If true, user can select multiple items and confirm with a button.
  final bool allowMultipleSelection;

  /// Filters that cannot be cleared by the user.
  /// These filters are always applied and their chips won't show delete buttons.
  final TagTurnoversFilter lockedFilters;

  /// An additional header that will render at the top of the list.
  final Widget? header;

  /// Opens the page for single selection, returns the selected [TagTurnover]
  static Future<TagTurnover?> openForSelection({
    required BuildContext context,
    TagTurnoversFilter? filter,
    TagTurnoversFilter? lockedFilters,
    bool allowMultiple = false,
    Widget? header,
  }) async {
    return await Navigator.of(context).push<TagTurnover>(
      MaterialPageRoute(
        builder: (context) => TagTurnoversPage(
          header: header,
          initialFilter: filter ?? TagTurnoversFilter.empty,
          lockedFilters: lockedFilters ?? TagTurnoversFilter.empty,
          forSelection: true,
          allowMultipleSelection: allowMultiple,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<TagTurnoversPage> createState() => _TagTurnoversPageState();
}

class _TagTurnoversPageState extends State<TagTurnoversPage> {
  final _log = Logger();
  final _scrollController = ScrollController();
  final List<TagTurnover> _items = [];
  final Map<UuidValue, TransferWithDetails> _transferByTagTurnoverId = {};

  static const _pageSize = 10;
  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  late TagTurnoversFilter _filter;
  late TagTurnoverSort _sort;

  final Set<UuidValue> _selectedIds = {};

  /// Batch mode is active when:
  /// - Items are selected AND we're not in selection mode, OR
  /// - We're in multi-selection mode (regardless of whether items are selected)
  bool get _isBatchMode =>
      (_selectedIds.isNotEmpty && !widget.forSelection) ||
      (widget.forSelection && widget.allowMultipleSelection);

  late final TagTurnoverRepository _repository;
  late final TransferService _transferService;

  @override
  void initState() {
    super.initState();
    _repository = context.read<TagTurnoverRepository>();
    _transferService = context.read<TransferService>();
    _filter = widget.initialFilter.lockWith(widget.lockedFilters);
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
      final newItems = await _repository.getTagTurnoversPaginated(
        limit: _pageSize,
        offset: _currentOffset,
        filter: _filter,
        sort: _sort,
      );

      // Fetch transfer information for new items
      await _loadTransfersForItems(newItems);

      setState(() {
        _items.addAll(newItems);
        _currentOffset += newItems.length;
        _hasMore = newItems.length >= _pageSize;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      _log.e(
        'Error fetching tag turnovers page',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  /// Loads transfer information for the given tag turnovers.
  Future<void> _loadTransfersForItems(List<TagTurnover> items) async {
    try {
      final tagTurnoverIds = items.map((item) => item.id).toList();

      // Get transfer IDs for these tag turnovers
      final transferRepository = context.read<TransferRepository>();
      final transferIdByTagTurnoverId = await transferRepository
          .getTransferIdsForTagTurnovers(tagTurnoverIds);

      if (transferIdByTagTurnoverId.isEmpty) return;

      // Fetch transfer details
      final transferIds = transferIdByTagTurnoverId.values.toSet().toList();
      final transfersWithDetails = await _transferService
          .getTransfersWithDetails(transferIds);

      // Map transfers back to tag turnover IDs
      for (final entry in transferIdByTagTurnoverId.entries) {
        final tagTurnoverId = entry.key;
        final transferId = entry.value;
        final transferDetails = transfersWithDetails[transferId];
        if (transferDetails != null) {
          _transferByTagTurnoverId[tagTurnoverId] = transferDetails;
        }
      }
    } catch (error, stackTrace) {
      _log.e(
        'Error loading transfers for tag turnovers',
        error: error,
        stackTrace: stackTrace,
      );
      // Don't fail the whole operation if transfer loading fails
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _transferByTagTurnoverId.clear();
      _currentOffset = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  void _updateFilter(TagTurnoversFilter newFilter) {
    setState(() => _filter = newFilter.lockWith(widget.lockedFilters));
    _refresh();
  }

  void _updateSort(TagTurnoverSort sort) {
    setState(() {
      _sort = sort;
    });
    _refresh();
  }

  Future<void> _openFilterDialog() async {
    final result = await showDialog<TagTurnoversFilter>(
      context: context,
      builder: (context) => TagTurnoversFilterDialog(
        initialFilter: _filter,
        lockedFilters: widget.lockedFilters,
      ),
    );
    if (result != null) _updateFilter(result);
  }

  Future<void> _openSortDialog() async {
    final result = await showDialog<TagTurnoverSort>(
      context: context,
      builder: (context) => TagTurnoversSortDialog(initialSort: _sort),
    );
    if (result != null) {
      setState(() => _sort = result);
      _refresh();
    }
  }

  Future<void> _openSearchDialog() async {
    final searchQuery = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const SearchDialog(),
        fullscreenDialog: true,
      ),
    );

    if (searchQuery != null && searchQuery.isNotEmpty) {
      _updateFilter(_filter.copyWith(searchQuery: searchQuery));
    }
  }

  void _toggleSelection(UuidValue id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag Turnovers'),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} tag turnovers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final idsToDelete = _selectedIds.toList();
      await _repository.deleteTagTurnoversBatch(idsToDelete);

      _clearSelection();
      await _refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${idsToDelete.length} tag turnovers'),
          ),
        );
      }
    } catch (error, stackTrace) {
      _log.e(
        'Error batch deleting tag turnovers',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting tag turnovers: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleItemSelect(TagTurnover item) async {
    final id = item.id;

    if (widget.forSelection) {
      // In single selection mode, immediately return the selected item
      if (!widget.allowMultipleSelection) {
        Navigator.of(context).pop(item);
        return;
      }

      // In multi-selection mode, toggle selection
      _toggleSelection(id);
      return;
    }

    if (_isBatchMode) {
      _toggleSelection(id);
    } else {
      _log.e(
        'Should not be able to select an item if neither in forSelection mode nor in batch mode',
      );
    }
  }

  Future<void> _handleItemTap(TagTurnover item) async {
    if (widget.forSelection) {
      await TagTurnoverInfoDialog.show(context, item);
      return;
    }
    // Open appropriate editor based on status
    if (item.isMatched) {
      // Navigate to TurnoverTagsPage for "done" items
      await TurnoverTagsRoute(turnoverId: item.turnoverId!.uuid).push(context);
      _refresh();
    } else {
      // Open EditPendingTagTurnoverDialog for "pending" items
      final result = await TagTurnoverEditorDialog.show(
        context,
        tagTurnover: item,
      );

      if (result == null || !mounted) return;

      if (result is EditTagTurnoverUpdated) {
        await _repository.updateTagTurnover(result.tagTurnover);
        _refresh();
      } else if (result is EditTagTurnoverDeleted) {
        await _repository.deleteTagTurnover(item.id);
        _refresh();
      }
    }
  }

  void _handleItemLongPress(TagTurnover item) {
    // Don't allow batch mode when opened for selection
    if (widget.forSelection) return;

    _toggleSelection(item.id);
  }

  Future<void> _handleTransferAction(
    TagTurnover item,
    TransferWithDetails? sourceTransfer,
  ) async {
    final transferDetails = _transferByTagTurnoverId[item.id];
    final tagRepository = context.read<TagRepository>();
    final tagById = await tagRepository.getByIdsCached();
    final tag = tagById[item.tagId];
    final isTransferTag = tag?.isTransfer ?? false;
    final isUnlinkedTransfer = isTransferTag && transferDetails == null;

    if (!mounted) return;

    if (transferDetails != null) {
      // Navigate to TransferEditorPage if transfer exists
      await TransferEditorRoute(
        transferId: transferDetails.transfer.id.uuid,
      ).push(context);
      if (mounted) _refresh();
    } else if (isUnlinkedTransfer) {
      // Determine the required sign for the counterpart
      final requiredSign = item.sign == TurnoverSign.expense
          ? TurnoverSign.income
          : TurnoverSign.expense;

      // Open TagTurnoversPage for selection with appropriate filters
      final selectedTagTurnover = await TagTurnoversPage.openForSelection(
        context: context,
        header: SourceCard(tagTurnover: item, tag: tag!),
        filter: TagTurnoversFilter(sign: requiredSign),
        lockedFilters: TagTurnoversFilter(
          transferTagOnly: true,
          unfinishedTransfersOnly: true,
          excludeTagTurnoverIds: [item.id],
        ),
      );

      if (mounted && selectedTagTurnover != null) {
        final transferService = context.read<TransferService>();

        // Create the transfer using the service
        final (transferId, conflict) = await transferService
            .linkTransferTagTurnovers(
              sourceTagTurnover: item,
              selectedTagTurnover: selectedTagTurnover,
              transfer: sourceTransfer?.transfer,
            );

        if (!mounted) return;
        await conflict?.showAsDialog(context);
        if (!mounted) return;

        if (transferId != null) {
          // Navigate to transfer editor page for review
          await TransferEditorRoute(transferId: transferId.uuid).push(context);
        }
        if (mounted) _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFilterChips =
        _filter.hasFilters || _sort != TagTurnoverSort.defaultSort;

    return Scaffold(
      appBar: _isBatchMode ? _buildBatchAppBar() : _buildNormalAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.header != null) widget.header!,
            if (showFilterChips)
              TagTurnoversFilterChips(
                filter: _filter,
                lockedFilters: widget.lockedFilters,
                sort: _sort,
                onFilterChanged: _updateFilter,
                onSortChanged: _updateSort,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: TagTurnoversListContent(
                  items: _items,
                  isLoading: _isLoading,
                  hasMore: _hasMore,
                  error: _error,
                  scrollController: _scrollController,
                  selectedIds: _selectedIds,
                  isBatchMode: _isBatchMode,
                  forSelection: widget.forSelection,
                  transferByTagTurnoverId: _transferByTagTurnoverId,
                  onItemTap: _handleItemTap,
                  onItemSelect: _handleItemSelect,
                  onItemLongPress: _handleItemLongPress,
                  onTransferAction: _handleTransferAction,
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
      title: Text(
        widget.forSelection
            ? (widget.allowMultipleSelection
                  ? 'Select Tag Turnovers'
                  : 'Select Tag Turnover')
            : 'Tag Turnovers',
      ),
      elevation: 0,
      actions: [
        // In multi-selection mode, show confirm button when items are selected
        if (widget.forSelection &&
            widget.allowMultipleSelection &&
            _selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // Return the first selected item (for single return type compatibility)
              final selectedItem = _items.firstWhere(
                (item) => _selectedIds.contains(item.id),
              );
              Navigator.of(context).pop(selectedItem);
            },
            tooltip: 'Confirm',
          ),
        if (widget.lockedFilters.searchQuery == null)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _openSearchDialog,
            tooltip: 'Search',
          ),
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: _openSortDialog,
          tooltip: 'Sort',
        ),
        IconButton(
          icon: Icon(
            _filter.hasFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
          ),
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
      title: Text('${_selectedIds.length} selected'),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: _batchDelete,
          tooltip: 'Delete',
        ),
      ],
    );
  }
}
