import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/accounts_page.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/theme.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/widgets/turnover_card.dart';
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
    return AccountAllTurnoversPage(accountId: accountId);
  }
}

class AccountAllTurnoversPage extends StatefulWidget {
  final String accountId;

  const AccountAllTurnoversPage({super.key, required this.accountId});

  @override
  State<AccountAllTurnoversPage> createState() =>
      _AccountAllTurnoversPageState();
}

class _AccountAllTurnoversPageState extends State<AccountAllTurnoversPage> {
  final _log = Logger();
  final _scrollController = ScrollController();
  final List<TurnoverWithTags> _items = [];

  static const _pageSize = 20;
  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  Decimal? _openingBalance;
  DateTime? _openingBalanceDate;

  late final TurnoverRepository _turnoverRepository;
  late final TagTurnoverRepository _tagTurnoverRepository;
  late final TagCubit _tagCubit;

  @override
  void initState() {
    super.initState();
    _turnoverRepository = context.read<TurnoverRepository>();
    _tagTurnoverRepository = context.read<TagTurnoverRepository>();
    _tagCubit = context.read<TagCubit>();
    _scrollController.addListener(_onScroll);
    _loadAccountInfo();
    _loadTags();
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountInfo() async {
    final accountState = context.read<AccountCubit>().state;
    final allAccounts = [
      ...accountState.accounts,
      ...accountState.hiddenAccounts,
    ];
    final account = allAccounts.cast<Account?>().firstWhere(
      (a) => a?.id?.uuid == widget.accountId,
      orElse: () => null,
    );

    if (account != null) {
      setState(() {
        _openingBalance = account.openingBalance;
        _openingBalanceDate = account.openingBalanceDate;
      });
    }
  }

  Future<void> _loadTags() async {
    await _tagCubit.loadTags();
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
      final turnovers = await _turnoverRepository.getTurnoversForAccount(
        accountId: UuidValue.fromString(widget.accountId),
      );

      // Paginate in memory
      final startIndex = _currentOffset;
      final endIndex = (_currentOffset + _pageSize).clamp(0, turnovers.length);
      final paginatedTurnovers = turnovers.sublist(startIndex, endIndex);

      // Fetch tags for each turnover
      final allTags = _tagCubit.state.tags;
      final tagMap = {
        for (final tag in allTags)
          if (tag.id != null) tag.id!: tag,
      };

      final newItems = <TurnoverWithTags>[];
      for (final turnover in paginatedTurnovers.reversed) {
        if (turnover.id != null) {
          final tagTurnovers = await _tagTurnoverRepository.getByTurnover(
            turnover.id!,
          );

          final tagTurnoversWithTags = tagTurnovers.map((tt) {
            final tag = tagMap[tt.tagId];
            return TagTurnoverWithTag(
              tagTurnover: tt,
              tag: tag ?? Tag(name: 'Unknown', id: tt.tagId, color: null),
            );
          }).toList();

          newItems.add(
            TurnoverWithTags(
              turnover: turnover,
              tagTurnovers: tagTurnoversWithTags,
            ),
          );
        }
      }

      setState(() {
        _items.addAll(newItems);
        _currentOffset = endIndex;
        _hasMore = endIndex < turnovers.length;
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
    await _loadTags();
    await _loadMore();
  }

  void _showOpeningBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opening Balance'),
        content: const Text(
          'This is the initial balance of the account when it was created. '
          'All turnovers are calculated from this starting point.',
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
        final allAccounts = [...state.accounts, ...state.hiddenAccounts];
        final account = allAccounts.cast<Account?>().firstWhere(
          (a) => a?.id?.uuid == widget.accountId,
          orElse: () => null,
        );

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
                    if (id != null) {
                      TurnoverTagsRoute(
                        turnoverId: id.uuid,
                      ).push(context).then((_) => _refresh());
                    }
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
                        'As of ${_formatDate(_openingBalanceDate!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (_openingBalance != null)
                Text(
                  currency.format(_openingBalance!),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,
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
