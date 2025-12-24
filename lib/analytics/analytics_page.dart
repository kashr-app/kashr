import 'package:kashr/analytics/cubit/analytics_cubit.dart';
import 'package:kashr/analytics/cubit/analytics_state.dart';
import 'package:kashr/analytics/widgets/analytics_chart.dart';
import 'package:kashr/analytics/widgets/tag_filter_section.dart';
import 'package:kashr/home/home_page.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AnalyticsRoute extends GoRouteData with $AnalyticsRoute {
  const AnalyticsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return BlocProvider(
      create: (context) => AnalyticsCubit(
        context.read<TagTurnoverRepository>(),
        context.read<TagRepository>(),
      )..loadData(),
      child: const AnalyticsPage(),
    );
  }
}

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Analytics'),
      ),
      body: BlocBuilder<AnalyticsCubit, AnalyticsState>(
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
                    onPressed: () => context.read<AnalyticsCubit>().loadData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<AnalyticsCubit>().loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tag Trends Over Time',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (state.selectedTagIds.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text('Select tags to view analytics'),
                            ),
                          )
                        else
                          const AnalyticsChart(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const TagFilterSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}
