import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/widgets/tag_turnover_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

/// Displays the tag turnovers list content including error, empty, and list states.
class TagTurnoversListContent extends StatelessWidget {
  const TagTurnoversListContent({
    required this.items,
    required this.isLoading,
    required this.hasMore,
    required this.error,
    required this.scrollController,
    required this.selectedIds,
    required this.isBatchMode,
    required this.forSelection,
    required this.onItemTap,
    required this.onItemSelect,
    required this.onItemLongPress,
    required this.onRetry,
    required this.onLoadMore,
    this.transferByTagTurnoverId,
    this.onTransferAction,
    super.key,
  });

  final List<TagTurnover> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final ScrollController scrollController;
  final Set<UuidValue> selectedIds;
  final bool isBatchMode;
  final bool forSelection;
  final void Function(TagTurnover) onItemTap;
  final void Function(TagTurnover) onItemSelect;
  final void Function(TagTurnover) onItemLongPress;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final Map<UuidValue, TransferWithDetails>? transferByTagTurnoverId;
  final void Function(TagTurnover item, TransferWithDetails? sourceTransfer)?
  onTransferAction;

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
        return BlocBuilder<AccountCubit, AccountState>(
          builder: (context, accountState) {
            return ListView.builder(
              controller: scrollController,
              itemCount: items.length + (hasMore || isLoading ? 1 : 0),
              itemBuilder: (context, index) {
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
                final isSelected = selectedIds.contains(item.id);
                final transferDetails = transferByTagTurnoverId?[item.id];

                return TagTurnoverCard(
                  tagTurnover: item,
                  tagById: tagState.tagById,
                  accountByid: accountState.accountById,
                  isSelected: isSelected,
                  isBatchMode: isBatchMode,
                  transferWithDetails: transferDetails,
                  onTransferAction: onTransferAction != null
                      ? () => onTransferAction!(item, transferDetails)
                      : null,
                  onTap: () => onItemTap(item),
                  onSelect: () => onItemSelect(item),
                  onLongPress: () => onItemLongPress(item),
                  forSelection: forSelection,
                );
              },
            );
          },
        );
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
            'Error loading tag turnovers',
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
            Icons.label_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No tag turnovers found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tag turnovers will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
