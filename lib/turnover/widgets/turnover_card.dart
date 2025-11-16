import 'package:decimal/decimal.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/widgets/tag_amount_bar.dart';
import 'package:flutter/material.dart';

/// A beautiful card widget for displaying a turnover with its tag allocations.
class TurnoverCard extends StatelessWidget {
  final TurnoverWithTags turnoverWithTags;
  final VoidCallback onTap;

  const TurnoverCard({
    required this.turnoverWithTags,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final turnover = turnoverWithTags.turnover;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isNegative = turnover.amountValue < Decimal.zero;
    final amountColor = isNegative
        ? colorScheme.error
        : colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    turnover.format(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tag allocation bar
              if (turnoverWithTags.tagTurnovers.isNotEmpty) ...[
                TagAmountBar(
                  totalAmount: turnover.amountValue,
                  tagTurnovers: turnoverWithTags.tagTurnovers,
                ),
                const SizedBox(height: 8),
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
                      backgroundColor: _parseColor(tagTurnover.tag.color)
                          .withValues(alpha: 0.1),
                    );
                  }).toList(),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey.shade400;
    }

    try {
      final hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.grey.shade400;
    }
  }
}
