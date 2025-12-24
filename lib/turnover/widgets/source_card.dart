import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Displays the source tagTurnover that we're trying to match.
///
/// Used as a header when selecting a matching TagTurnover to provide context
/// about which transaction we're trying to link.
class SourceCard extends StatelessWidget {
  final TagTurnover tagTurnover;
  final Tag tag;

  const SourceCard({super.key, required this.tagTurnover, required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Looking for match:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TagAvatar(tag: tag, radius: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      dateFormat.format(tagTurnover.bookingDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (tagTurnover.note != null &&
                        tagTurnover.note!.isNotEmpty)
                      Text(
                        tagTurnover.note!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tagTurnover.format(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
