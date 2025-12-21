import 'package:finanalyzer/core/color_utils.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tag_turnovers.dart';
import 'package:finanalyzer/turnover/widgets/tag_amount_bar.dart';
import 'package:finanalyzer/turnover/widgets/transfer_issue_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A beautiful card widget for displaying a turnover with its tag allocations.
class TurnoverCard extends StatelessWidget {
  final TurnoverWithTagTurnovers turnoverWithTags;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isBatchMode;
  final bool hasTransfer;
  final bool transferNeedsReview;

  const TurnoverCard({
    required this.turnoverWithTags,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isBatchMode = false,
    this.hasTransfer = false,
    this.transferNeedsReview = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final turnover = turnoverWithTags.turnover;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final amountColor = theme.decimalColor(turnover.amountValue);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show checkbox in batch mode
              if (isBatchMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              // Transfer badges
              if (hasTransfer) ...[
                Row(
                  children: [
                    const TransferBadge.badge(),
                    if (transferNeedsReview) ...[
                      const SizedBox(width: 8),
                      TransferBadge.needsReview(),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Header: Counter party and amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          turnover.counterPart ?? 'Unknown',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          turnover.formatDate() ?? 'Not booked',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    turnover.formatAmount(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (turnoverWithTags.tagTurnovers.isNotEmpty) ...[
                BlocBuilder<TagCubit, TagState>(
                  builder: (context, tagState) {
                    final tagById = tagState.tagById;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TagAmountBar(
                          totalAmount: turnover.amountValue,
                          tagTurnovers: turnoverWithTags.tagTurnovers,
                          tagById: tagById,
                        ),
                        const SizedBox(height: 8),
                        ...turnoverWithTags.tagTurnovers
                            .where((tt) => tt.note?.isNotEmpty == true)
                            .map(
                              (tt) => TagNoteDisplay(
                                tagTurnover: tt,
                                tag: tagById[tt.tagId],
                              ),
                            ),
                        // Tag chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: turnoverWithTags.tagTurnovers.map((
                            tagTurnover,
                          ) {
                            final tag = tagById[tagTurnover.tagId];
                            final tagName = tag?.name ?? '(Unknown)';
                            final tagColor =
                                ColorUtils.parseColor(
                                  tag?.color,
                                )?.withValues(alpha: 0.1) ??
                                Colors.grey.shade400;
                            return Chip(
                              label: Text(
                                '$tagName: ${tagTurnover.format()}',
                                style: theme.textTheme.bodySmall,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              backgroundColor: tagColor,
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.label_off_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No tags assigned',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TagNoteDisplay extends StatelessWidget {
  const TagNoteDisplay({
    super.key,
    required this.tagTurnover,
    required this.tag,
  });

  final TagTurnover tagTurnover;
  final Tag? tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.note,
              size: 16,
              color:
                  ColorUtils.parseColor(tag?.color) ??
                  colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${tagTurnover.note}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
