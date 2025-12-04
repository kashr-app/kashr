import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/account_all_turnovers_page.dart';
import 'package:finanalyzer/account/accounts_page.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/edit_account_page.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/color_utils.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/savings/savings_detail_page.dart';
import 'package:finanalyzer/savings/services/savings_balance_service.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/widgets/turnover_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class AccountDetailsRoute extends GoRouteData with $AccountDetailsRoute {
  final String accountId;

  const AccountDetailsRoute({required this.accountId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return AccountDetailsPage(accountId: UuidValue.fromString(accountId));
  }
}

class AccountDetailsPage extends StatefulWidget {
  final UuidValue accountId;

  const AccountDetailsPage({super.key, required this.accountId});

  @override
  State<AccountDetailsPage> createState() => _AccountDetailsPageState();
}

class _AccountDetailsPageState extends State<AccountDetailsPage> {
  Map<Savings, SavingsAccountInfo>? _savingsBreakdown;
  List<TurnoverWithTags>? _recentTurnovers;
  bool _isLoadingSavings = false;
  bool _isLoadingTurnovers = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _loadSavingsBreakdown();
    _loadRecentTurnovers();
  }

  Future<void> _loadSavingsBreakdown() async {
    setState(() => _isLoadingSavings = true);
    try {
      final savingsService = context.read<SavingsBalanceService>();
      final breakdown = await savingsService.getSavingsBreakdownForAccount(
        widget.accountId,
      );
      if (mounted) {
        setState(() {
          _savingsBreakdown = breakdown;
          _isLoadingSavings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSavings = false);
      }
    }
  }

  Future<void> _loadRecentTurnovers() async {
    setState(() => _isLoadingTurnovers = true);
    try {
      final turnoverRepository = context.read<TurnoverRepository>();
      final tagTurnoverRepository = context.read<TagTurnoverRepository>();
      final tagCubit = context.read<TagCubit>();

      final recentTurnovers = (await turnoverRepository.getTurnoversForAccount(
        accountId: widget.accountId,
        limit: 5,
        direction: SortDirection.desc,
      )).toList();

      final tagById = tagCubit.state.tagById;

      final turnoversWithTags = <TurnoverWithTags>[];
      for (final turnover in recentTurnovers) {
        final tagTurnovers = await tagTurnoverRepository.getByTurnover(
          turnover.id,
        );

        final tagTurnoversWithTags = tagTurnovers.map((tt) {
          final tag = tagById[tt.tagId];
          return TagTurnoverWithTag(
            tagTurnover: tt,
            tag: tag ?? Tag(name: 'Unknown', id: tt.tagId),
          );
        }).toList();

        turnoversWithTags.add(
          TurnoverWithTags(
            turnover: turnover,
            tagTurnovers: tagTurnoversWithTags,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _recentTurnovers = turnoversWithTags;
          _isLoadingTurnovers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTurnovers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final account = state.accountById[widget.accountId];

        if (account == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account Details')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Account not found'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => const AccountsRoute().go(context),
                    child: const Text('Back to Accounts'),
                  ),
                ],
              ),
            ),
          );
        }

        final balance = state.balances[widget.accountId];
        final currency = Currency.currencyFrom(account.currency);

        return Scaffold(
          appBar: AppBar(
            title: Text(account.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => EditAccountRoute(
                  accountId: widget.accountId.uuid,
                ).go(context),
                tooltip: 'Edit Account',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await context.read<AccountCubit>().loadAccounts();
              await _loadData();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAccountInfoCard(account, balance, currency),
                const SizedBox(height: 16),
                _buildSavingsBreakdownCard(currency, balance),
                const SizedBox(height: 16),
                _buildRecentTurnoversCard(account),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountInfoCard(
    Account account,
    Decimal? balance,
    Currency currency,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  account.accountType.icon,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.accountType.label(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (account.identifier != null)
                        Text(
                          account.identifier!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (account.syncSource != null &&
                account.syncSource != SyncSource.manual) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.sync,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Synced with ${account.syncSource!.label()}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Last sync: Not yet available',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Current Balance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              balance != null ? currency.format(balance) : 'Calculating...',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).decimalColor(balance),
              ),
            ),
            if (_savingsBreakdown != null && _savingsBreakdown!.isNotEmpty)
              _spendableTile(currency, balance),
          ],
        ),
      ),
    );
  }

  Widget _spendableTile(Currency currency, Decimal? balance) {
    final totalSavings = _savingsBreakdown!.values.fold(
      Decimal.zero,
      (sum, value) => sum + value.savingsOnAccount,
    );
    final spendableBalance = balance != null ? balance - totalSavings : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
    );
  }

  Widget _buildSavingsBreakdownCard(Currency currency, Decimal? balance) {
    if (_isLoadingSavings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savingsBreakdown == null || _savingsBreakdown!.isEmpty) {
      return const SizedBox.shrink();
    }

    final tagCubit = context.read<TagCubit>();
    final tagById = {for (final t in tagCubit.state.tags) t.id: t};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            Icon(
              Icons.savings,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Savings Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._savingsBreakdown!.entries.map((entry) {
          final savings = entry.key;
          final amount = entry.value;
          final tag = tagById[savings.tagId];

          return Card(
            child: ListTile(
              leading: Container(
                color: ColorUtils.parseColor(tag?.color),
                child: SizedBox(width: 2, height: 50),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tag?.name ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    currency.format(amount.savingsOnAccount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).decimalColor(amount.savingsOnAccount),
                    ),
                  ),
                ],
              ),
              subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Other accounts',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    currency.format(
                      amount.totalSavings - amount.savingsOnAccount,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              onTap: () {
                SavingsDetailRoute(savingsId: savings.id.uuid).go(context);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecentTurnoversCard(Account account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Turnovers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => AccountAllTurnoversRoute(
                accountId: widget.accountId.uuid,
              ).go(context),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingTurnovers)
          const Center(child: CircularProgressIndicator())
        else if (_recentTurnovers == null || _recentTurnovers!.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No turnovers yet'),
            ),
          )
        else
          ..._recentTurnovers!.map((turnoverWithTags) {
            return TurnoverCard(
              turnoverWithTags: turnoverWithTags,
              onTap: () {
                final id = turnoverWithTags.turnover.id;
                TurnoverTagsRoute(turnoverId: id.uuid).push(context);
              },
            );
          }),
      ],
    );
  }
}
