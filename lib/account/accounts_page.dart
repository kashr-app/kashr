import 'package:decimal/decimal.dart';
import 'package:kashr/account/account_details_page.dart';
import 'package:kashr/account/create_account_page.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/home/home_page.dart';
import 'package:kashr/savings/model/savings.dart';
import 'package:kashr/savings/savings_detail_page.dart';
import 'package:kashr/savings/services/savings_balance_service.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
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

            if (state.accountById.isEmpty) {
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

            final showHidden = state.showHiddenAccounts;
            final displayedAccounts = state.visibleAccounts;
            final hiddenAccounts = (state.accountsByIsHidden[true] ?? []);
            final hasHiddenAccounts = hiddenAccounts.isNotEmpty;


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
                      onTap: () =>
                          context.read<AccountCubit>().toggleHiddenAccounts(),
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
                    final balance =  state.balances[account.id];
                    final projectedBalance =state.projectedBalances[account.id];

                    return _AccountListItem(
                      account: account,
                      balance: balance,
                      projectedBalance: projectedBalance,
                      projectionDate: state.projectionDate,
                      onTap: () => _navigateToAccountDetails(context, account),
                    );
                  } else {
                    return _HiddenAccountsHint(
                      hiddenCount: hiddenAccounts.length,
                      isExpanded: showHidden,
                      onTap: () =>
                          context.read<AccountCubit>().toggleHiddenAccounts(),
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

  void _navigateToAccountDetails(BuildContext context, Account account) {
    AccountDetailsRoute(accountId: account.id.uuid).go(context);
  }
}

class _AccountListItem extends StatefulWidget {
  final Account account;
  final Decimal? balance;
  final Decimal? projectedBalance;
  final DateTime projectionDate;
  final VoidCallback onTap;

  const _AccountListItem({
    required this.account,
    required this.balance,
    required this.projectedBalance,
    required this.projectionDate,
    required this.onTap,
  });

  @override
  State<_AccountListItem> createState() => _AccountListItemState();
}

class _AccountListItemState extends State<_AccountListItem> {
  Map<Savings, SavingsAccountInfo>? _savingsBreakdown;

  @override
  void initState() {
    super.initState();
    _loadSavingsBreakdown();
  }

  Future<void> _loadSavingsBreakdown() async {
    try {
      final savingsService = context.read<SavingsBalanceService>();
      final breakdown = await savingsService.getSavingsBreakdownForAccount(
        widget.account.id,
      );
      if (mounted) {
        setState(() {
          _savingsBreakdown = breakdown;
        });
      }
    } catch (e) {
      // Silently fail - savings breakdown is optional
    }
  }

  String _formatMonth(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[date.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final currency = Currency.currencyFrom(widget.account.currency);
    final balanceText = widget.balance != null
        ? currency.format(widget.balance!)
        : 'Calculating...';

    final totalSavings = _savingsBreakdown?.values.fold(
      Decimal.zero,
      (sum, value) => sum + value.savingsOnAccount,
    );
    final spendableBalance = widget.balance != null && totalSavings != null
        ? widget.balance! - totalSavings
        : widget.balance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    widget.account.accountType.icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  widget.account.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(widget.account.accountType.label())],
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
                        color: Theme.of(context).decimalColor(widget.balance),
                      ),
                    ),
                    if (widget.projectedBalance != null &&
                        widget.balance != null &&
                        widget.projectedBalance != widget.balance)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'End of ${_formatMonth(widget.projectionDate)}: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            currency.format(widget.projectedBalance!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).decimalColor(widget.projectedBalance),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                onTap: widget.onTap,
              ),
              if (widget.account.syncSource != null &&
                  widget.account.syncSource != SyncSource.manual)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Synced with ${widget.account.syncSource!.label()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if (widget.account.syncSource != null &&
                          widget.account.syncSource != SyncSource.manual)
                        Text(
                          'Last sync: Not yet available',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              if (_savingsBreakdown != null &&
                  _savingsBreakdown!.isNotEmpty) ...[
                // spendable money
                ListTile(
                  leading: Icon(
                    Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text(
                    'Spendable',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    spendableBalance != null
                        ? currency.format(spendableBalance)
                        : 'Calculating...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).decimalColor(spendableBalance),
                    ),
                  ),
                ),
                Divider(),
                ..._savingsBreakdown!.entries.map((entry) {
                  return _SavingsRow(
                    savings: entry.key,
                    amount: entry.value.savingsOnAccount,
                    currency: currency,
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SavingsRow extends StatelessWidget {
  final Savings savings;
  final Decimal amount;
  final Currency currency;

  const _SavingsRow({
    required this.savings,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final tagCubit = context.read<TagCubit>();
    final tag = tagCubit.state.tags.firstWhere(
      (t) => t.id == savings.tagId,
      orElse: () => throw StateError('Tag not found'),
    );

    return ListTile(
      leading: Icon(
        Icons.savings,
        color: Theme.of(context).colorScheme.secondary,
      ),
      title: Text(
        tag.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        currency.format(amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Theme.of(context).decimalColor(amount),
        ),
      ),
      onTap: () {
        SavingsDetailRoute(savingsId: savings.id.uuid).go(context);
      },
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
