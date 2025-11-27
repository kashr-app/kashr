import 'dart:convert';

import 'package:finanalyzer/account/accounts_page.dart';
import 'package:finanalyzer/account/create_account_page.dart';
import 'package:finanalyzer/account/edit_account_page.dart';
import 'package:finanalyzer/analytics/analytics_page.dart';
import 'package:finanalyzer/comdirect/comdirect_login_page.dart';
import 'package:finanalyzer/comdirect/comdirect_page.dart';
import 'package:finanalyzer/core/widgets/period_selector.dart';
import 'package:finanalyzer/home/cubit/dashboard_cubit.dart';
import 'package:finanalyzer/home/cubit/dashboard_state.dart';
import 'package:finanalyzer/home/widgets/cashflow_card.dart';
import 'package:finanalyzer/home/widgets/income_summary_card.dart';
import 'package:finanalyzer/home/widgets/load_bank_data_section.dart';
import 'package:finanalyzer/home/widgets/spending_summary_card.dart';
import 'package:finanalyzer/home/widgets/unallocated_turnovers_section.dart';
import 'package:finanalyzer/settings/settings_page.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
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
    TypedGoRoute<AnalyticsRoute>(path: 'analytics'),
    TypedGoRoute<AccountsRoute>(
      path: 'accounts',
      routes: [
        TypedGoRoute<CreateAccountRoute>(path: 'create'),
        TypedGoRoute<EditAccountRoute>(path: ':accountId/edit'),
      ],
    ),
    TypedGoRoute<TurnoversRoute>(
      path: 'turnovers',
      routes: [TypedGoRoute<TurnoverTagsRoute>(path: ':turnoverId/tags')],
    ),
    TypedGoRoute<ComdirectRoute>(
      path: 'comdirect',
      routes: [TypedGoRoute<ComdirectLoginRoute>(path: 'login')],
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
            onPressed: () => const AccountsRoute().go(context),
            icon: const Icon(Icons.account_balance),
            tooltip: 'Accounts',
          ),
          IconButton(
            onPressed: () => const ComdirectRoute().go(context),
            icon: const Icon(Icons.sync),
            tooltip: 'Comdirect Sync',
          ),
          IconButton(
            onPressed: () => const TurnoversRoute().go(context),
            icon: const Icon(Icons.list_alt),
            tooltip: 'Turnovers',
          ),
          IconButton(
            onPressed: () => const TagsRoute().go(context),
            icon: const Icon(Icons.label),
            tooltip: 'Tags',
          ),
          IconButton(
            onPressed: () => const AnalyticsRoute().go(context),
            icon: const Icon(Icons.analytics),
            tooltip: 'Analytics',
          ),
          IconButton(
            onPressed: () => const SettingsRoute().go(context),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
        title: const Text('Finanalyze'),
      ),
      body: SafeArea(
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            if (state.status.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status.isError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
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
                  PeriodSelector(
                    selectedPeriod: state.selectedPeriod,
                    onPreviousMonth: () =>
                        context.read<DashboardCubit>().previousMonth(),
                    onNextMonth: () =>
                        context.read<DashboardCubit>().nextMonth(),
                  ),
                  const SizedBox(height: 8),
                  const LoadBankDataSection(),
                  const SizedBox(height: 8),
                  CashflowCard(
                    totalIncome: state.totalIncome,
                    totalExpenses: state.totalExpenses,
                  ),
                  const SizedBox(height: 16),
                  UnallocatedTurnoversSection(
                    unallocatedTurnovers: state.unallocatedTurnovers,
                    unallocatedCount: state.unallocatedCount,
                    onRefresh: () =>
                        context.read<DashboardCubit>().loadMonthData(),
                    selectedPeriod: state.selectedPeriod,
                  ),
                  const SizedBox(height: 16),
                  IncomeSummaryCard(
                    totalIncome: state.totalIncome,
                    unallocatedIncome: state.unallocatedIncome,
                    tagSummaries: state.incomeTagSummaries,
                    selectedPeriod: state.selectedPeriod,
                  ),
                  const SizedBox(height: 16),
                  SpendingSummaryCard(
                    totalExpenses: state.totalExpenses,
                    unallocatedExpenses: state.unallocatedExpenses,
                    tagSummaries: state.expenseTagSummaries,
                    selectedPeriod: state.selectedPeriod,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
