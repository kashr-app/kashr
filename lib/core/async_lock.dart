import 'dart:async';

/// A simple async lock to serialize operations.
class AsyncLock {
  Future<void>? _lock;

  /// Executes [operation] exclusively, waiting for any previous operation.
  Future<T> synchronized<T>(Future<T> Function() operation) async {
    final previousLock = _lock;
    final completer = Completer<void>();
    _lock = completer.future;

    try {
      if (previousLock != null) {
        await previousLock;
      }
      return await operation();
    } finally {
      completer.complete();
    }
  }
}
