import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/account/widgets/create_account_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/model/account.dart';
import 'package:uuid/uuid.dart';

/// Picks one account, and creates one when there is none to pick.
class AccountSelectorDialog extends StatelessWidget {
  final UuidValue? selectedId;
  final String? title;
  final UuidValue? excludeId;
  const AccountSelectorDialog({
    super.key,
    this.selectedId,
    this.title,
    this.excludeId,
  });

  /// Shows the dialog and returns the selected or created account, or `null`
  /// when the user cancelled.
  static Future<Account?> show(
    BuildContext context, {
    final UuidValue? selectedId,
    final String? title,
    final UuidValue? excludeId,
  }) async {
    return await showDialog<Account>(
      context: context,
      // Stay on the caller's navigator so that pages opened from the dialog,
      // account creation in particular, show up above it.
      useRootNavigator: false,
      builder: (context) => AccountSelectorDialog(
        selectedId: selectedId,
        title: title,
        excludeId: excludeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final items = excludeId != null
            ? state.visibleAccounts.where((it) => it.id != excludeId).toList()
            : state.visibleAccounts;
        final hasHiddenAccounts =
            (state.accountsByIsHidden[true] ?? []).isNotEmpty;

        return AlertDialog(
          title: Text(title ?? 'Select Account'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items.isEmpty)
                  _EmptyHint(hasOtherAccounts: state.accountById.isNotEmpty)
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final account = items[index];
                        final isSelected = account.id == selectedId;
                        return ListTile(
                          selected: isSelected,
                          leading: Icon(account.accountType.icon),
                          title: Text(account.name),
                          subtitle: Text(account.accountType.label()),
                          onTap: () => Navigator.of(context).pop(account),
                          trailing: isSelected ? Icon(Icons.check) : null,
                        );
                      },
                    ),
                  ),
                const Divider(),
                CreateAccountTile(
                  onCreated: (account) => Navigator.of(context).pop(account),
                ),
                if (hasHiddenAccounts)
                  SwitchListTile(
                    title: Text('Show hidden'),
                    value: state.showHiddenAccounts,
                    onChanged: (_) =>
                        context.read<AccountCubit>().toggleHiddenAccounts(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Explains why the list above it is empty.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.hasOtherAccounts});

  /// Whether accounts exist that this picker does not offer.
  final bool hasOtherAccounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        hasOtherAccounts ? 'No other account to pick.' : 'No accounts yet.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
