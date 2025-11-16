import 'package:finanalyzer/home_page.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ComdirectSyncRoute extends GoRouteData with $ComdirectSyncRoute {
  const ComdirectSyncRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ComdirectSyncPage();
  }
}

class ComdirectSyncPage extends StatelessWidget {
  const ComdirectSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turnovers')),
      body: BlocBuilder<TurnoverCubit, TurnoverState>(
        builder: (context, state) {
          if (state.status.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.status.isSuccess) {
            return ListView.builder(
              itemCount: state.turnovers.length,
              itemBuilder: (context, index) {
                final turnover = state.turnovers[index];
                return ListTile(
                  title: Text(turnover.format()),
                  subtitle: Text(turnover.formatDate() ?? "not booked"),
                );
              },
            );
          } else if (state.status.isError) {
            return Center(child: Text(state.errorMessage ?? 'unknown error'));
          }
          return const Center(child: Text('No turnovers available.'));
        },
      ),
    );
  }
}
