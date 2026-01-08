import 'package:kashr/account/model/account.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Displays one side (FROM or TO) of a transfer.
class TransferSideCard extends StatelessWidget {
  /// The tag turnover for this side (null if missing).
  final TagTurnover? tagTurnover;

  /// The tag associated with this side.
  final Tag? tag;

  /// Tge account on which the [tagTurnover] is booked
  final Account? account;

  /// The sign of this side (negative for FROM/expense, positive for TO/income).
  final TurnoverSign sign;

  /// Callback when the user wants to link a tag turnover to this side.
  final VoidCallback? onLink;

  /// Callback when the user wants to create a new tag turnover for this side.
  final VoidCallback? onCreate;

  /// Callback when the user wants to unlink the tag turnover from this side.
  final VoidCallback? onUnlink;

  /// Callback when the user taps on the card to edit the tag turnover.
  final VoidCallback? onTap;

  const TransferSideCard({
    super.key,
    this.tagTurnover,
    this.tag,
    this.account,
    required this.sign,
    this.onLink,
    this.onCreate,
    this.onUnlink,
    this.onTap,
  });

  String get _label => sign == TurnoverSign.expense ? 'FROM' : 'TO';

  TurnoverSign get _requiredSign =>
      sign == TurnoverSign.expense ? TurnoverSign.expense : TurnoverSign.income;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        tagTurnover == null
            ? _MissingSideCard(
                theme: theme,
                requiredSign: _requiredSign,
                onLink: onLink,
                onCreate: onCreate,
              )
            : _LinkedSideCard(
                theme: theme,
                tagTurnover: tagTurnover!,
                tag: tag,
                account: account,
                onUnlink: onUnlink,
                onTap: onTap,
              ),
      ],
    );
  }
}

class _MissingSideCard extends StatelessWidget {
  final ThemeData theme;
  final TurnoverSign requiredSign;
  final VoidCallback? onLink;
  final VoidCallback? onCreate;

  const _MissingSideCard({
    required this.theme,
    required this.requiredSign,
    this.onLink,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  'Missing',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                OutlinedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onLink,
                  icon: const Icon(Icons.link),
                  label: const Text('Link Existing'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedSideCard extends StatelessWidget {
  final ThemeData theme;
  final TagTurnover tagTurnover;
  final Tag? tag;
  final Account? account;
  final VoidCallback? onUnlink;
  final VoidCallback? onTap;

  const _LinkedSideCard({
    required this.theme,
    required this.tagTurnover,
    this.tag,
    this.account,
    this.onUnlink,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (tag != null) ...[
                    TagAvatar(tag: tag!, radius: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tag!.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'Unknown Tag',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  Text(
                    tagTurnover.formatAmount(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (onUnlink != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.link_off),
                      iconSize: 20,
                      tooltip: 'Unlink',
                      onPressed: onUnlink,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(tagTurnover.bookingDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (account != null)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            account!.accountType.icon,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              account!.name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (tagTurnover.note != null && tagTurnover.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(tagTurnover.note!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
