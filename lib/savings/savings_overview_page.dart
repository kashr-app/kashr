import 'package:decimal/decimal.dart';
import 'package:kashr/core/currency.dart';
import 'package:kashr/home/home_page.dart';
import 'package:kashr/savings/create_savings_dialog.dart';
import 'package:kashr/savings/cubit/savings_cubit.dart';
import 'package:kashr/savings/cubit/savings_state.dart';
import 'package:kashr/savings/model/savings.dart';
import 'package:kashr/savings/savings_detail_page.dart';
import 'package:kashr/theme.dart';
import 'package:kashr/turnover/cubit/tag_cubit.dart';
import 'package:kashr/turnover/cubit/tag_state.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
  @override
  void initState() {
    super.initState();
    context.read<SavingsCubit>().loadAllSavings();
  }

  Future<void> _createSavings() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateSavingsDialog(),
    );

    if (result == true && mounted) {
      // Data will be automatically reloaded by the dialog through the cubit
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
    return BlocBuilder<SavingsCubit, SavingsState>(
      builder: (context, state) {
        if (state.status.isLoading) {
          return RefreshIndicator(
            onRefresh: () => context.read<SavingsCubit>().loadAllSavings(),
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

        if (state.status.isError) {
          return RefreshIndicator(
            onRefresh: () => context.read<SavingsCubit>().loadAllSavings(),
            child: ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
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
                              context.read<SavingsCubit>().loadAllSavings(),
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

        if (state.savingsById.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => context.read<SavingsCubit>().loadAllSavings(),
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

        final allSavings = state.savingsById.values.toList();
        return RefreshIndicator(
          onRefresh: () => context.read<SavingsCubit>().loadAllSavings(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allSavings.length,
            itemBuilder: (context, index) {
              final savings = allSavings[index];
              final balance = state.balancesBySavingsId[savings.id];
              return BlocBuilder<TagCubit, TagState>(
                builder: (context, tagState) {
                  final tag = tagState.tagById[savings.tagId];
                  return _SavingsCard(
                    savings: savings,
                    tag: tag,
                    balance: balance,
                    onTap: () => _navigateToDetail(savings),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _navigateToDetail(Savings savings) {
    SavingsDetailRoute(savingsId: savings.id.uuid).push(context);
  }
}

class _SavingsCard extends StatelessWidget {
  final Savings savings;
  final Tag? tag;
  final Decimal? balance;
  final VoidCallback onTap;

  const _SavingsCard({
    required this.savings,
    required this.tag,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tagName = tag?.name ?? 'Unknown';
    final tagColor = tag?.color != null
        ? Color(int.parse(tag!.color!.replaceFirst('#', '0xFF')))
        : Theme.of(context).colorScheme.primary;
    final currentBalance = balance ?? Decimal.zero;

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
              Row(
                children: [
                  // Tag indicator
                  Container(
                    width: 4,
                    height: 50,
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
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Currency.currencyFrom(
                            savings.goalUnit ?? Currency.EUR.name,
                          ).format(currentBalance),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).decimalColor(currentBalance),
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Goal progress (if set)
                  if (savings.goalValue != null) ...[
                    const SizedBox(width: 8),
                    _GoalProgressIndicator(
                      balance: currentBalance,
                      goalValue: savings.goalValue!,
                    ),
                  ],
                ],
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
