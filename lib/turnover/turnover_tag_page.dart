import 'package:finanalyzer/home_page.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class TurnoverTagRoute extends GoRouteData with $TurnoverTagRoute {
  final String turnoverId;
  const TurnoverTagRoute({required this.turnoverId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TurnoverTagPage(turnoverId: turnoverId);
  }
}

class TurnoverTagPage extends StatelessWidget {
  final String turnoverId;
  const TurnoverTagPage({required this.turnoverId, super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Turnover Tags")),
        body: BlocBuilder<TurnoverCubit, TurnoverState>(
          builder: (context, state) {
            final id = UuidValue.fromString(turnoverId);
            final turnover = state.turnovers.firstWhere((it) => it.id == id);
            return Column(
              children: [
                Text(turnover.counterPart ?? '(?)'),
                Text(turnover.format()),
              ],
            );
          },
        ),
      ),
    );
  }
}
