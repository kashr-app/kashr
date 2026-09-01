import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/comdirect/comdirect_api.dart';
import 'package:kashr/comdirect/comdirect_model.dart';
import 'package:kashr/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:kashr/ingest/cubit/download_cubit.dart';
import 'package:kashr/ingest/download_progress.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:logger/logger.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

/// An auth cubit that is already signed in.
///
/// Lets a download test start at the point the credentials and the
/// confirmation in the banking app are already behind it, which is the only
/// part of the flow that cannot run without a real bank.
class _SignedInAuthCubit extends ComdirectAuthCubit {
  _SignedInAuthCubit(super.log);

  void seedSuccess() {
    final dio = Dio();
    emit(AuthSuccess(_token, ComdirectAPI(dio), dio));
  }
}

final _token = TokenDTO(
  accessToken: 'access',
  tokenType: 'bearer',
  refreshToken: 'refresh',
  expiresIn: 599,
  scope: 'scope',
  kdnr: 'kdnr',
  bpid: 1,
  kontaktId: 1,
);

/// A download that does nothing but say what it is doing.
class _ScriptedIngestor implements DataIngestor {
  final List<DownloadProgress> script;

  _ScriptedIngestor(this.script);

  @override
  Future<DataIngestResult> ingest(
    DownloadRequest request,
    DownloadCancellation cancellation,
    DownloadProgressSink progress,
  ) async {
    for (final step in script) {
      cancellation.throwIfCancelled();
      progress.report(step);
    }
    return const DataIngestResult.success(
      newCount: 0,
      updatedCount: 0,
      autoMatchedCount: 0,
      unmatchedCount: 0,
      downloadedAccountIds: [],
    );
  }
}

/// A download that reports once more after the user has already stopped it.
///
/// The real thing can do this: a stop is only noticed at the next safe point,
/// so a report already on its way still arrives.
class _ReportsAfterStopIngestor implements DataIngestor {
  final void Function() stop;

  _ReportsAfterStopIngestor(this.stop);

  @override
  Future<DataIngestResult> ingest(
    DownloadRequest request,
    DownloadCancellation cancellation,
    DownloadProgressSink progress,
  ) async {
    progress.report(const DownloadProgress.fetching(subject: 'Girokonto'));
    stop();
    progress.report(const DownloadProgress.saving(total: 3));
    cancellation.throwIfCancelled();
    return const DataIngestResult.error(ResultStatus.otherError);
  }
}

void main() {
  useInMemoryDatabase();

  late TestApp app;
  late Logger log;
  late _SignedInAuthCubit authCubit;
  late AccountCubit accountCubit;

  setUp(() {
    app = TestApp();
    addTearDown(app.dispose);
    log = app.log;

    authCubit = _SignedInAuthCubit(log);
    addTearDown(authCubit.close);
    authCubit.seedSuccess();

    accountCubit = AccountCubit(
      app.accountRepository,
      app.balanceService,
      app.turnoverRepository,
      log,
    );
    addTearDown(accountCubit.close);
  });

  DownloadCubit downloadCubit(DataIngestor ingestor) {
    final cubit = DownloadCubit(
      log,
      authCubit: authCubit,
      accountCubit: accountCubit,
      createIngestor: (_) => ingestor,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('carries what the source says through to the running state', () async {
    // Each step changes the phase, which is what the sink never holds back.
    final cubit = downloadCubit(
      _ScriptedIngestor([
        const DownloadProgress.findingAccounts(done: 2, total: 2),
        const DownloadProgress.fetching(subject: 'Girokonto', done: 50),
        const DownloadProgress.saving(total: 50),
        const DownloadProgress.matching(done: 0, total: 50),
      ]),
    );
    final seen = <DownloadProgress?>[];
    final subscription = cubit.stream
        .where((it) => it is DownloadRunning)
        .listen((it) => seen.add((it as DownloadRunning).progress));
    addTearDown(subscription.cancel);

    await cubit.startWithDepth(DownloadDepth.threeMonths);
    await pumpEventQueue();

    expect(seen, [
      null,
      const DownloadProgress.findingAccounts(done: 2, total: 2),
      const DownloadProgress.fetching(subject: 'Girokonto', done: 50),
      const DownloadProgress.saving(total: 50),
      const DownloadProgress.matching(done: 0, total: 50),
    ]);
    expect(cubit.state, isA<DownloadFinished>());
  });

  test(
    'never says it is downloading again after the user stopped it',
    () async {
      late DownloadCubit cubit;
      cubit = downloadCubit(_ReportsAfterStopIngestor(() => cubit.cancel()));
      final seen = <DownloadState>[];
      final subscription = cubit.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      await cubit.startWithDepth(DownloadDepth.threeMonths);
      await pumpEventQueue();

      final stoppedAt = seen.indexWhere((it) => it is DownloadStopping);
      expect(stoppedAt, isNonNegative);
      expect(seen.skip(stoppedAt), isNot(contains(isA<DownloadRunning>())));
      expect(cubit.state, isA<DownloadIdle>());
    },
  );
}
