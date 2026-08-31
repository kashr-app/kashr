import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/comdirect/comdirect_api.dart';
import 'package:kashr/comdirect/comdirect_model.dart';
import 'package:kashr/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:kashr/ingest/download_range.dart';
import 'package:kashr/ingest/ingest.dart';
import 'package:logger/logger.dart';
import 'package:meta/meta.dart';

part 'download_state.dart';

/// Builds the ingestor that downloads from an authenticated bank connection.
typedef IngestorFactory = DataIngestor Function(ComdirectAPI api);

/// Drives one download from the tap on the download button to the result.
///
/// Lives as long as the app, not as long as the sheet: a download has to
/// survive the sheet being dismissed, and there must only ever be one of it.
///
/// Everything the user is asked is asked here, and there is only one such
/// question: how far back the very first download should reach. Afterwards
/// each account's own download cursor answers it.
class DownloadCubit extends Cubit<DownloadState> {
  final ComdirectAuthCubit _authCubit;
  final AccountCubit _accountCubit;
  final IngestorFactory _createIngestor;
  final Logger log;

  /// Guards against a stray tap starting a second, concurrent download.
  bool _isRunning = false;

  DownloadCubit(
    this.log, {
    required ComdirectAuthCubit authCubit,
    required AccountCubit accountCubit,
    required IngestorFactory createIngestor,
  }) : _authCubit = authCubit,
       _accountCubit = accountCubit,
       _createIngestor = createIngestor,
       super(const DownloadIdle());

  /// Starts a download unless one is already under way.
  ///
  /// Opening the sheet again has to show the download that is running, or
  /// the question it is stuck on, rather than begin a second one.
  Future<void> startIfIdle() async {
    if (state.activity != DownloadActivity.settled) return;
    await start();
  }

  /// Starts the download, asking only what cannot be derived.
  Future<void> start() async {
    _safeEmit(const DownloadStarting());
    if (!await Credentials.hasStored()) {
      log.i('No bank connected yet, offering the connect flow.');
      _safeEmit(const DownloadNeedsBank());
      return;
    }
    await _startConnected();
  }

  /// Picks the download back up after the connect flow.
  ///
  /// When the user left without connecting, the download stops here rather
  /// than waiting for something that is never going to arrive.
  Future<void> continueAfterConnect({required bool isConnected}) async {
    if (!isConnected) {
      log.i('Left the connect flow without a bank, stopping the download.');
      _safeEmit(const DownloadNoBankConnected());
      return;
    }
    await _startConnected();
  }

  /// Runs the first download with the depth the user picked.
  Future<void> startWithDepth(DownloadDepth depth) async {
    final today = DateTime.now();
    await _run(DownloadRequest.upTo(today, startDate: depth.startDate(today)));
  }

  /// Re-runs the download from [startDate] for every account.
  ///
  /// Used when the user widens the range by hand; the cursors are ignored so
  /// that the requested history is actually fetched.
  Future<void> downloadFrom(DateTime startDate) async {
    await _run(
      DownloadRequest.upTo(
        DateTime.now(),
        startDate: startDate,
        ignoreCursors: true,
      ),
    );
  }

  /// Retries after a failure, with the same scope as before.
  Future<void> retry() async {
    final request = state.request;
    if (request == null) {
      await start();
      return;
    }
    await _run(request);
  }

  Future<void> _startConnected() async {
    final accounts = _accountCubit.state.accountById.values;
    if (isFirstDownload(accounts)) {
      _safeEmit(const DownloadChoosingDepth());
      return;
    }

    final today = DateTime.now();
    await _run(
      DownloadRequest.upTo(
        today,
        startDate: oldestDownloadCursor(accounts) ?? today,
      ),
    );
  }

  Future<void> _run(DownloadRequest request) async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      await _attempt(request, allowRelogin: true);
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _attempt(
    DownloadRequest request, {
    required bool allowRelogin,
  }) async {
    final range = unionDownloadRange(
      _accountCubit.state.accountById.values,
      request: request,
    );

    final api = await _authenticate(range: range, force: !allowRelogin);
    if (api == null) return;

    _safeEmit(DownloadRunning(request: request, range: range));

    final result = await _ingest(_createIngestor(api), request);

    switch (result.status) {
      case ResultStatus.success:
        _safeEmit(
          DownloadFinished(request: request, range: range, result: result),
        );
      case ResultStatus.unauthed:
        if (allowRelogin) {
          log.i('Download was rejected as unauthenticated, logging in again.');
          await _attempt(request, allowRelogin: false);
          return;
        }
        _safeEmit(
          DownloadFailed(
            request: request,
            range: range,
            reason: DownloadFailureReason.unknown,
            message: 'The bank ended the session. Please try again.',
          ),
        );
      case ResultStatus.otherError:
        _safeEmit(
          DownloadFailed(
            request: request,
            range: range,
            reason: DownloadFailureReason.unknown,
            message: result.errorMessage ?? 'The download did not finish.',
          ),
        );
    }
  }

  /// Downloads, and on success records how far each account is caught up so
  /// the next download can continue from there.
  Future<DataIngestResult> _ingest(
    DataIngestor ingestor,
    DownloadRequest request,
  ) async {
    final result = await ingestor.ingest(request);
    if (result.status == ResultStatus.success) {
      await _accountCubit.advanceDownloadCursors(
        result.downloadedAccountIds,
        request.maxBookingDate,
      );
    }
    return result;
  }

  /// Returns an authenticated API, logging in when needed.
  ///
  /// Emits the connection progress, including the wait for the confirmation
  /// in the banking app, so the sheet can show what is happening.
  Future<ComdirectAPI?> _authenticate({
    required DownloadRange range,
    required bool force,
  }) async {
    final authState = _authCubit.state;
    if (!force && authState is AuthSuccess) return authState.api;

    final credentials = await Credentials.load();
    if (credentials == null) {
      log.w('Stored credentials could not be unlocked.');
      _safeEmit(
        DownloadFailed(
          range: range,
          reason: DownloadFailureReason.badCredentials,
          message: 'Kashr could not unlock your saved credentials.',
        ),
      );
      return null;
    }

    _safeEmit(DownloadConnecting(range: range));

    final subscription = _authCubit.stream.listen(
      (it) => _onAuthState(it, range),
    );
    try {
      await _authCubit.login(credentials);
    } finally {
      await subscription.cancel();
    }

    final result = _authCubit.state;
    if (result is AuthSuccess) return result.api;

    _safeEmit(
      DownloadFailed(
        range: range,
        message: result is AuthError ? result.message : 'Login failed.',
        reason: result is AuthError
            ? result.reason
            : DownloadFailureReason.unknown,
      ),
    );
    return null;
  }

  void _onAuthState(ComdirectAuthState authState, DownloadRange range) {
    switch (authState) {
      case AuthLoading():
        _safeEmit(DownloadConnecting(range: range, message: authState.message));
      case WaitingForTANConfirmation():
        _safeEmit(DownloadWaitingForConfirmation(range: range));
      case AuthInitial():
      case AuthError():
      case AuthSuccess():
        break;
    }
  }

  /// The download outlives the sheet, so it can still be running when the
  /// app tears the cubit down.
  void _safeEmit(DownloadState state) {
    if (isClosed) return;
    emit(state);
  }
}
