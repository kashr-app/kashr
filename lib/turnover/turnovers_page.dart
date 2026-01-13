import 'dart:async';

import 'package:collection/collection.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/core/associate_by.dart';
import 'package:kashr/core/map_values.dart';
import 'package:kashr/app_gate.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/turnover/model/tag_turnover_change.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_change.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/model/turnover_sort.dart';
import 'package:kashr/turnover/model/turnover_with_tag_turnovers.dart';
import 'package:kashr/turnover/services/transfer_service.dart';
import 'package:kashr/turnover/services/turnover_service.dart';
import 'package:kashr/turnover/turnover_tags_page.dart';
import 'package:kashr/turnover/widgets/batch_tag_dialog.dart';
import 'package:kashr/turnover/widgets/turnover_filter_dialog.dart';
import 'package:kashr/turnover/widgets/search_dialog.dart';
import 'package:kashr/turnover/widgets/turnover_sort_dialog.dart';
import 'package:kashr/turnover/widgets/turnovers_filter_chips.dart';
import 'package:kashr/turnover/widgets/turnovers_list_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/uuid_value.dart';

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
  final _scrollController = ScrollController();
  final Map<UuidValue, TurnoverWithTagTurnovers> _itemsByTurnoverId = {};
  final Map<UuidValue, TransferWithDetails> _transferByTagTurnoverId = {};
  final Map<UuidValue, DateTime> _openingBalanceDatesByAccountId = {};

  static const _pageSize = 10;
  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  late TurnoverFilter _filter;
  late TurnoverSort _sort;

  final Set<UuidValue> _selectedTurnoverIds = {};
  bool get _isBatchMode => _selectedTurnoverIds.isNotEmpty;

  late final TurnoverRepository _repository;
  late final TagTurnoverRepository _tagTurnoverRepository;
  late final TransferService _transferService;
  late final TurnoverService _turnoverService;

  StreamSubscription<TagTurnoverChange>? _tagTurnoverSubscription;
  StreamSubscription<TurnoverChange>? _turnoverSubscription;

  late final Logger _log;

  @override
  void initState() {
    super.initState();
    _log = context.read<LogService>().log;

    _repository = context.read<TurnoverRepository>();
    _tagTurnoverRepository = context.read<TagTurnoverRepository>();
    _transferService = context.read<TransferService>();
    _turnoverService = context.read<TurnoverService>();

    _tagTurnoverSubscription = _tagTurnoverRepository.watchChanges().listen(
      _onTagTurnoverChanged,
    );

    _filter = widget.initialFilter;
    _sort = widget.initialSort;
    _scrollController.addListener(_onScroll);

    _turnoverSubscription = _repository.watchChanges().listen(
      _onTurnoverChange,
    );

    _getOpeningBalanceDates();

    _loadMore();
  }

  void _onTurnoverChange(TurnoverChange change) async {
    final List<Turnover> upsertedTurnovers = [];

    switch (change) {
      case TurnoversInserted(:final turnovers):
        upsertedTurnovers.addAll(turnovers);
      case TurnoversUpdated(:final turnovers):
        upsertedTurnovers.addAll(turnovers);
      case TurnoversDeleted(:final ids):
        setState(() {
          for (final id in ids) {
            _itemsByTurnoverId.remove(id);
          }
        });
    }

    if (upsertedTurnovers.isNotEmpty) {
      final turnoversWithTT = await _turnoverService.getTurnoversWithTags(
        upsertedTurnovers,
      );

      setState(() {
        for (final it in turnoversWithTT) {
          _itemsByTurnoverId[it.turnover.id] = it;
        }
      });

      // refresh opening balances dates if needed
      final anyBeforeOpeningBalance = upsertedTurnovers.any((it) {
        final bookingDate = it.bookingDate;
        if (bookingDate == null) return false;
        final openingDate = _openingBalanceDatesByAccountId[it.accountId];
        if (openingDate == null) return false;
        return !openingDate.isBefore(bookingDate);
      });
      if (anyBeforeOpeningBalance) {
        await _getOpeningBalanceDates();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tagTurnoverSubscription?.cancel();
    _turnoverSubscription?.cancel();
    super.dispose();
  }

  void _onTagTurnoverChanged(TagTurnoverChange change) {
    switch (change) {
      case TagTurnoversInserted(:final tagTurnovers):
        final updated = <UuidValue, TurnoverWithTagTurnovers>{};
        for (final tt in tagTurnovers) {
          final turnoverId = tt.turnoverId;
          if (turnoverId == null) continue;
          final t = _itemsByTurnoverId[turnoverId];
          if (t != null) {
            final c = t.copyWith(tagTurnovers: [...t.tagTurnovers, tt]);
            updated[turnoverId] = c;
          }
        }
        setState(() {
          _itemsByTurnoverId.addAll(updated);
        });
      case TagTurnoversUpdated(:final tagTurnovers):
        final updated = <UuidValue, TurnoverWithTagTurnovers>{};
        for (final tt in tagTurnovers) {
          final turnoverId = tt.turnoverId;
          if (turnoverId == null) {
            // the tt was unallocated from its turnover
            // find the former turnover
            final toUpdate = _itemsByTurnoverId.values.firstWhereOrNull(
              (it) => it.tagTurnovers.any((it2) => it2.id == tt.id),
            );
            if (toUpdate != null) {
              // remove the tt
              updated[toUpdate.turnover.id] = toUpdate.copyWith(
                tagTurnovers: toUpdate.tagTurnovers
                    .whereNot((it) => it.id == tt.id)
                    .toList(),
              );
            }
          } else {
            final t = _itemsByTurnoverId[turnoverId];
            if (t != null) {
              // the tt can be either already in the map or newly allocated
              var isNew = true;
              final c = t.copyWith(
                tagTurnovers:
                    t.tagTurnovers.map((it) {
                        if (it.id == tt.id) {
                          isNew = false;
                          return tt;
                        } else {
                          return it;
                        }
                      }).toList()
                      // if new, append
                      ..addAll([if (isNew) tt]),
              );
              updated[turnoverId] = c;
            }
          }
        }
        setState(() {
          _itemsByTurnoverId.addAll(updated);
        });
      case TagTurnoversDeleted(:final ids):
        final updated = _itemsByTurnoverId.mapValues(
          (turnoverId, it) => it.copyWith(
            tagTurnovers: it.tagTurnovers
                .whereNot((tt) => ids.contains(tt.id))
                .toList(),
          ),
        );
        setState(() {
          _itemsByTurnoverId.addAll(updated);
        });
    }
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
      final newItems = await _repository.getTurnoversPaginated(
        limit: _pageSize,
        offset: _currentOffset,
        filter: _filter,
        sort: _sort,
      );

      final turnoversWithTT = await _turnoverService.getTurnoversWithTags(
        newItems,
      );

      // Fetch transfer information for new items
      await _loadTransfersForItems(turnoversWithTT);

      setState(() {
        _itemsByTurnoverId.addAll(
          turnoversWithTT.associateBy((it) => it.turnover.id),
        );
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

  /// Updates opening balance dates for all accounts (or filtered accounts).
  Future<void> _getOpeningBalanceDates() async {
    try {
      final accountCubit = context.read<AccountCubit>();
      final accountState = accountCubit.state;

      // Determine which accounts to fetch the opening balances for
      final Iterable<UuidValue> accountIds;
      if (_filter.accountIds?.isNotEmpty == true) {
        accountIds = _filter.accountIds!;
      } else {
        accountIds = accountState.accountById.keys;
      }

      if (accountIds.isEmpty) return;

      final dates = await accountCubit.getOpeningBalanceDates(accountIds);

      _openingBalanceDatesByAccountId.addAll(dates);
    } catch (error, stackTrace) {
      _log.e(
        'Error updating opening balance dates',
        error: error,
        stackTrace: stackTrace,
      );
      // Don't fail the whole operation if this fails
    }
  }

  /// Loads transfer information for tag turnovers within the given turnovers.
  Future<void> _loadTransfersForItems(
    List<TurnoverWithTagTurnovers> items,
  ) async {
    try {
      // Collect all tag turnover IDs from the turnovers
      final tagTurnoverIds = <UuidValue>[];
      for (final turnoverWithTT in items) {
        for (final tagTurnover in turnoverWithTT.tagTurnovers) {
          tagTurnoverIds.add(tagTurnover.id);
        }
      }

      if (tagTurnoverIds.isEmpty) return;

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
        'Error loading transfers for turnovers',
        error: error,
        stackTrace: stackTrace,
      );
      // Don't fail the whole operation if transfer loading fails
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _itemsByTurnoverId.clear();
      _transferByTagTurnoverId.clear();
      _openingBalanceDatesByAccountId.clear();
      _currentOffset = 0;
      _hasMore = true;
      _error = null;
    });
    await _getOpeningBalanceDates();
    await _loadMore();
  }

  void _updateFilter(TurnoverFilter newFilter) {
    setState(() => _filter = newFilter);
    unawaited(_refresh());
  }

  void _updateSort(TurnoverSort sort) {
    setState(() {
      _sort = sort;
    });
    unawaited(_refresh());
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
      unawaited(_refresh());
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

  void _toggleTurnoverSelection(UuidValue turnoverId) {
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

  List<TurnoverWithTagTurnovers> get _selectedTurnovers => _selectedTurnoverIds
      .map((id) => _itemsByTurnoverId[id])
      .nonNulls
      .toList();

  Future<void> _batchAddTag() async {
    if (_selectedTurnoverIds.isEmpty) return;

    final result = await BatchTagDialog.show(
      context,
      affectedTurnoversCount: _selectedTurnoverIds.length,
      mode: BatchTagMode.add,
    );

    if (result == null || !mounted) return;
    await _applyBatchTagOperation(result);
  }

  Future<void> _batchRemoveTag() async {
    if (_selectedTurnoverIds.isEmpty) return;

    final tagIds = <UuidValue>[];
    for (final turnoverWithTags in _selectedTurnovers) {
      for (final tagTurnover in turnoverWithTags.tagTurnovers) {
        tagIds.add(tagTurnover.tagId);
      }
    }

    if (tagIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tags found on selected turnovers')),
      );
      return;
    }
    if (!mounted) return;

    final result = await BatchTagDialog.show(
      context,
      affectedTurnoversCount: _selectedTurnoverIds.length,
      filter: (tag) => tagIds.contains(tag.id),
      mode: BatchTagMode.remove,
    );

    if (result == null || !mounted) return;
    await _applyBatchTagOperation(result);
  }

  Future<void> _applyBatchTagOperation(BatchTagResult result) async {
    final turnovers = _selectedTurnovers.map((t) => t.turnover).toList();
    final turnoverIds = turnovers.map((it) => it.id).toList();
    final tag = result.tag;
    final isAdd = result.mode == BatchTagMode.add;

    int affected = 0;

    try {
      if (isAdd) {
        affected = await _tagTurnoverRepository.batchAddTagToTurnovers(
          turnovers,
          tag.id,
        );
      } else {
        if (result.deleteTaggings) {
          affected = await _tagTurnoverRepository.batchDeleteByTurnoverInAndTag(
            turnoverIds,
            tag.id,
          );
        } else {
          affected = await _tagTurnoverRepository
              .batchUnallocateByTurnoverInAndTag(turnoverIds, tag.id);
        }
      }

      _clearSelection();
      await _refresh();

      if (mounted) {
        final action = isAdd
            ? 'Added'
            : (result.deleteTaggings ? 'Deleted' : 'Unallocated');
        final preposition = isAdd ? 'to' : 'from';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$action tag "${tag.name}" $preposition '
              '$affected turnover${affected == 1 ? '' : 's'}',
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

  void _handleItemTap(TurnoverWithTagTurnovers item) async {
    final id = item.turnover.id;

    if (_isBatchMode) {
      _toggleTurnoverSelection(id);
    } else {
      await TurnoverTagsRoute(turnoverId: id.uuid).push(context);
    }
  }

  void _handleItemLongPress(TurnoverWithTagTurnovers item) {
    final id = item.turnover.id;
    _toggleTurnoverSelection(id);
  }

  /// Builds the combined list of turnovers and opening balance cards.
  ///
  /// Opening balance cards are injected based on the current sort field:
  /// - bookingDate: injected chronologically by opening balance date
  /// - amount: injected by comparing opening balance amount
  /// - counterPart: injected alphabetically treating "Opening Balance" as counterpart
  List<TurnoversListItem> _buildCombinedList(
    Iterable<TurnoverWithTagTurnovers> turnovers,
    AccountState accountState,
    TurnoverSort sort,
    TurnoverFilter filter,
  ) {
    // We only display/inject account opening balances when ordering
    // by bookingDate and not having any filters but accounts
    if (sort.orderBy != SortField.bookingDate ||
        filter.hideAccountOpeningBalances) {
      return turnovers.map((it) => TurnoverListItem(it)).toList();
    }

    final accountIds = accountState.accountById.keys.toSet();
    final accountsToRenderOpeningBalanceFor = filter.period == null
        ? accountIds
        : accountIds.where((accountId) {
            final balanceDate = _openingBalanceDatesByAccountId[accountId];
            return balanceDate != null && filter.period!.contains(balanceDate);
          }).toSet();

    final result = <TurnoversListItem>[];
    for (final turnover in turnovers) {
      // check if we should inject any opening balance before this turnover
      final rendered = <UuidValue>{};
      for (final accountId in accountsToRenderOpeningBalanceFor) {
        final balanceDate = _openingBalanceDatesByAccountId[accountId];
        final bookingDate = turnover.turnover.bookingDate;

        if (balanceDate != null &&
            bookingDate != null &&
            (sort.direction == SortDirection.desc
                ? bookingDate.isBefore(balanceDate)
                : bookingDate.isAfter(balanceDate))) {
          result.add(OpeningBalanceListItem(accountId, balanceDate));
          rendered.add(accountId);
        }
      }
      if (rendered.isNotEmpty) {
        accountsToRenderOpeningBalanceFor.removeAll(rendered);
      }

      result.add(TurnoverListItem(turnover));
    }

    // Add remaining opening balances that weren't injected yet at the end
    for (final accountId in accountsToRenderOpeningBalanceFor) {
      final openingBalanceDate = _openingBalanceDatesByAccountId[accountId];
      if (openingBalanceDate != null) {
        result.add(OpeningBalanceListItem(accountId, openingBalanceDate));
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final showFilterChips =
        _filter.hasFilters || _sort != TurnoverSort.defaultSort;

    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, accountState) {
        final combinedItems = _buildCombinedList(
          _itemsByTurnoverId.values,
          accountState,
          _sort,
          _filter,
        );

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
                    onSortChanged: _updateSort,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: TurnoversListContent(
                      items: combinedItems,
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
                      transferByTagTurnoverId: _transferByTagTurnoverId,
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

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('Turnovers'),
      elevation: 0,
      actions: [
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
