part of 'download_cubit.dart';

/// What the download is doing right now.
@immutable
sealed class DownloadState {
  /// The scope of the download, as far as it is already decided.
  DownloadRequest? get request => null;

  /// The booking dates being fetched, shown to the user as one range.
  DownloadRange? get range => null;

  const DownloadState();
}

/// Deciding what to do, before anything is shown.
class DownloadStarting extends DownloadState {
  const DownloadStarting();
}

/// No bank is connected yet, so the connect flow takes over.
class DownloadNeedsBank extends DownloadState {
  const DownloadNeedsBank();
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

  const DownloadFailed({
    required this.message,
    required this.range,
    this.request,
  });
}
