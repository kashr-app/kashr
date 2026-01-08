import 'package:kashr/turnover/widgets/opening_balance_card.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/model/turnover_with_tag_turnovers.dart';
import 'package:kashr/turnover/widgets/turnover_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid_value.dart';

/// Base class for items in the turnovers list.
sealed class TurnoversListItem {}

/// A regular turnover item to display.
final class TurnoverListItem extends TurnoversListItem {
  final TurnoverWithTagTurnovers data;

  TurnoverListItem(this.data);
}

/// An opening balance card for a specific account.
final class OpeningBalanceListItem extends TurnoversListItem {
  final UuidValue accountId;
  final DateTime openingBalanceDate;

  OpeningBalanceListItem(this.accountId, this.openingBalanceDate);
}

/// Displays the turnovers list content including error, empty, and list states.
class TurnoversListContent extends StatelessWidget {
  const TurnoversListContent({
    required this.items,
    required this.isLoading,
    required this.hasMore,
    required this.error,
    required this.scrollController,
    required this.selectedIds,
    required this.isBatchMode,
    required this.onItemTap,
    required this.onItemLongPress,
    required this.onRetry,
    required this.onLoadMore,
    this.transferByTagTurnoverId,
    super.key,
  });

  final List<TurnoversListItem> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final ScrollController scrollController;
  final Set<UuidValue> selectedIds;
  final bool isBatchMode;
  final void Function(TurnoverWithTagTurnovers) onItemTap;
  final void Function(TurnoverWithTagTurnovers) onItemLongPress;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final Map<UuidValue, TransferWithDetails>? transferByTagTurnoverId;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && error != null) {
      return _ErrorState(error: error!, onRetry: onRetry);
    }

    if (items.isEmpty && !isLoading) {
      return const _EmptyState();
    }

    return BlocBuilder<TagCubit, TagState>(
      builder: (context, tagState) {
        final tagById = tagState.tagById;
        // Add 1 for loading/error indicator if needed
        final itemCount =
            items.length + (hasMore || isLoading || error != null ? 1 : 0);

        return ListView.builder(
          controller: scrollController,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // Loading/error indicator at the end
            if (index >= items.length) {
              if (error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: onLoadMore,
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

            final item = items[index];

            return switch (item) {
              TurnoverListItem(:final data) => _buildTurnoverCard(
                context,
                data,
                tagById,
              ),
              OpeningBalanceListItem(
                :final accountId,
                :final openingBalanceDate,
              ) =>
                OpeningBalanceCard(
                  accountId: accountId,
                  openingBalanceDate: openingBalanceDate,
                ),
            };
          },
        );
      },
    );
  }

  Widget _buildTurnoverCard(
    BuildContext context,
    TurnoverWithTagTurnovers turnoverWithTags,
    Map<UuidValue, dynamic> tagById,
  ) {
    final isSelected = selectedIds.contains(turnoverWithTags.turnover.id);

    // Calculate transfer flags for this turnover
    bool hasTransfer = false;
    bool transferNeedsReview = false;

    for (final tagTurnover in turnoverWithTags.tagTurnovers) {
      final tagTurnoverId = tagTurnover.id;
      final isTransferTag = tagById[tagTurnover.tagId]?.isTransfer ?? false;
      final transferDetails = transferByTagTurnoverId?[tagTurnoverId];

      // Show transfer badge if tag has transfer semantic OR is linked to a transfer
      if (isTransferTag || transferDetails != null) {
        hasTransfer = true;

        // Unlinked transfer tags need review
        final isUnlinkedTransfer = isTransferTag && transferDetails == null;
        if (isUnlinkedTransfer || transferDetails?.needsReview != null) {
          transferNeedsReview = true;
          break; // No need to check further
        }
      }
    }

    return TurnoverCard(
      key: Key(turnoverWithTags.turnover.id.uuid),
      turnoverWithTags: turnoverWithTags,
      isSelected: isSelected,
      isBatchMode: isBatchMode,
      hasTransfer: hasTransfer,
      transferNeedsReview: transferNeedsReview,
      onTap: () {
        onItemTap(turnoverWithTags);
      },
      onLongPress: () {
        onItemLongPress(turnoverWithTags);
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
            error,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No turnovers found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your turnovers will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
