import 'dart:async';

import 'package:kashr/home/home_page.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/turnover/dialogs/tag_turnover_editor_dialog.dart';
import 'package:kashr/turnover/dialogs/tag_turnover_info_dialog.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/tag_turnover_sort.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/services/transfer_service.dart';
import 'package:kashr/turnover/tag_turnovers_cubit.dart';
import 'package:kashr/turnover/tag_turnovers_state.dart';
import 'package:kashr/turnover/transfer_editor_page.dart';
import 'package:kashr/turnover/turnover_tags_page.dart';
import 'package:kashr/turnover/widgets/source_card.dart';
import 'package:kashr/turnover/widgets/tag_turnovers_filter_chips.dart';
import 'package:kashr/turnover/widgets/tag_turnovers_filter_dialog.dart';
import 'package:kashr/turnover/widgets/tag_turnovers_list_content.dart';
import 'package:kashr/turnover/widgets/tag_turnovers_sort_dialog.dart';
import 'package:kashr/turnover/widgets/search_dialog.dart';
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

class TagTurnoversPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TagTurnoversCubit(
        context.read<TagTurnoverRepository>(),
        context.read<TransferRepository>(),
        context.read<TransferService>(),
        context.read<LogService>().log,
        initialFilter: initialFilter,
        initialSort: initialSort,
        lockedFilters: lockedFilters,
      ),
      child: _TagTurnoversPageContent(
        forSelection: forSelection,
        allowMultipleSelection: allowMultipleSelection,
        lockedFilters: lockedFilters,
        header: header,
      ),
    );
  }
}

class _TagTurnoversPageContent extends StatefulWidget {
  const _TagTurnoversPageContent({
    required this.forSelection,
    required this.allowMultipleSelection,
    required this.lockedFilters,
    this.header,
  });

  final bool forSelection;
  final bool allowMultipleSelection;
  final TagTurnoversFilter lockedFilters;
  final Widget? header;

  @override
  State<_TagTurnoversPageContent> createState() =>
      _TagTurnoversPageContentState();
}

class _TagTurnoversPageContentState extends State<_TagTurnoversPageContent> {
  late final Logger _log;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _log = context.read<LogService>().log;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final cubit = context.read<TagTurnoversCubit>();
    if (cubit.state.isLoading || !cubit.state.hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= 200) {
      cubit.loadMore();
    }
  }

  Future<void> _openFilterDialog(
    BuildContext context,
    TagTurnoversFilter currentFilter,
  ) async {
    final result = await showDialog<TagTurnoversFilter>(
      context: context,
      builder: (context) => TagTurnoversFilterDialog(
        initialFilter: currentFilter,
        lockedFilters: widget.lockedFilters,
      ),
    );
    if (result != null && context.mounted) {
      context.read<TagTurnoversCubit>().updateFilter(result);
    }
  }

  Future<void> _openSortDialog(
    BuildContext context,
    TagTurnoverSort currentSort,
  ) async {
    final result = await showDialog<TagTurnoverSort>(
      context: context,
      builder: (context) => TagTurnoversSortDialog(initialSort: currentSort),
    );
    if (result != null && context.mounted) {
      context.read<TagTurnoversCubit>().updateSort(result);
    }
  }

  Future<void> _openSearchDialog(
    BuildContext context,
    TagTurnoversFilter currentFilter,
  ) async {
    final searchQuery = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const SearchDialog(),
        fullscreenDialog: true,
      ),
    );

    if (searchQuery != null && searchQuery.isNotEmpty && context.mounted) {
      context.read<TagTurnoversCubit>().updateFilter(
        currentFilter.copyWith(searchQuery: searchQuery),
      );
    }
  }

  Future<void> _batchDelete(BuildContext context, int selectedCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag Turnovers'),
        content: Text(
          'Are you sure you want to delete $selectedCount tag turnovers?',
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

    if (confirmed != true || !context.mounted) return;

    final cubit = context.read<TagTurnoversCubit>();
    final success = await cubit.batchDelete();

    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $selectedCount tag turnovers')),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error deleting tag turnovers'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleItemSelect(BuildContext context, TagTurnover item) async {
    final id = item.id;

    if (widget.forSelection) {
      if (!widget.allowMultipleSelection) {
        Navigator.of(context).pop(item);
        return;
      }
      context.read<TagTurnoversCubit>().toggleSelection(id);
      return;
    }

    final cubit = context.read<TagTurnoversCubit>();
    final isBatchMode =
        cubit.state.selectedIds.isNotEmpty ||
        (widget.forSelection && widget.allowMultipleSelection);

    if (isBatchMode) {
      cubit.toggleSelection(id);
    } else {
      _log.e(
        'Should not be able to select an item if neither in forSelection mode nor in batch mode',
      );
    }
  }

  Future<void> _handleItemTap(BuildContext context, TagTurnover item) async {
    if (widget.forSelection) {
      await TagTurnoverInfoDialog.show(context, item);
      return;
    }

    if (item.isMatched) {
      await TurnoverTagsRoute(turnoverId: item.turnoverId!.uuid).push(context);
    } else {
      final result = await TagTurnoverEditorDialog.show(
        context,
        tagTurnover: item,
      );

      if (result == null || !context.mounted) return;

      final cubit = context.read<TagTurnoversCubit>();
      if (result is EditTagTurnoverUpdated) {
        await cubit.updateTagTurnover(result.tagTurnover);
      } else if (result is EditTagTurnoverDeleted) {
        await cubit.deleteTagTurnover(item.id);
      }
    }
  }

  void _handleItemLongPress(BuildContext context, TagTurnover item) {
    if (widget.forSelection) return;
    context.read<TagTurnoversCubit>().toggleSelection(item.id);
  }

  Future<void> _handleTransferAction(
    BuildContext context,
    TagTurnover item,
    TransferWithDetails? sourceTransfer,
    Map<UuidValue, TransferWithDetails> transferByTagTurnoverId,
  ) async {
    final transferDetails = transferByTagTurnoverId[item.id];
    final tagRepository = context.read<TagRepository>();

    final tagById = await tagRepository.getByIdsCached();
    if (!context.mounted) return;

    final tag = tagById[item.tagId];
    final isTransferTag = tag?.isTransfer ?? false;
    final isUnlinkedTransfer = isTransferTag && transferDetails == null;

    if (transferDetails != null) {
      await TransferEditorRoute(
        transferId: transferDetails.transfer.id.uuid,
      ).push(context);
    } else if (isUnlinkedTransfer) {
      final requiredSign = item.sign == TurnoverSign.expense
          ? TurnoverSign.income
          : TurnoverSign.expense;

      final selectedTagTurnover = await TagTurnoversPage.openForSelection(
        context: context,
        header: SourceCard(
          tagTurnover: item,
          tag: tag!,
          action: CreateOtherTransferSideButton(
            tagTurnover: item,
            tag: tag,
            onCreated: (context, created) => Navigator.pop(context, created),
          ),
        ),
        filter: TagTurnoversFilter(
          sign: requiredSign,
          // non-locked becaues the user might have not yet tagged the
          // opposing side as transfer
          transferTagOnly: true,
          unfinishedTransfersOnly: true,
        ),
        lockedFilters: TagTurnoversFilter(
          // do not allow selecting the same TagTurnover for both sides
          excludeTagTurnoverIds: [item.id],
        ),
      );

      if (context.mounted && selectedTagTurnover != null) {
        final transferService = context.read<TransferService>();

        final (transferId, conflict) = await transferService
            .linkTransferTagTurnovers(
              sourceTagTurnover: item,
              selectedTagTurnover: selectedTagTurnover,
              transfer: sourceTransfer?.transfer,
            );

        if (!context.mounted) return;
        await conflict?.showAsDialog(context);
        if (!context.mounted) return;

        if (transferId != null) {
          await TransferEditorRoute(transferId: transferId.uuid).push(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TagTurnoversCubit, TagTurnoversState>(
      builder: (context, state) {
        final isBatchMode =
            (state.selectedIds.isNotEmpty && !widget.forSelection) ||
            (widget.forSelection && widget.allowMultipleSelection);

        final showFilterChips =
            state.filter.hasFilters ||
            state.sort != TagTurnoverSort.defaultSort;

        return Scaffold(
          appBar: isBatchMode
              ? _buildBatchAppBar(context, state.selectedIds.length)
              : _buildNormalAppBar(context, state),
          body: SafeArea(
            child: Column(
              children: [
                if (widget.header != null) widget.header!,
                if (showFilterChips)
                  TagTurnoversFilterChips(
                    filter: state.filter,
                    lockedFilters: widget.lockedFilters,
                    sort: state.sort,
                    onFilterChanged: (filter) =>
                        context.read<TagTurnoversCubit>().updateFilter(filter),
                    onSortChanged: (sort) =>
                        context.read<TagTurnoversCubit>().updateSort(sort),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        context.read<TagTurnoversCubit>().refresh(),
                    child: TagTurnoversListContent(
                      items: state.itemById.values.toList(),
                      isLoading: state.isLoading,
                      hasMore: state.hasMore,
                      error: state.error,
                      scrollController: _scrollController,
                      selectedIds: state.selectedIds,
                      isBatchMode: isBatchMode,
                      forSelection: widget.forSelection,
                      transferByTagTurnoverId: state.transferByTagTurnoverId,
                      onItemTap: (item) => _handleItemTap(context, item),
                      onItemSelect: (item) => _handleItemSelect(context, item),
                      onItemLongPress: (item) =>
                          _handleItemLongPress(context, item),
                      onTransferAction: (item, sourceTransfer) =>
                          _handleTransferAction(
                            context,
                            item,
                            sourceTransfer,
                            state.transferByTagTurnoverId,
                          ),
                      onRetry: () =>
                          context.read<TagTurnoversCubit>().refresh(),
                      onLoadMore: () =>
                          context.read<TagTurnoversCubit>().loadMore(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildNormalAppBar(BuildContext context, TagTurnoversState state) {
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
        if (widget.forSelection &&
            widget.allowMultipleSelection &&
            state.selectedIds.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              final selectedItem = state.itemById.keys.firstWhere(
                (id) => state.selectedIds.contains(id),
              );
              Navigator.of(context).pop(selectedItem);
            },
            tooltip: 'Confirm',
          ),
        if (widget.lockedFilters.searchQuery == null)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _openSearchDialog(context, state.filter),
            tooltip: 'Search',
          ),
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () => _openSortDialog(context, state.sort),
          tooltip: 'Sort',
        ),
        IconButton(
          icon: Icon(
            state.filter.hasFilters
                ? Icons.filter_alt
                : Icons.filter_alt_outlined,
          ),
          onPressed: () => _openFilterDialog(context, state.filter),
          tooltip: 'Filter',
        ),
      ],
    );
  }

  AppBar _buildBatchAppBar(BuildContext context, int selectedCount) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => context.read<TagTurnoversCubit>().clearSelection(),
        tooltip: 'Cancel selection',
      ),
      title: Text('$selectedCount selected'),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _batchDelete(context, selectedCount),
          tooltip: 'Delete',
        ),
      ],
    );
  }
}
