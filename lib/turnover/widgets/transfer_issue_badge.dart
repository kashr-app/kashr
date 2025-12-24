import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:flutter/material.dart';

class TransferBadge extends StatelessWidget {
  const TransferBadge._({
    required this.icon,
    required this.title,
    this.isError = true,
  });

  const TransferBadge.badge()
    : this._(icon: Icons.swap_horiz, title: 'Transfer', isError: false);

  const TransferBadge.unlinked()
    : this._(icon: Icons.link_off, title: 'Not linked to transfer');

  const TransferBadge.needsReview()
    : this._(icon: Icons.warning_amber_outlined, title: 'Needs review');

  TransferBadge.needsReviewDetailed(TransferReviewReason reviewReason)
    : this._(
        icon: Icons.warning_amber_outlined,
        title: reviewReason.description,
      );

  final IconData icon;
  final String title;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bgColor = isError
        ? colorScheme.errorContainer
        : colorScheme.tertiaryContainer;
    final fgColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
