part of 'download_cubit.dart';

/// What a state means to the button and the sheet.
enum DownloadActivity {
  /// Work is in flight. The button says so, even with the sheet closed.
  working,

  /// Nothing is happening, but the download is not over: it needs an answer
  /// that only the sheet can collect.
  waitingForUser,

  /// The download is over. Opening the sheet starts a new one.
  settled,
}

/// What the download is doing right now.
@immutable
sealed class DownloadState {
  /// The scope of the download, as far as it is already decided.
  DownloadRequest? get request => null;

  /// The booking dates being fetched, shown to the user as one range.
  DownloadRange? get range => null;

  /// How far along the download is, in the only three steps that anything
  /// outside this file needs to tell apart.
  DownloadActivity get activity => switch (this) {
    DownloadStarting() ||
    DownloadConnecting() ||
    DownloadWaitingForConfirmation() ||
    DownloadRunning() => DownloadActivity.working,
    DownloadNeedsBank() ||
    DownloadChoosingDepth() => DownloadActivity.waitingForUser,
    DownloadIdle() ||
    DownloadNoBankConnected() ||
    DownloadFinished() ||
    DownloadFailed() => DownloadActivity.settled,
  };

  const DownloadState();
}

/// Nothing has been downloaded yet, and nothing is being downloaded.
class DownloadIdle extends DownloadState {
  const DownloadIdle();
}

/// Deciding what to do, before anything is shown.
class DownloadStarting extends DownloadState {
  const DownloadStarting();
}

/// No bank is connected yet, so the connect flow takes over.
///
/// Passing through, the user is already on their way to the login page.
class DownloadNeedsBank extends DownloadState {
  const DownloadNeedsBank();
}

/// The user came back from the connect flow without connecting a bank.
///
/// A state of its own because waiting on the user must never look like the
/// app is busy; this is where the download stops and offers a way on.
class DownloadNoBankConnected extends DownloadState {
  const DownloadNoBankConnected();
}

/// The first ever download has no cursor to continue from.
class DownloadChoosingDepth extends DownloadState {
  const DownloadChoosingDepth();
}

/// Logging in.
class DownloadConnecting extends DownloadState {
  @override
  final DownloadRange range;

  final String? message;

  const DownloadConnecting({required this.range, this.message});
}

/// Waiting for the user to confirm the login in their banking app.
class DownloadWaitingForConfirmation extends DownloadState {
  @override
  final DownloadRange range;

  const DownloadWaitingForConfirmation({required this.range});
}

/// Fetching accounts and transactions.
class DownloadRunning extends DownloadState {
  @override
  final DownloadRequest request;

  @override
  final DownloadRange range;

  const DownloadRunning({required this.request, required this.range});
}

/// The data has arrived.
class DownloadFinished extends DownloadState {
  @override
  final DownloadRequest request;

  @override
  final DownloadRange range;

  final DataIngestResult result;

  const DownloadFinished({
    required this.request,
    required this.range,
    required this.result,
  });
}

/// Something went wrong that the app could not have predicted.
class DownloadFailed extends DownloadState {
  @override
  final DownloadRequest? request;

  @override
  final DownloadRange range;

  final String message;

  /// What went wrong, so the sheet can offer the way out that fits.
  final DownloadFailureReason reason;

  const DownloadFailed({
    required this.message,
    required this.range,
    required this.reason,
    this.request,
  });
}
