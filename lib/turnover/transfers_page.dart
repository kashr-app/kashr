import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/logging/services/log_service.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/cubit/transfers_cubit.dart';
import 'package:finanalyzer/turnover/cubit/transfers_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnovers_filter.dart';
import 'package:finanalyzer/turnover/model/transfer_repository.dart';
import 'package:finanalyzer/turnover/model/transfer_item.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:finanalyzer/turnover/model/transfers_filter.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/services/transfer_service.dart';
import 'package:finanalyzer/turnover/tag_turnovers_page.dart';
import 'package:finanalyzer/turnover/transfer_editor_page.dart';
import 'package:finanalyzer/turnover/widgets/source_card.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:finanalyzer/turnover/widgets/transfer_issue_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TransfersRoute extends GoRouteData with $TransfersRoute {
  const TransfersRoute({this.filters, this.lockedFilters});

  final TransfersFilter? filters;
  final TransfersFilter? lockedFilters;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return BlocProvider(
      create: (context) => TransfersCubit(
        context.read<TransferRepository>(),
        context.read<TransferService>(),
        context.read<LogService>().log,
        initialFilter: filters ?? TransfersFilter.empty,
        lockedFilters: lockedFilters ?? TransfersFilter.empty,
      ),
      child: const TransfersPage(),
    );
  }
}

class TransfersPage extends StatefulWidget {
  const TransfersPage({super.key});

  @override
  State<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends State<TransfersPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isNearBottom) {
      context.read<TransfersCubit>().loadMoreTransfers();
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransfersCubit, TransfersState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Transfers'),
            actions: [
              IconButton(
                icon: Icon(
                  state.filter.hasFilters
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                ),
                onPressed: () {
                  final cubit = context.read<TransfersCubit>();
                  cubit.updateFilter(
                    state.filter.copyWith(
                      needsReviewOnly: !state.filter.needsReviewOnly,
                    ),
                  );
                },
                tooltip: state.filter.needsReviewOnly
                    ? 'Show all transfers'
                    : 'Show only needs review',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (state.filter.needsReviewOnly)
                        Chip(
                          label: const Text('Needs Review'),
                          avatar: Icon(
                            state.lockedFilters.needsReviewOnly
                                ? Icons.lock
                                : Icons.warning_amber_outlined,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _buildContent(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, TransfersState state) {
    switch (state.status) {
      case Status.loading:
        return const Center(child: CircularProgressIndicator());
      case Status.error || Status.initial:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load transfers',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.read<TransfersCubit>().loadTransfers(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case Status.success:
        final items = state.transferItemsById.values.toList();
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  state.filter.needsReviewOnly
                      ? Icons.check_circle_outline
                      : Icons.swap_horiz,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  state.filter.needsReviewOnly
                      ? 'All transfers are reviewed!'
                      : 'No transfers found',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          itemCount: items.length + (state.isLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final item = items[index];
            return _TransferItemWidget(key: ValueKey(item.id), item: item);
          },
        );
    }
  }
}

/// Widget dispatcher that renders the appropriate card based on review item type.
class _TransferItemWidget extends StatelessWidget {
  final TransferItem item;

  const _TransferItemWidget({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return item.when(
      withTransfer: (transferDetails) =>
          _InvalidTransferCard(transferDetails: transferDetails),
      unlinkedFromTransfer: (tagTurnover, tag) =>
          _UnlinkedFromTransferCard(tagTurnover: tagTurnover, tag: tag),
    );
  }
}

/// Card for displaying an invalid Transfer entity.
class _InvalidTransferCard extends StatelessWidget {
  final TransferWithDetails transferDetails;

  const _InvalidTransferCard({required this.transferDetails});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewReason = transferDetails.needsReview;
    final fromTT = transferDetails.fromTagTurnover;
    final toTT = transferDetails.toTagTurnover;

    return Card(
      child: InkWell(
        onTap: () {
          TransferEditorRoute(
            transferId: transferDetails.transfer.id.uuid,
          ).go(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: BlocBuilder<TagCubit, TagState>(
            builder: (context, tagState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Review reason badge
                  if (reviewReason != null)
                    TransferBadge.needsReviewDetailed(reviewReason),
                  const SizedBox(height: 12),

                  // From side
                  _buildSide(
                    context,
                    label: 'FROM',
                    tagTurnover: fromTT,
                    tag: tagState.tagById[fromTT?.tagId],
                  ),

                  const SizedBox(height: 8),
                  Center(
                    child: Icon(
                      Icons.arrow_downward,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // To side
                  _buildSide(
                    context,
                    label: 'TO',
                    tagTurnover: toTT,
                    tag: tagState.tagById[toTT?.tagId],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSide(
    BuildContext context, {
    required String label,
    required TagTurnover? tagTurnover,
    required Tag? tag,
  }) {
    final theme = Theme.of(context);

    if (tagTurnover == null) {
      return Row(
        children: [
          Text(
            '$label:',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Missing',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy');

    return Row(
      children: [
        Text(
          '$label:',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        if (tag != null) ...[
          TagAvatar(tag: tag, radius: 12),
          const SizedBox(width: 8),
          Text(tag.name, style: theme.textTheme.bodyMedium),
        ] else
          Text(
            'Unknown Tag',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              tagTurnover.format(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              dateFormat.format(tagTurnover.bookingDate),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card for displaying an unlinked tagTurnover that needs to be linked to a Transfer.
class _UnlinkedFromTransferCard extends StatelessWidget {
  final TagTurnover tagTurnover;
  final Tag tag;

  const _UnlinkedFromTransferCard({
    required this.tagTurnover,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      child: InkWell(
        onTap: () async {
          // Determine the required sign for the counterpart
          final requiredSign = tagTurnover.sign == TurnoverSign.expense
              ? TurnoverSign.income
              : TurnoverSign.expense;

          // Open TagTurnoversPage for selection with appropriate filters
          final selectedTagTurnover = await TagTurnoversPage.openForSelection(
            context: context,
            header: SourceCard(tagTurnover: tagTurnover, tag: tag),
            filter: TagTurnoversFilter(sign: requiredSign),
            lockedFilters: TagTurnoversFilter(
              transferTagOnly: true,
              unfinishedTransfersOnly: true,
              excludeTagTurnoverIds: [tagTurnover.id],
            ),
          );

          if (context.mounted && selectedTagTurnover != null) {
            final transferService = context.read<TransferService>();

            // Create the transfer using the service
            final (transferId, conflict) = await transferService
                .linkTransferTagTurnovers(
                  sourceTagTurnover: tagTurnover,
                  selectedTagTurnover: selectedTagTurnover,
                );

            if (!context.mounted) return;
            await conflict?.showAsDialog(context);
            if (!context.mounted) return;

            if (transferId != null) {
              // Navigate to transfer editor page for review
              TransferEditorRoute(transferId: transferId.uuid).go(context);
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TransferBadge.unlinked(),
              const SizedBox(height: 12),

              // Single side display
              Row(
                children: [
                  TagAvatar(tag: tag, radius: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Tap to link',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tagTurnover.format(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        dateFormat.format(tagTurnover.bookingDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
