import 'package:finanalyzer/comdirect/comdirect_login_page.dart';
import 'package:finanalyzer/comdirect/comdirect_service.dart';
import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:finanalyzer/home_page.dart';
import 'package:finanalyzer/model/account_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';

final dateFormat = DateFormat("dd.MM.yyyy");

class ComdirectRoute extends GoRouteData with $ComdirectRoute {
  const ComdirectRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ComdirectPage();
  }
}

class ComdirectPage extends StatelessWidget {
  const ComdirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text("Comdirect")),
        body: BlocBuilder<ComdirectAuthCubit, ComdirectAuthState>(
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("auth status: ${state.runtimeType}"),
              Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      const ComdirectLoginRoute().go(context);
                    },
                    child: (state is AuthSuccess)
                        ? Text("Manage Session")
                        : const Text("Login"),
                  ),
                  if (state is AuthSuccess) ...[
                    Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        final service = ComdirectService(
                          comdirectAPI: state.api,
                          accountCubit: context.read<AccountCubit>(),
                          turnoverCubit: context.read<TurnoverCubit>(),
                        );
                        final now = Jiffy.now();
                        final start = now.startOf(Unit.month);
                        service.fetchAccountsAndTurnovers(
                          minBookingDate: start.dateTime,
                          maxBookingDate: now.dateTime,
                        );
                      },
                      child: const Text("Load Data"),
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
