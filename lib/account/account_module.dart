import 'package:finanalyzer/account/cubit/account_cubit.dart';
import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/account/services/balance_calculation_service.dart';
import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/turnover/turnover_module.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class AccountModule implements Module {
  late final AccountRepository accountRepository;
  late final BalanceCalculationService balanceCalculationService;

  @override
  late final List<SingleChildWidget> providers;

  AccountModule(TurnoverModule turnoverModule) {
    accountRepository = AccountRepository();
    balanceCalculationService = BalanceCalculationService(
      turnoverModule.turnoverRepository,
      turnoverModule.tagTurnoverRepository,
    );

    providers = [
      Provider.value(value: accountRepository),
      Provider.value(
        value: balanceCalculationService,
      ),
      BlocProvider(
        lazy: false,
        create: (_) =>
            AccountCubit(accountRepository, balanceCalculationService)
              ..loadAccounts(),
      ),
    ];
  }
  @override
  void dispose() {}
}
