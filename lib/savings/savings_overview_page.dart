import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home/home_page.dart';
import 'package:finanalyzer/savings/create_savings_dialog.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/savings/model/savings_repository.dart';
import 'package:finanalyzer/savings/savings_detail_page.dart';
import 'package:finanalyzer/savings/services/savings_balance_service.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SavingsRoute extends GoRouteData with $SavingsRoute {
  const SavingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SavingsOverviewPage();
  }
}

class SavingsOverviewPage extends StatefulWidget {
  const SavingsOverviewPage({super.key});

  @override
  State<SavingsOverviewPage> createState() => _SavingsOverviewPageState();
}

class _SavingsOverviewPageState extends State<SavingsOverviewPage> {
  List<Savings> _savings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavings();
  }

  Future<void> _loadSavings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final savings = await context.read<SavingsRepository>().getAll();
      setState(() {
        _savings = savings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createSavings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateSavingsDialog(),
    );

    if (result == true) {
      _loadSavings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSavings,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return RefreshIndicator(
        onRefresh: _loadSavings,
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
        onRefresh: _loadSavings,
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
                      onPressed: _loadSavings,
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

    if (_savings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSavings,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height - 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No savings yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a savings goal to get started',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _createSavings,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Savings'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _savings.length,
        itemBuilder: (context, index) {
          final savings = _savings[index];
          return _SavingsCard(
            savings: savings,
            onTap: () => _navigateToDetail(savings),
          );
        },
      ),
    );
  }

  void _navigateToDetail(Savings savings) {
    SavingsDetailRoute(
      savingsId: savings.id!.uuid,
    ).push(context).then((_) => _loadSavings());
  }
}

class _SavingsCard extends StatelessWidget {
  final Savings savings;
  final VoidCallback onTap;

  const _SavingsCard({required this.savings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final savingsBalanceService = context.read<SavingsBalanceService>();
    final tagRepository = context.read<TagRepository>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tag name and balance
              FutureBuilder(
                future: Future.wait([
                  tagRepository.getTagById(savings.tagId),
                  savingsBalanceService.calculateTotalBalance(savings),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 24,
                      child: Center(
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final tag = snapshot.data![0] as Tag?;
                  final balance = snapshot.data![1] as Decimal;
                  final tagName = tag?.name ?? 'Unknown';
                  final tagColor = tag?.color != null
                      ? Color(int.parse(tag!.color!.replaceFirst('#', '0xFF')))
                      : Theme.of(context).colorScheme.primary;

                  return Row(
                    children: [
                      // Tag indicator
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tagColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tag name and balance
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tagName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Currency.EUR.format(balance),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: tagColor,
                                  ),
                            ),
                          ],
                        ),
                      ),

                      // Goal progress (if set)
                      if (savings.goalValue != null) ...[
                        const SizedBox(width: 8),
                        _GoalProgressIndicator(
                          balance: balance,
                          goalValue: savings.goalValue!,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalProgressIndicator extends StatelessWidget {
  final Decimal balance;
  final Decimal goalValue;

  const _GoalProgressIndicator({
    required this.balance,
    required this.goalValue,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goalValue > Decimal.zero
        ? (balance / goalValue).toDouble()
        : 0.0;
    final percentage = (progress * 100).clamp(0, 100).toInt();

    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '$percentage%',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
