import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/core/extensions/bloc_extensions.dart';

class _CounterCubit extends Cubit<int> {
  _CounterCubit(super.initialState);

  void set(int value) => emit(value);
}

void main() {
  group('waitForState', () {
    test('completes with the current state when it already matches', () {
      final cubit = _CounterCubit(1);

      expect(cubit.waitForState((it) => it > 0), completion(1));
    });

    test('completes with the first later state that matches', () {
      final cubit = _CounterCubit(0);

      final waiting = cubit.waitForState((it) => it > 1);
      cubit.set(1);
      cubit.set(2);
      cubit.set(3);

      expect(waiting, completion(2));
    });

    test('stays pending while no state matches', () async {
      final cubit = _CounterCubit(0);
      var completed = false;

      unawaited(
        cubit.waitForState((it) => it > 5).then((_) {
          completed = true;
        }),
      );
      cubit.set(1);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);
    });
  });
}
