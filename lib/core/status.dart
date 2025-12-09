import 'package:flutter/material.dart';

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

  void snack(BuildContext context, String msg) {
    snack2(ScaffoldMessenger.of(context), Theme.of(context), msg);
  }

  void snack2(
    ScaffoldMessengerState scaffoldMessenger,
    ThemeData theme,
    String msg, {
    SnackBarAction? action,
  }) {
    final [colorBg, color, actionColor] = switch (this) {
      Status.initial => [
        theme.colorScheme.surfaceContainer,
        theme.colorScheme.onSurface,
        theme.colorScheme.primary,
      ],
      Status.loading => [
        theme.colorScheme.surfaceContainer,
        theme.colorScheme.onSurface,
        theme.colorScheme.primary,
      ],
      Status.success => [
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
        theme.colorScheme.primary,
      ],
      Status.error => [
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        theme.colorScheme.error,
      ],
    };
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
        backgroundColor: colorBg,
        action: action != null
            ? SnackBarAction(
                label: action.label,
                onPressed: action.onPressed,
                textColor: actionColor,
              )
            : null,
      ),
    );
  }
}
