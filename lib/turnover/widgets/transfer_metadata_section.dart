import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Displays metadata about a transfer (created/confirmed dates and actions).
class TransferMetadataSection extends StatelessWidget {
  final TransferWithDetails details;
  final VoidCallback? onConfirm;

  const TransferMetadataSection({
    super.key,
    required this.details,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    final confirmed = details.transfer.confirmed;
    final confirmedAt = details.transfer.confirmedAt;
    final canConfirm = details.canConfirm;
    final hasIssue = details.needsReview != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Confirmed date or action button
        if (confirmed) ...[
          Text(
            'CONFIRMED',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateFormat.format(confirmedAt!),
            style: theme.textTheme.bodyMedium,
          ),
        ] else if (hasIssue)
          if (!canConfirm)
            const Text('(A transfer with this issue cannot be confirmed)')
          else ...[
            const Text(
              'If the found issue is not a real problem, you can confirm the transfer details to be correct. Only the "from" amount will be taken into account during overview calculations.',
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onConfirm,
              child: Text('Confirm it\'s not an issue'),
            ),
          ],
      ],
    );
  }
}
