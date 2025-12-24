import 'package:kashr/savings/cubit/savings_cubit.dart';
import 'package:kashr/savings/savings_detail_page.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/turnover_module.dart';
import 'package:flutter/material.dart';

/// Listens to tag deletion events and blocks deletion if the tag has
/// associated savings.
///
/// When a tag with savings is about to be deleted, this listener provides:
/// - Information about why deletion is blocked
/// - Alternative actions: view savings, merge with another tag
class SavingsTagListener extends TagListener {
  final SavingsCubit savingsCubit;

  SavingsTagListener(this.savingsCubit);

  @override
  Future<BeforeTagDeleteResult> onBeforeTagDelete(
    Tag tag, {
    required VoidCallback recheckStatus,
  }) async {
    final savingsState = savingsCubit.state;
    final savings = savingsState.savingsById.values
        .where((s) => s.tagId == tag.id)
        .firstOrNull;

    if (savings == null) {
      return BeforeTagDeleteResult(
        canProceed: true,
        blockingReason: null,
        buildSuggestedActions: null,
      );
    }

    return BeforeTagDeleteResult(
      canProceed: false,
      blockingReason:
          'This tag has associated savings that must be handled first.',
      buildSuggestedActions: (context) => [
        _buildInfoSection(context),
        const SizedBox(height: 12),
        _buildActionButtons(context, tag, savings),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you can do:',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoBullet(
          context,
          'Delete the savings first, then delete the tag',
        ),
        const SizedBox(height: 4),
        _buildInfoBullet(
          context,
          'Merge this tag with another tag to keep your savings',
        ),
      ],
    );
  }

  Widget _buildInfoBullet(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Icons.circle,
            size: 6,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Tag tag, dynamic savings) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              SavingsDetailRoute(savingsId: savings.id.uuid).push(context);
            },
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('View Savings'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              side: BorderSide(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
