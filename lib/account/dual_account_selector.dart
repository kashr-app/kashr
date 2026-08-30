import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/account/widgets/create_account_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Picks the two accounts of a transfer, and creates them when they are
/// missing.
class DualAccountSelectorDialog extends StatefulWidget {
  const DualAccountSelectorDialog({super.key});

  /// Shows the dialog and returns the picked pair, or `null` when the user
  /// cancelled.
  static Future<TransferAccountSelection?> show(BuildContext context) {
    return showDialog<TransferAccountSelection>(
      context: context,
      // Stay on the caller's navigator so that pages opened from the dialog,
      // account creation in particular, show up above it.
      useRootNavigator: false,
      builder: (context) => const DualAccountSelectorDialog(),
    );
  }

  @override
  State<DualAccountSelectorDialog> createState() =>
      _DualAccountSelectorDialogState();
}

class _DualAccountSelectorDialogState extends State<DualAccountSelectorDialog> {
  Account? from;
  Account? to;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final hasHiddenAccounts =
            (state.accountsByIsHidden[true] ?? []).isNotEmpty;

        return AlertDialog(
          title: const Text("Transfer Between Accounts"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: state.accountById.isEmpty
                  ? [
                      _NoAccountsYet(
                        onCreated: (account) => setState(() => from = account),
                      ),
                    ]
                  : [
                      _AccountSection(
                        accounts: state.visibleAccounts,
                        label: "From",
                        selected: from,
                        onSelected: (account) => setState(() {
                          from = account;
                          if (to == account) to = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _AccountSection(
                        accounts: state.visibleAccounts,
                        label: "To",
                        selected: to,
                        onSelected: (account) => setState(() {
                          to = account;
                          if (from == account) from = null;
                        }),
                      ),
                      if (hasHiddenAccounts)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Show hidden'),
                          value: state.showHiddenAccounts,
                          onChanged: (_) => context
                              .read<AccountCubit>()
                              .toggleHiddenAccounts(),
                        ),
                    ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: (from != null && to != null)
                  ? () => Navigator.pop(
                      context,
                      TransferAccountSelection(from: from!, to: to!),
                    )
                  : null,
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );
  }
}

/// One side of the transfer: the accounts to pick from, plus a way to create
/// one more.
class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.accounts,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final List<Account> accounts;
  final String label;
  final Account? selected;
  final ValueChanged<Account> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Scrollbar(
              child: ListView.builder(
                primary: false,
                shrinkWrap: true,
                itemCount: accounts.length + 1,
                itemBuilder: (context, index) {
                  if (index == accounts.length) {
                    return CreateAccountTile(onCreated: onSelected);
                  }

                  final account = accounts[index];
                  final isSelected = account == selected;
                  final cs = theme.colorScheme;

                  return ListTile(
                    leading: Icon(
                      account.accountType.icon,
                      color: theme.iconTheme.color,
                    ),
                    title: Text(account.name),
                    subtitle: Text(account.accountType.label()),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: cs.primary)
                        : null,
                    tileColor: isSelected
                        ? cs.primary.withValues(alpha: 0.08)
                        : null,
                    onTap: () => onSelected(account),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown instead of the two sections while there is nothing to transfer
/// between.
class _NoAccountsYet extends StatelessWidget {
  const _NoAccountsYet({required this.onCreated});

  final ValueChanged<Account> onCreated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A transfer moves money between two of your accounts.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        CreateAccountTile(onCreated: onCreated),
      ],
    );
  }
}

class TransferAccountSelection {
  final Account from;
  final Account to;

  TransferAccountSelection({required this.from, required this.to});
}
