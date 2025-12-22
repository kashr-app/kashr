import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/savings/cubit/savings_cubit.dart';
import 'package:finanalyzer/savings/listeners/savings_tag_listener.dart';
import 'package:finanalyzer/savings/model/savings_repository.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking_repository.dart';
import 'package:finanalyzer/savings/services/savings_balance_service.dart';
import 'package:finanalyzer/turnover/turnover_module.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Module for the savings feature.
///
/// Handles initialization and registration of savings-related functionality
/// with other modules.
class SavingsModule implements Module {
  @override
  late final List<SingleChildWidget> providers;

  SavingsModule(TurnoverModule turnoverModule, Logger log) {
    final savingsRepository = SavingsRepository();
    final savingsVirtualBookingRepository = SavingsVirtualBookingRepository();
    final savingsBalanceService = SavingsBalanceService(
      turnoverModule.tagTurnoverRepository,
      savingsVirtualBookingRepository,
      savingsRepository,
    );
    final savingsCubit = SavingsCubit(
      savingsRepository,
      savingsBalanceService,
      log,
    )..loadAllSavings();

    providers = [
      Provider.value(value: this),
      Provider.value(value: savingsRepository),
      Provider.value(value: savingsVirtualBookingRepository),
      Provider.value(value: savingsBalanceService),
      BlocProvider.value(value: savingsCubit),
    ];

    turnoverModule.registerTagListener(SavingsTagListener(savingsCubit));
  }

  @override
  void dispose() {}
}
