import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/savings/dialogs/delete_savings_dialog.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/savings/model/savings_repository.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking_repository.dart';
import 'package:finanalyzer/savings/services/savings_balance_service.dart';
import 'package:finanalyzer/savings/virtual_booking_dialog.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class SavingsDetailRoute extends GoRouteData with $SavingsDetailRoute {
  final String savingsId;

  const SavingsDetailRoute({required this.savingsId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return _SavingsDetailPageWrapper(savingsId: savingsId);
  }
}

/// Wrapper widget that loads savings by ID and passes it to SavingsDetailPage
class _SavingsDetailPageWrapper extends StatelessWidget {
  final String savingsId;

  const _SavingsDetailPageWrapper({required this.savingsId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Savings?>(
      future: context.read<SavingsRepository>().getById(
        UuidValue.fromString(savingsId),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text(
                snapshot.hasError
                    ? 'Error: ${snapshot.error}'
                    : 'Savings not found',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }

        return SavingsDetailPage(savings: snapshot.data!);
      },
    );
  }
}

/// Represents a transaction that affects the savings balance.
/// Can be either a virtual booking or a tag turnover.
sealed class SavingsTransactionItem {
  DateTime get bookingDate;
  Decimal get amountValue;
  String get amountUnit;
  String? get note;

  String format() => Currency.currencyFrom(amountUnit).format(amountValue);
}

class VirtualBookingItem extends SavingsTransactionItem {
  final SavingsVirtualBooking booking;

  VirtualBookingItem(this.booking);

  @override
  DateTime get bookingDate => booking.bookingDate;

  @override
  Decimal get amountValue => booking.amountValue;

  @override
  String get amountUnit => booking.amountUnit;

  @override
  String? get note => booking.note;
}

class TagTurnoverItem extends SavingsTransactionItem {
  final TagTurnover turnover;

  TagTurnoverItem(this.turnover);

  @override
  DateTime get bookingDate => turnover.bookingDate;

  @override
  Decimal get amountValue => turnover.amountValue;

  @override
  String get amountUnit => turnover.amountUnit;

  @override
  String? get note => turnover.note;
}

class SavingsDetailPage extends StatefulWidget {
  final Savings savings;

  const SavingsDetailPage({required this.savings, super.key});

  @override
  State<SavingsDetailPage> createState() => _SavingsDetailPageState();
}

class _SavingsDetailPageState extends State<SavingsDetailPage> {
  Tag? _tag;
  Decimal? _totalBalance;
  Map<UuidValue, Decimal> _accountBreakdown = {};
  List<SavingsTransactionItem> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tagRepository = context.read<TagRepository>();
      final savingsBalanceService = context.read<SavingsBalanceService>();
      final virtualBookingRepository = context
          .read<SavingsVirtualBookingRepository>();
      final tagTurnoverRepository = context.read<TagTurnoverRepository>();

      final results = await Future.wait([
        tagRepository.getTagById(widget.savings.tagId),
        savingsBalanceService.calculateTotalBalance(widget.savings),
        savingsBalanceService.getAccountBreakdown(widget.savings),
        virtualBookingRepository.getBySavingsId(widget.savings.id!),
        tagTurnoverRepository.getByTag(widget.savings.tagId),
      ]);

      final virtualBookings = results[3] as List<SavingsVirtualBooking>;
      final tagTurnovers = results[4] as List<TagTurnover>;

      // Combine virtual bookings and tag turnovers into transaction items
      final transactions = <SavingsTransactionItem>[
        ...virtualBookings.map((b) => VirtualBookingItem(b)),
        ...tagTurnovers.map((t) => TagTurnoverItem(t)),
      ];

      // Sort by booking date descending (newest first)
      transactions.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));

      setState(() {
        _tag = results[0] as Tag?;
        _totalBalance = results[1] as Decimal;
        _accountBreakdown = results[2] as Map<UuidValue, Decimal>;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addVirtualBooking() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => VirtualBookingDialog(savings: widget.savings),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _confirmDeleteSavings() async {
    if (_tag == null || _totalBalance == null) {
      return;
    }

    final confirmed = await DeleteSavingsDialog.show(
      context,
      savings: widget.savings,
      tag: _tag!,
      currentBalance: _totalBalance!,
    );

    if (!confirmed || !mounted) {
      return;
    }

    try {
      await context.read<SavingsRepository>().delete(widget.savings.id!);

      if (!mounted) return;

      // Navigate back to previous page
      context.pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Savings for "${_tag!.name}" deleted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete savings: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tag?.name ?? 'Savings'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteSavings();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 12),
                    Text('Delete Savings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVirtualBooking,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: const [
            SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, state) {
        final accountById = {
          for (final a in state.accounts)
            if (a.id != null) a.id!: a,
        };
        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 16),
              if (widget.savings.goalValue != null) ...[
                _buildGoalCard(),
                const SizedBox(height: 16),
              ],
              if (_accountBreakdown.isNotEmpty) ...[
                _buildAccountBreakdownCard(accountById),
                const SizedBox(height: 16),
              ],
              _buildHistoryCard(accountById),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Total Balance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              Currency.EUR.format(_totalBalance ?? Decimal.zero),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    if (widget.savings.goalValue == null) return const SizedBox();

    final goalValue = widget.savings.goalValue!;
    final currentBalance = _totalBalance ?? Decimal.zero;
    final progress = goalValue > Decimal.zero
        ? (currentBalance / goalValue).toDouble()
        : 0.0;
    final percentage = (progress * 100).clamp(0, 100).toInt();
    final remaining = goalValue - currentBalance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$percentage%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Goal: ${Currency.EUR.format(goalValue)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (remaining > Decimal.zero)
                      Text(
                        'Remaining: ${Currency.EUR.format(remaining)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountBreakdownCard(Map<UuidValue, Account> accountById) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ..._accountBreakdown.entries.map((entry) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(accountById[entry.key]?.name ?? 'Unknown Account'),
                trailing: Text(
                  Currency.EUR.format(entry.value),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<UuidValue, Account> accountById) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              ..._transactions.map((transaction) {
                return _TransactionTile(
                  transaction: transaction,
                  accountById: accountById,
                  onReload: _loadData,
                  savings: widget.savings,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final SavingsTransactionItem transaction;
  final Map<UuidValue, Account> accountById;
  final VoidCallback onReload;
  final Savings savings;

  const _TransactionTile({
    required this.transaction,
    required this.accountById,
    required this.onReload,
    required this.savings,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.amountValue >= Decimal.zero;
    final theme = Theme.of(context);

    final containerColor = switch (transaction) {
      TagTurnoverItem() => theme.colorScheme.secondaryContainer,
      VirtualBookingItem() => theme.colorScheme.tertiaryContainer,
    };

    final onContainerColor = switch (transaction) {
      TagTurnoverItem() => theme.colorScheme.onSecondaryContainer,
      VirtualBookingItem() => theme.colorScheme.onTertiaryContainer,
    };

    final label = switch (transaction) {
      TagTurnoverItem() => 'Transaction',
      VirtualBookingItem item =>
        accountById[item.booking.accountId]?.name ?? '(Unknown Account)',
    };

    final onTap = switch (transaction) {
      VirtualBookingItem(:final booking) => () async {
        final isChanged = await showDialog<bool>(
          context: context,
          builder: (context) =>
              VirtualBookingDialog(savings: savings, booking: booking),
        );

        if (isChanged == true) {
          onReload();
        }
      },
      TagTurnoverItem(:final turnover) => () async {
        await TurnoverTagsRoute(
          turnoverId: turnover.turnoverId.toString(),
        ).push(context);

        onReload();
      },
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        isPositive ? Icons.add_circle : Icons.remove_circle,
        color: isPositive ? Colors.green : Colors.red,
      ),
      title: Row(
        children: [
          Expanded(child: Text(transaction.format())),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: onContainerColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat.yMMMd().format(transaction.bookingDate)),
          if (transaction.note != null && transaction.note!.isNotEmpty)
            Text(transaction.note!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
