import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiffy/jiffy.dart';

enum WeekStartDay {
  monday,
  sunday;

  String get displayName {
    switch (this) {
      case WeekStartDay.monday:
        return 'Monday';
      case WeekStartDay.sunday:
        return 'Sunday';
    }
  }

  StartOfWeek get jiffyStartOfWeek {
    switch (this) {
      case WeekStartDay.monday:
        return StartOfWeek.monday;
      case WeekStartDay.sunday:
        return StartOfWeek.sunday;
    }
  }
}

class WeekStartDayConverter implements JsonConverter<WeekStartDay, String> {
  const WeekStartDayConverter();

  @override
  WeekStartDay fromJson(String json) {
    return WeekStartDay.values.firstWhere(
      (e) => e.name == json,
      orElse: () => WeekStartDay.monday,
    );
  }

  @override
  String toJson(WeekStartDay object) => object.name;
}

Future<WeekStartDay?> showWeekStartDayDialog(
  BuildContext context,
  WeekStartDay current,
) {
  return showModalBottomSheet<WeekStartDay>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select the first day of the week',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ...WeekStartDay.values.map((option) {
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
