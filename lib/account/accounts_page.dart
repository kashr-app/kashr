import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/create_account_page.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/edit_account_page.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AccountsRoute extends GoRouteData with $AccountsRoute {
  const AccountsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const AccountsPage();
  }
}

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: SafeArea(
        child: BlocBuilder<AccountCubit, AccountState>(
          builder: (context, state) {
            if (state.status.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status.isError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.errorMessage ?? 'An error occurred',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          context.read<AccountCubit>().loadAccounts(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state.accounts.isEmpty && state.hiddenAccounts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No accounts yet'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _navigateToCreateAccount(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Account'),
                    ),
                  ],
                ),
              );
            }

            final visibleAccounts = state.accounts;
            final hiddenAccounts = state.hiddenAccounts;
            final showHidden = state.showHiddenAccounts;
            final hasHiddenAccounts = hiddenAccounts.isNotEmpty;

            final displayedAccounts = [
              ...visibleAccounts,
              if (showHidden) ...hiddenAccounts,
            ];

            final itemCount =
                displayedAccounts.length + (hasHiddenAccounts ? 1 : 0);

            if (displayedAccounts.isEmpty && hasHiddenAccounts) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No visible accounts'),
                    const SizedBox(height: 16),
                    _HiddenAccountsHint(
                      hiddenCount: hiddenAccounts.length,
                      isExpanded: showHidden,
                      onTap: () => context
                          .read<AccountCubit>()
                          .toggleHiddenAccounts(),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => context.read<AccountCubit>().loadAccounts(),
              child: ListView.builder(
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index < displayedAccounts.length) {
                    final account = displayedAccounts[index];
                    final balance = account.id != null
                        ? state.balances[account.id!.uuid]
                        : null;

                    return _AccountListItem(
                      account: account,
                      balance: balance,
                      onTap: () => _navigateToEditAccount(context, account),
                    );
                  } else {
                    return _HiddenAccountsHint(
                      hiddenCount: hiddenAccounts.length,
                      isExpanded: showHidden,
                      onTap: () => context
                          .read<AccountCubit>()
                          .toggleHiddenAccounts(),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateAccount(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToCreateAccount(BuildContext context) {
    const CreateAccountRoute().go(context);
  }

  void _navigateToEditAccount(BuildContext context, Account account) {
    if (account.id != null) {
      EditAccountRoute(accountId: account.id!.uuid).go(context);
    }
  }
}

class _AccountListItem extends StatelessWidget {
  final Account account;
  final Decimal? balance;
  final VoidCallback onTap;

  const _AccountListItem({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currency = Currency.currencyFrom(account.currency);
    final balanceText = balance != null
        ? currency.format(balance!)
        : 'Calculating...';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            account.accountType.icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.accountType.label()),
            if (account.syncSource != null &&
                account.syncSource != SyncSource.manual)
              Text(
                'Synced with ${account.syncSource!.label()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              balanceText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: balance != null && balance! < Decimal.zero
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _HiddenAccountsHint extends StatelessWidget {
  final int hiddenCount;
  final bool isExpanded;
  final VoidCallback onTap;

  const _HiddenAccountsHint({
    required this.hiddenCount,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isExpanded
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isExpanded
                    ? 'Hide $hiddenCount hidden ${hiddenCount == 1 ? 'account' : 'accounts'}'
                    : '$hiddenCount hidden ${hiddenCount == 1 ? 'account' : 'accounts'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
