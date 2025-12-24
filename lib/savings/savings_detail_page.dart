import 'package:decimal/decimal.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/home/home_page.dart';
import 'package:kashr/savings/cubit/savings_cubit.dart';
import 'package:kashr/savings/cubit/savings_state.dart';
import 'package:kashr/savings/dialogs/delete_savings_dialog.dart';
import 'package:kashr/savings/dialogs/edit_savings_goal_dialog.dart';
import 'package:kashr/savings/model/savings.dart';
import 'package:kashr/savings/model/savings_virtual_booking.dart';
import 'package:kashr/savings/model/savings_virtual_booking_repository.dart';
import 'package:kashr/savings/services/savings_balance_service.dart';
import 'package:kashr/savings/virtual_booking_dialog.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/turnover_tags_page.dart';
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
    return SavingsDetailPage(savingsId: UuidValue.fromString(savingsId));
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
  final UuidValue savingsId;

  const SavingsDetailPage({super.key, required this.savingsId});

  @override
  State<SavingsDetailPage> createState() => _SavingsDetailPageState();
}

class _SavingsDetailPageState extends State<SavingsDetailPage> {
  bool _isLoadingDetails = true;
  Decimal? _totalBalance;
  Map<UuidValue, Decimal> _accountBreakdown = {};
  List<SavingsTransactionItem> _transactions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoadingDetails = true;
      _errorMessage = null;
    });

    try {
      final savings = context
          .read<SavingsCubit>()
          .state
          .savingsById[widget.savingsId];
      if (savings == null) {
        setState(() {
          _errorMessage = 'Savings not found';
          _isLoadingDetails = false;
        });
        return;
      }

      final savingsBalanceService = context.read<SavingsBalanceService>();
      final virtualBookingRepository = context
          .read<SavingsVirtualBookingRepository>();
      final tagTurnoverRepository = context.read<TagTurnoverRepository>();

      final results = await Future.wait([
        savingsBalanceService.calculateTotalBalance(savings),
        savingsBalanceService.getAccountBreakdown(savings),
        virtualBookingRepository.getBySavingsId(savings.id),
        tagTurnoverRepository.getByTag(savings.tagId),
      ]);

      final virtualBookings = results[2] as List<SavingsVirtualBooking>;
      final tagTurnovers = results[3] as List<TagTurnover>;

      final transactions = <SavingsTransactionItem>[
        ...virtualBookings.map((b) => VirtualBookingItem(b)),
        ...tagTurnovers.map((t) => TagTurnoverItem(t)),
      ];

      transactions.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));

      setState(() {
        _totalBalance = results[0] as Decimal;
        _accountBreakdown = results[1] as Map<UuidValue, Decimal>;
        _transactions = transactions;
        _isLoadingDetails = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingDetails = false;
      });
    }
  }

  Future<void> _addVirtualBooking(Savings savings) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => VirtualBookingDialog(savings: savings),
    );

    if (result == true && mounted) {
      _loadDetails();
    }
  }

  Future<void> _editGoal(Savings savings) async {
    final result = await EditSavingsGoalDialog.show(context, savings);

    if (result == true && mounted) {
      _loadDetails();
    }
  }

  Future<void> _confirmDeleteSavings(
    Savings savings,
    Tag tag,
    Decimal totalBalance,
  ) async {
    final confirmed = await DeleteSavingsDialog.show(
      context,
      savings: savings,
      tag: tag,
      currentBalance: totalBalance,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await context.read<SavingsCubit>().deleteSavings(
      widget.savingsId,
    );

    if (!mounted) return;

    if (success) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Savings for "${tag.name}" deleted')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete savings'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavingsCubit, SavingsState>(
      builder: (context, savingsState) {
        final savings = savingsState.savingsById[widget.savingsId];
        if (savings == null) {
          return _buildErrorScaffold('Savings not found');
        }

        return BlocBuilder<TagCubit, TagState>(
          builder: (context, tagState) {
            final tag = tagState.tagById[savings.tagId];
            if (tag == null) {
              return _buildErrorScaffold('Savings tag not found');
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(tag.name),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit_goal') {
                        _editGoal(savings);
                      } else if (value == 'delete' && _totalBalance != null) {
                        _confirmDeleteSavings(savings, tag, _totalBalance!);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit_goal',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined),
                            SizedBox(width: 12),
                            Text('Edit Goal'),
                          ],
                        ),
                      ),
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
                onPressed: () => _addVirtualBooking(savings),
                child: const Icon(Icons.add),
              ),
              body: SafeArea(child: _buildBody(savings)),
            );
          },
        );
      },
    );
  }

  Scaffold _buildErrorScaffold(String error) {
    return Scaffold(
      appBar: AppBar(title: Text('Savings')),
      body: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Text(
          'ERROR: $error',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Savings? savings) {
    if (_isLoadingDetails) {
      return RefreshIndicator(
        onRefresh: _loadDetails,
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
        onRefresh: _loadDetails,
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
                      onPressed: _loadDetails,
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
      builder: (context, accountState) {
        final accountById = accountState.accountById;
        return RefreshIndicator(
          onRefresh: _loadDetails,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 16),
              if (savings?.goalValue != null) ...[
                _buildGoalCard(savings!),
                const SizedBox(height: 16),
              ],
              if (_accountBreakdown.isNotEmpty) ...[
                _buildAccountBreakdownCard(accountById),
                const SizedBox(height: 16),
              ],
              _buildHistoryCard(accountById, savings),
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

  Widget _buildGoalCard(Savings savings) {
    if (savings.goalValue == null) return const SizedBox();

    final goalValue = savings.goalValue!;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Goal Progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  iconSize: 20,
                  onPressed: () => _editGoal(savings),
                  tooltip: 'Edit Goal',
                ),
              ],
            ),
            const SizedBox(height: 8),
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

  Widget _buildHistoryCard(
    Map<UuidValue, Account> accountById,
    Savings? savings,
  ) {
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
                  onReload: _loadDetails,
                  savings: savings!,
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
