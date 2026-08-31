import 'package:flutter_bloc/flutter_bloc.dart';

/// Waiting for a state instead of turning an early caller away.
extension StateWait<S> on BlocBase<S> {
  /// Completes with the first state that satisfies [test].
  ///
  /// Completes right away when the current state already satisfies it, so
  /// callers can await this without knowing whether work is in flight.
  ///
  /// Never completes when no such state arrives, and fails when the bloc is
  /// closed before one does. Only await this on a bloc that outlives the
  /// caller.
  Future<S> waitForState(bool Function(S state) test) =>
      test(state) ? Future.value(state) : stream.firstWhere(test);
}
