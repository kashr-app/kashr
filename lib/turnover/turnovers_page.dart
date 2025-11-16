import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/currency.dart';
import 'package:finanalyzer/home_page.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_state.dart';
import 'package:finanalyzer/turnover/turnover_tags_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TurnoversRoute extends GoRouteData with $TurnoversRoute {
  const TurnoversRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TurnoversPage();
  }
}

class TurnoversPage extends StatelessWidget {
  TurnoversPage({super.key});

  final log = Logger();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Turnovers")),
        body: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                final accountId = const Uuid().v4();
                context.read<TurnoverCubit>().addTurnover(
                  Turnover(
                    createdAt: DateTime.now(),
                    accountId: UuidValue.fromString(accountId),
                    amountValue: Decimal.parse("-123.45"),
                    amountUnit: Currency.EUR.name,
                    counterPart: "Hans Wooper",
                    bookingDate: DateTime(2024, 9, 14),
                    purpose: "Some purpose",
                  ),
                );
              },
              child: const Text("Add turnover"),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<TurnoverCubit>().loadAllTurnovers();
              },
              child: const Text("load"),
            ),
            BlocBuilder<TurnoverCubit, TurnoverState>(
              builder: (context, state) =>
                  Text("Count: ${state.turnovers.length}"),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: BlocBuilder<TurnoverCubit, TurnoverState>(
                    builder: (context, state) => Column(
                      children: state.turnovers
                          .map(
                            (it) => ListTile(
                              onTap: () {
                                final id = it.id;
                                if (id == null) {
                                  log.e('turnover has no id');
                                  return;
                                }
                                return TurnoverTagsRoute(
                                  turnoverId: id.uuid,
                                ).go(context);
                              },
                              title: Text(it.counterPart ?? 'n/a'),
                              subtitle: Text(it.formatDate() ?? "not booked"),
                              trailing: Text(
                                it.format(),
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
