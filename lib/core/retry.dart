/// Executes [action] and retries it when it throws.
///
/// By default, retries up to [maxAttempts] times using exponential backoff:
///
/// - Attempt 1 -> 500 ms
/// - Attempt 2 -> 1 s
/// - Attempt 3 -> 2 s
/// - Attempt 4 -> 4 s
///
/// A custom retry strategy can be provided via [backoff].
///
/// The optional [shouldRetry] callback determines whether a thrown error
/// should be retried. If it returns `false`, the error is immediately
/// rethrown without any further retry attempts.
///
/// The optional [onRetry] callback is invoked after a failed attempt and
/// before waiting for the next retry.
///
/// Example:
///
/// ```dart
/// final token = await retry(
///   maxAttempts: 3,
///   shouldRetry: (error) => error is DioException,
///   onRetry: (attempt, maxAttempts, error, stackTrace, delay) {
///     log.w(
///       'Attempt $attempt/$maxAttempts failed. Retrying in $delay',
///       error: error,
///       stackTrace: stackTrace,
///     );
///   },
///   action: createToken,
/// );
/// ```
Future<T> retry<T>({
  required Future<T> Function() action,
  int maxAttempts = 3,
  Duration Function(int attempt)? backoff,
  bool Function(Object error)? shouldRetry,
  void Function(
    int attempt,
    int maxAttempts,
    Object error,
    StackTrace stackTrace,
    Duration nextDelay,
  )?
  onRetry,
}) async {
  assert(maxAttempts > 0, 'maxAttempts must be greater than 0');

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e, s) {
      if (shouldRetry != null && !shouldRetry(e)) {
        Error.throwWithStackTrace(e, s);
      }

      if (attempt == maxAttempts) {
        Error.throwWithStackTrace(e, s);
      }

      final delay =
          backoff?.call(attempt) ??
          Duration(milliseconds: 500 * (1 << (attempt - 1)));

      onRetry?.call(attempt, maxAttempts, e, s, delay);

      await Future.delayed(delay);
    }
  }

  throw StateError('Unreachable');
}
