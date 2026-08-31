import 'dart:async';

import 'package:flutter/material.dart';

/// How long work may run unannounced before a spinner is worth its flicker.
const _spinnerDelay = Duration(milliseconds: 300);

/// Awaits [work] and puts a modal spinner on screen while the user waits.
///
/// The spinner only appears once the work has been pending for [delay], so
/// work that finishes quickly does not make the screen flash. Use this to
/// honour a tap that arrived a moment too early instead of asking the user
/// to repeat it.
Future<T> showWhileWaiting<T>(
  BuildContext context,
  Future<T> work, {
  Duration delay = _spinnerDelay,
}) async {
  final finishedInTime = await Future.any([
    work.then((_) => true, onError: (_) => true),
    Future.delayed(delay, () => false),
  ]);
  if (finishedInTime || !context.mounted) return work;

  final navigator = Navigator.of(context);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      // Stay on the caller's navigator, like the dialogs that follow it.
      useRootNavigator: false,
      builder: (context) => const _SpinnerDialog(),
    ),
  );
  try {
    return await work;
  } finally {
    if (navigator.mounted) navigator.pop();
  }
}

/// A spinner the user cannot dismiss, because dismissing it would only lose
/// the work it is waiting for.
class _SpinnerDialog extends StatelessWidget {
  const _SpinnerDialog();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
