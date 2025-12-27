import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

enum AuthDelayOption {
  disabled,
  immediate,
  thirtySeconds,
  oneMinute,
  twoMinutes;

  String get displayName {
    switch (this) {
      case AuthDelayOption.disabled:
        return 'Disabled';
      case AuthDelayOption.immediate:
        return 'Immediate';
      case AuthDelayOption.thirtySeconds:
        return '30 seconds';
      case AuthDelayOption.oneMinute:
        return '1 minute';
      case AuthDelayOption.twoMinutes:
        return '2 minutes';
    }
  }

  Duration? get duration {
    switch (this) {
      case AuthDelayOption.disabled:
        return null;
      case AuthDelayOption.immediate:
        return Duration.zero;
      case AuthDelayOption.thirtySeconds:
        return const Duration(seconds: 30);
      case AuthDelayOption.oneMinute:
        return const Duration(minutes: 1);
      case AuthDelayOption.twoMinutes:
        return const Duration(minutes: 2);
    }
  }
}

class AuthDelayOptionConverter
    implements JsonConverter<AuthDelayOption, String> {
  const AuthDelayOptionConverter();

  @override
  AuthDelayOption fromJson(String json) {
    return AuthDelayOption.values.firstWhere(
      (e) => e.name == json,
      orElse: () => AuthDelayOption.immediate,
    );
  }

  @override
  String toJson(AuthDelayOption object) => object.name;
}

Future<AuthDelayOption?> showAuthDelayDialog(
  BuildContext context,
  AuthDelayOption current,
) {
  return showModalBottomSheet<AuthDelayOption>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Time before requiring authentication when returning to app',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ...AuthDelayOption.values.map((option) {
              return ListTile(
                title: Text(option.displayName),
                trailing: option == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, option),
              );
            }),
          ],
        ),
      );
    },
  );
}
