import 'package:finanalyzer/comdirect/comdirect_login_page.dart';
import 'package:finanalyzer/comdirect/comdirect_page.dart';
import 'package:finanalyzer/comdirect/turnover_screen.dart';
import 'package:finanalyzer/home/cubit/dashboard_cubit.dart';
import 'package:finanalyzer/home/cubit/dashboard_state.dart';
import 'package:finanalyzer/home/widgets/cashflow_card.dart';
import 'package:finanalyzer/home/widgets/income_summary_card.dart';
import 'package:finanalyzer/home/widgets/month_selector.dart';
import 'package:finanalyzer/home/widgets/spending_summary_card.dart';
import 'package:finanalyzer/settings/settings_page.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/tags_page.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:finanalyzer/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

part '../_gen/home/home_page.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/app',
  routes: <TypedGoRoute<GoRouteData>>[
    TypedGoRoute<SettingsRoute>(path: 'settings'),
    TypedGoRoute<TagsRoute>(path: 'tags'),
    TypedGoRoute<TurnoversRoute>(
      path: 'turnovers',
      routes: [TypedGoRoute<TurnoverTagsRoute>(path: ':turnoverId/tags')],
    ),
    TypedGoRoute<ComdirectRoute>(
      path: 'comdirect',
      routes: [
        TypedGoRoute<ComdirectLoginRoute>(path: 'login'),
        TypedGoRoute<ComdirectSyncRoute>(path: 'sync'),
      ],
    ),
  ],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return BlocProvider(
      create: (context) => DashboardCubit(
        context.read<TurnoverRepository>(),
        context.read<TagTurnoverRepository>(),
      )..loadMonthData(),
      child: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () => const ComdirectRoute().go(context),
            icon: const Icon(Icons.account_balance),
          ),
          IconButton(
            onPressed: () => const TurnoversRoute().go(context),
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            onPressed: () => const TagsRoute().go(context),
            icon: const Icon(Icons.label),
          ),
          IconButton(
            onPressed: () => const SettingsRoute().go(context),
            icon: const Icon(Icons.settings),
          ),
        ],
        title: const Text('Finanalyze'),
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state.status.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status.isError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? 'An error occurred',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<DashboardCubit>().loadMonthData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<DashboardCubit>().loadMonthData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MonthSelector(
                  selectedYear: state.selectedYear,
                  selectedMonth: state.selectedMonth,
                  onPreviousMonth: () =>
                      context.read<DashboardCubit>().previousMonth(),
                  onNextMonth: () =>
                      context.read<DashboardCubit>().nextMonth(),
                ),
                const SizedBox(height: 16),
                CashflowCard(
                  totalIncome: state.totalIncome,
                  totalExpenses: state.totalExpenses,
                ),
                const SizedBox(height: 16),
                IncomeSummaryCard(
                  totalIncome: state.totalIncome,
                  unallocatedIncome: state.unallocatedIncome,
                  tagSummaries: state.incomeTagSummaries,
                ),
                const SizedBox(height: 16),
                SpendingSummaryCard(
                  totalExpenses: state.totalExpenses,
                  unallocatedExpenses: state.unallocatedExpenses,
                  tagSummaries: state.expenseTagSummaries,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
