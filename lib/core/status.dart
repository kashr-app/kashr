enum Status {
  initial,
  loading,
  success,
  error;

  bool get isInitial => this == initial;

  bool get isLoading => this == loading;

  bool get isSuccess => this == success;

  bool get isError => this == error;

  /// Finds the least successful [Status] in [status]
  /// using this comparison: [error] < [loading] < [initial] < [success]
  static Status? findLeastSuccessful(Iterable<Status> status) {
    if (status.isEmpty) {
      return null;
    }
    final countByStatus = {};
    for (var s in status) {
      if (s.isError) {
        return Status.error;
      }
      countByStatus[s] = (countByStatus[s] ?? 0) + 1;
    }
    if ((countByStatus[Status.loading] ?? 0) > 0) {
      return Status.loading;
    }
    if ((countByStatus[Status.initial] ?? 0) > 0) {
      return Status.initial;
    }
    return Status.success;
  }
}
