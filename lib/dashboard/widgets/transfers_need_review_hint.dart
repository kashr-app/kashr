import 'package:kashr/dashboard/widgets/dashboard_hint.dart';
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

    return DashboardHint(
      icon: Icon(Icons.warning_outlined),
      title: '$count transfer${count != 1 ? 's' : ''} need review',
      color: theme.colorScheme.onErrorContainer,
      colorBackground: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
      onTap: () {
        const TransfersRoute(
          filters: TransfersFilter(needsReviewOnly: true),
        ).go(context);
      },
    );
  }
}
