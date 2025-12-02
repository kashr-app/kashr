import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/widgets/turnover_card.dart';
import 'package:flutter/material.dart';

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
    super.key,
  });

  final List<TurnoverWithTags> items;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final ScrollController scrollController;
  final Set<String> selectedIds;
  final bool isBatchMode;
  final void Function(TurnoverWithTags) onItemTap;
  final void Function(TurnoverWithTags) onItemLongPress;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && error != null) {
      return _ErrorState(error: error!, onRetry: onRetry);
    }

    if (items.isEmpty && !isLoading) {
      return const _EmptyState();
    }

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

        final turnoverWithTags = items[index];
        final turnoverId = turnoverWithTags.turnover.id.uuid;
        final isSelected = selectedIds.contains(turnoverId);

        return TurnoverCard(
          turnoverWithTags: turnoverWithTags,
          isSelected: isSelected,
          isBatchMode: isBatchMode,
          onTap: () {
            onItemTap(turnoverWithTags);
          },
          onLongPress: () {
            onItemLongPress(turnoverWithTags);
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
