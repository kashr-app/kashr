import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:finanalyzer/turnover/model/tag.dart';

class AccountDivergenceConfirmationDialog extends StatelessWidget {
  final List<TagTurnoverWithTagAndAccounts> divergingTagTurnovers;

  const AccountDivergenceConfirmationDialog({
    required this.divergingTagTurnovers,
    super.key,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<TagTurnover> divergingTagTurnovers,
    required Map<String, Tag> tagMap,
    required Map<String, Account> accountMap,
    required Account targetAccount,
  }) {
    final items = divergingTagTurnovers.map((tt) {
      final tag = tagMap[tt.tagId.uuid];
      final currentAccount = accountMap[tt.accountId.uuid];
      return TagTurnoverWithTagAndAccounts(
        tagTurnover: tt,
        tag: tag ?? Tag(name: 'Unknown', id: tt.tagId),
        currentAccount: currentAccount,
        targetAccount: targetAccount,
      );
    }).toList();

    return showDialog<bool>(
      context: context,
      builder: (context) => AccountDivergenceConfirmationDialog(
        divergingTagTurnovers: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Account Mismatch')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The following tag turnovers have different accounts. '
              'Confirming will update their account to match the turnover.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: divergingTagTurnovers.length,
                itemBuilder: (context, index) {
                  final item = divergingTagTurnovers[index];
                  return _DivergingAccountItem(item: item);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _DivergingAccountItem extends StatelessWidget {
  final TagTurnoverWithTagAndAccounts item;

  const _DivergingAccountItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = item.tagTurnover;
    final tag = item.tag;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagAvatar(tag: tag, radius: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tt.note ?? tag.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        tt.format(),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AccountChip(
                    account: item.currentAccount,
                    label: 'From',
                    color: theme.colorScheme.errorContainer,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _AccountChip(
                    account: item.targetAccount,
                    label: 'To',
                    color: theme.colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  final Account? account;
  final String label;
  final Color color;

  const _AccountChip({
    required this.account,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            account?.name ?? 'Unknown',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class TagTurnoverWithTagAndAccounts {
  final TagTurnover tagTurnover;
  final Tag tag;
  final Account? currentAccount;
  final Account targetAccount;

  TagTurnoverWithTagAndAccounts({
    required this.tagTurnover,
    required this.tag,
    this.currentAccount,
    required this.targetAccount,
  });
}
