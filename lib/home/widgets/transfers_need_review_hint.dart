import 'package:kashr/turnover/model/transfers_filter.dart';
import 'package:kashr/turnover/transfers_page.dart';
import 'package:flutter/material.dart';

/// Hint shown on dashboard when transfers need user review.
///
/// Transfers need review when:
/// - Missing from or to side
/// - Amounts don't match (same currency, not confirmed)
/// - Different currencies (not confirmed)
class TransfersNeedReviewHint extends StatelessWidget {
  final int count;

  const TransfersNeedReviewHint({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            const TransfersRoute(
              filters: TransfersFilter(needsReviewOnly: true),
            ).go(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.warning_outlined,
                  size: 18,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count transfer${count != 1 ? 's' : ''} need review',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
