import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking_repository.dart';
import 'package:finanalyzer/savings/services/savings_balance_service.dart';
import 'package:finanalyzer/savings/virtual_booking_dialog.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Represents a transaction that affects the savings balance.
/// Can be either a virtual booking or a tag turnover.
sealed class TransactionItem {
  DateTime get bookingDate;
  Decimal get amountValue;
  String get amountUnit;
  String? get note;

  String format() => Currency.currencyFrom(amountUnit).format(amountValue);
}

class VirtualBookingItem extends TransactionItem {
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

class TagTurnoverItem extends TransactionItem {
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
  List<TransactionItem> _transactions = [];
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
      final transactions = <TransactionItem>[
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tag?.name ?? 'Savings'),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBalanceCard(),
        const SizedBox(height: 16),
        if (widget.savings.goalValue != null) ...[
          _buildGoalCard(),
          const SizedBox(height: 16),
        ],
        if (_accountBreakdown.isNotEmpty) ...[
          _buildAccountBreakdownCard(),
          const SizedBox(height: 16),
        ],
        _buildHistoryCard(),
      ],
    );
  }

  Widget _buildBalanceCard() {
    final tagColor = _tag?.color != null
        ? Color(int.parse(_tag!.color!.replaceFirst('#', '0xFF')))
        : Theme.of(context).colorScheme.primary;

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
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: tagColor,
              ),
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

  Widget _buildAccountBreakdownCard() {
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
              return BlocBuilder<AccountCubit, dynamic>(
                builder: (context, state) {
                  final account = (state.accounts as List<Account>)
                      .where((a) => a.id == entry.key)
                      .firstOrNull;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text(account?.name ?? 'Unknown Account'),
                    trailing: Text(
                      Currency.EUR.format(entry.value),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
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
                  onDelete: transaction is VirtualBookingItem
                      ? () => _deleteBooking(transaction.booking)
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBooking(SavingsVirtualBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Adjustment'),
        content: Text(
          'Are you sure you want to delete this adjustment of ${booking.format()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<SavingsVirtualBookingRepository>().delete(
          booking.id!,
        );
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback? onDelete;

  const _TransactionTile({required this.transaction, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.amountValue >= Decimal.zero;
    final isVirtualBooking = transaction is VirtualBookingItem;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isPositive ? Icons.add_circle : Icons.remove_circle,
        color: isPositive ? Colors.green : Colors.red,
      ),
      title: Row(
        children: [
          Expanded(child: Text(transaction.format())),
          if (!isVirtualBooking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Transaction',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: BlocBuilder<AccountCubit, dynamic>(
                builder: (context, state) {
                  final accountId = (transaction as VirtualBookingItem).booking.accountId;
                  final account = (state.accounts as List<Account>)
                      .where((a) => a.id == accountId)
                      .firstOrNull;
                  return Text(
                    account?.name ?? '(Unknown Account)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat.yMMMd().format(transaction.bookingDate)),
          if (transaction.note != null && transaction.note!.isNotEmpty)
            Text(
              transaction.note!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete',
            )
          : null,
    );
  }
}
