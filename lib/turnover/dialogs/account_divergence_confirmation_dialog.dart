import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/widgets/tag_avatar.dart';
import 'package:flutter/material.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class AccountDivergenceConfirmationDialog extends StatelessWidget {
  final List<TagTurnover> divergingTagTurnovers;
  final UuidValue targetAccountId;

  const AccountDivergenceConfirmationDialog(
    this.divergingTagTurnovers,
    this.targetAccountId, {
    super.key,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<TagTurnover> divergingTagTurnovers,
    required UuidValue targetAccountId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => BlocBuilder<AccountCubit, AccountState>(
        builder: (context, state) {
          return AccountDivergenceConfirmationDialog(
            divergingTagTurnovers,
            targetAccountId,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
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
              child: BlocBuilder<TagCubit, TagState>(
                builder: (context, tagState) {
                  return BlocBuilder<AccountCubit, AccountState>(
                    builder: (context, accountState) {
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: divergingTagTurnovers.length,
                        itemBuilder: (context, index) {
                          final item = divergingTagTurnovers[index];
                          final tag = tagState.tagById[item.tagId];
                          final currentAccount =
                              accountState.accountById[item.accountId];
                          final targetAccount =
                              accountState.accountById[targetAccountId];
                          return _DivergingAccountItem(
                            item: item,
                            tag: tag,
                            currentAccount: currentAccount,
                            targetAccount: targetAccount,
                          );
                        },
                      );
                    },
                  );
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
  final TagTurnover item;
  final Tag? tag;
  final Account? currentAccount;
  final Account? targetAccount;

  const _DivergingAccountItem({
    required this.item,
    required this.tag,
    required this.currentAccount,
    required this.targetAccount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = item;

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
                        tt.note ?? tag?.name ?? '',
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
                    account: currentAccount,
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
                    account: targetAccount,
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
