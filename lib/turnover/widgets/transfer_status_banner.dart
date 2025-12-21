import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:flutter/material.dart';

/// Displays the status banner for a transfer (review warning or confirmed).
class TransferStatusBanner extends StatelessWidget {
  final TransferReviewReason? reviewReason;
  final bool isConfirmed;

  const TransferStatusBanner({
    super.key,
    this.reviewReason,
    required this.isConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewReason != null) {
      return _ReviewWarningBanner(reason: reviewReason!);
    }
    if (isConfirmed) {
      return const _ConfirmedBanner();
    }
    return const SizedBox.shrink();
  }
}

class _ReviewWarningBanner extends StatelessWidget {
  final TransferReviewReason reason;

  const _ReviewWarningBanner({required this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_outlined,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Needs Review',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  reason.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedBanner extends StatelessWidget {
  const _ConfirmedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Text(
            'Confirmed',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
