import 'package:decimal/decimal.dart';
import 'package:kashr/account/accounts_page.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/home/home_page.dart';
import 'package:kashr/logging/services/log_service.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/model/turnover_with_tag_turnovers.dart';
import 'package:kashr/turnover/services/turnover_service.dart';
import 'package:kashr/turnover/turnover_tags_page.dart';
import 'package:kashr/turnover/widgets/turnover_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class AccountAllTurnoversRoute extends GoRouteData
    with $AccountAllTurnoversRoute {
  final String accountId;

  const AccountAllTurnoversRoute({required this.accountId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return AccountAllTurnoversPage(accountId: UuidValue.fromString(accountId));
  }
}

class AccountAllTurnoversPage extends StatefulWidget {
  final UuidValue accountId;

  const AccountAllTurnoversPage({super.key, required this.accountId});

  @override
  State<AccountAllTurnoversPage> createState() =>
      _AccountAllTurnoversPageState();
}

class _AccountAllTurnoversPageState extends State<AccountAllTurnoversPage> {
  final _scrollController = ScrollController();
  final List<TurnoverWithTagTurnovers> _items = [];

  static const _pageSize = 20;
  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  Decimal? _openingBalance;
  DateTime? _openingBalanceDate;

  late final TurnoverRepository _turnoverRepository;
  late final TurnoverService _turnoverService;
  late final Logger _log;

  @override
  void initState() {
    super.initState();
    _log = context.read<LogService>().log;
    _turnoverRepository = context.read<TurnoverRepository>();
    _turnoverService = context.read<TurnoverService>();
    _scrollController.addListener(_onScroll);
    _loadAccountInfo();
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountInfo() async {
    final accountState = context.read<AccountCubit>().state;
    final account = accountState.accountById[widget.accountId];

    if (account != null) {
      setState(() {
        _openingBalance = account.openingBalance;
        _openingBalanceDate = account.openingBalanceDate;
      });
    }
  }

  void _onScroll() {
    if (_isLoading || !_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final turnovers = await _turnoverRepository.getTurnoversPaginated(
        limit: _pageSize,
        offset: _currentOffset,
        filter: TurnoverFilter(accountId: widget.accountId),
      );

      final newItems = await _turnoverService.getTurnoversWithTags(turnovers);

      setState(() {
        _items.addAll(newItems);
        _currentOffset += turnovers.length;
        _hasMore = turnovers.length >= _pageSize;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      _log.e(
        'Error fetching turnovers page',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _currentOffset = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadAccountInfo();
    await _loadMore();
  }

  void _showOpeningBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opening Balance'),
        content: const Text(
          'The opening balance is calculated as your current account balance minus the sum of all transactions on the account.'
          ' The date states when it was last re-calculated, typically when the current balance is updated (e.g. during sync).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final account = state.accountById[widget.accountId];

        if (account == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('All Turnovers')),
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

        final currency = Currency.currencyFrom(account.currency);

        return Scaffold(
          appBar: AppBar(title: Text('${account.name} - All Turnovers')),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _items.length + 1,
              itemBuilder: (context, index) {
                // Loading/error/end indicator
                if (index >= _items.length) {
                  if (_error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text('Error: $_error'),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _loadMore,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (_isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  // Opening balance item (always last)
                  return _buildOpeningBalanceCard(currency);
                }

                // Turnover item
                final turnoverWithTags = _items[index];
                return TurnoverCard(
                  turnoverWithTags: turnoverWithTags,
                  onTap: () {
                    final id = turnoverWithTags.turnover.id;
                    TurnoverTagsRoute(
                      turnoverId: id.uuid,
                    ).push(context).then((_) => _refresh());
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpeningBalanceCard(Currency currency) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: _showOpeningBalanceDialog,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opening Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_openingBalanceDate != null)
                      Text(
                        'Modified at ${_formatDate(_openingBalanceDate!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (_openingBalance != null)
                Text(
                  currency.format(_openingBalance!),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).decimalColor(_openingBalance!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
