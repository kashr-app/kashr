import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/account/model/account_repository.dart';
import 'package:kashr/account/services/balance_calculation_service.dart';
import 'package:kashr/core/module.dart';
import 'package:kashr/turnover/turnover_module.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class AccountModule implements Module {
  late final AccountRepository accountRepository;
  late final BalanceCalculationService balanceCalculationService;

  @override
  late final List<SingleChildWidget> providers;

  AccountModule(TurnoverModule turnoverModule, Logger log) {
    accountRepository = AccountRepository();
    balanceCalculationService = BalanceCalculationService(
      turnoverModule.turnoverRepository,
      turnoverModule.tagTurnoverRepository,
    );

    providers = [
      Provider.value(value: this),
      Provider.value(value: accountRepository),
      Provider.value(value: balanceCalculationService),
      BlocProvider(
        lazy: false,
        create: (_) => AccountCubit(
          accountRepository,
          balanceCalculationService,
          turnoverModule.turnoverRepository,
          log,
        )..loadAccounts(),
      ),
    ];
  }
  @override
  void dispose() {}
}
