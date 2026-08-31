import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/comdirect/comdirect_service.dart';
import 'package:kashr/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:kashr/core/module.dart';
import 'package:kashr/ingest/cubit/download_cubit.dart';
import 'package:kashr/turnover/turnover_module.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Wires the one download the whole app shares.
///
/// Must be registered after the account and bank modules, whose cubits it
/// reads.
class IngestModule implements Module {
  @override
  late final List<SingleChildWidget> providers;

  IngestModule(TurnoverModule turnoverModule, Logger log) {
    providers = [
      Provider.value(value: this),
      BlocProvider(
        create: (context) {
          final accountCubit = context.read<AccountCubit>();
          return DownloadCubit(
            log,
            authCubit: context.read<ComdirectAuthCubit>(),
            accountCubit: accountCubit,
            createIngestor: (api) => ComdirectService(
              log,
              comdirectAPI: api,
              accountCubit: accountCubit,
              turnoverService: turnoverModule.turnoverService,
              matchingService: turnoverModule.turnoverMatchingService,
            ),
          );
        },
      ),
    ];
  }

  @override
  void dispose() {}
}
