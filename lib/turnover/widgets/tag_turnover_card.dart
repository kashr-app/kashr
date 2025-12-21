import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:finanalyzer/turnover/widgets/transfer_issue_badge.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid_value.dart';

/// Card displaying a single tag turnover with its details.
class TagTurnoverCard extends StatelessWidget {
  const TagTurnoverCard({
    required this.tagTurnover,
    required this.isSelected,
    required this.isBatchMode,
    required this.onTap,
    required this.onSelect,
    required this.onLongPress,
    required this.tagById,
    required this.accountByid,
    this.transferWithDetails,
    this.onTransferAction,
    required this.forSelection,
    super.key,
  });

  final TagTurnover tagTurnover;
  final Map<UuidValue, Tag> tagById;
  final Map<UuidValue, Account> accountByid;
  final bool isSelected;
  final bool isBatchMode;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final VoidCallback onLongPress;
  final TransferWithDetails? transferWithDetails;
  final VoidCallback? onTransferAction;
  final bool forSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tag = tagById[tagTurnover.tagId];
    final account = accountByid[tagTurnover.accountId];
    final dateFormat = DateFormat('MMM d, yyyy');

    final isDone = tagTurnover.isMatched;
    final isTransferTag = tag?.isTransfer ?? false;
    final hasTransfer = transferWithDetails != null;
    final isTransfer = isTransferTag || hasTransfer;
    final isUnlinkedTransfer = isTransferTag && !hasTransfer;
    final transferNeedsReview = transferWithDetails?.needsReview;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSelected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: isBatchMode ? onSelect : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Selection checkbox in batch mode
                  if (isBatchMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onTap(),
                      ),
                    ),

                  // Tag avatar
                  TagAvatar(tag: tag, radius: 20),
                  const SizedBox(width: 12),

                  // Main content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tag?.name ?? '(Unknown)',
                                style: theme.textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              tagTurnover.format(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).decimalColor(tagTurnover.amountValue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              account?.accountType.icon ??
                                  Icons.account_balance,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                account?.name ?? '(Unknown)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateFormat.format(tagTurnover.bookingDate),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (tagTurnover.note != null &&
                            tagTurnover.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            tagTurnover.note!,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // status icon
                  const SizedBox(width: 8),
                  Icon(
                    isDone ? Icons.check_circle : Icons.pending_outlined,
                    size: 20,
                    color: isDone ? colorScheme.primary : colorScheme.outline,
                  ),
                ],
              ),
              // Transfer badges
              if (isTransfer) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TransferBadge.badge(),
                    if (isUnlinkedTransfer) ...[
                      const SizedBox(width: 8),
                      TransferBadge.unlinked(),
                    ] else if (transferNeedsReview != null) ...[
                      const SizedBox(width: 8),
                      TransferBadge.needsReviewDetailed(
                        transferNeedsReview,
                      ),
                    ],
                  ],
                ),
              ],
              // Action buttons
              if (forSelection && !isBatchMode) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onSelect,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: Text('Select'),
                ),
              ] else if (!isBatchMode) ...[
                if (isTransfer && onTransferAction != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onTransferAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      isUnlinkedTransfer ? Icons.link : Icons.open_in_new,
                      size: 16,
                    ),
                    label: Text(
                      isUnlinkedTransfer ? 'Link transfer' : 'View transfer',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
