import 'package:kashr/home/home_page.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/turnovers_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class AccountAllTurnoversRoute extends GoRouteData
    with $AccountAllTurnoversRoute {
  final String accountId;

  const AccountAllTurnoversRoute({required this.accountId});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TurnoversPage(
      initialFilter: TurnoverFilter(accountId: UuidValue.fromString(accountId)),
    );
  }
}
