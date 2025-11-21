import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/color_utils.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/widgets/tag_amount_bar.dart';
import 'package:flutter/material.dart';

/// A beautiful card widget for displaying a turnover with its tag allocations.
class TurnoverCard extends StatelessWidget {
  final TurnoverWithTags turnoverWithTags;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isBatchMode;

  const TurnoverCard({
    required this.turnoverWithTags,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isBatchMode = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final turnover = turnoverWithTags.turnover;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isNegative = turnover.amountValue < Decimal.zero;
    final amountColor = isNegative ? colorScheme.error : colorScheme.primary;

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
                TagAmountBar(
                  totalAmount: turnover.amountValue,
                  tagTurnovers: turnoverWithTags.tagTurnovers,
                ),
                const SizedBox(height: 8),
                ...turnoverWithTags.tagTurnovers
                    .where((tt) => tt.tagTurnover.note?.isNotEmpty == true)
                    .map((tt) => TagNoteDisplay(tagTurnover: tt)),
                // Tag chips
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: turnoverWithTags.tagTurnovers.map((tagTurnover) {
                    return Chip(
                      label: Text(
                        '${tagTurnover.tag.name}: ${tagTurnover.tagTurnover.format()}',
                        style: theme.textTheme.bodySmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      backgroundColor:
                          ColorUtils.parseColor(
                            tagTurnover.tag.color,
                          )?.withValues(alpha: 0.1) ??
                          Colors.grey.shade400,
                    );
                  }).toList(),
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
  const TagNoteDisplay({super.key, required this.tagTurnover});

  final TagTurnoverWithTag tagTurnover;

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
                  ColorUtils.parseColor(tagTurnover.tag.color) ??
                  colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${tagTurnover.tagTurnover.note}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

