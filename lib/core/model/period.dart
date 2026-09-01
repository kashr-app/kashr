import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiffy/jiffy.dart';
import 'package:kashr/core/booking_date_json_converter.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/core/model/booking_date.dart';

part '../../_gen/core/model/period.freezed.dart';
part '../../_gen/core/model/period.g.dart';

@freezed
abstract class Period with _$Period {
  const Period._();

  const factory Period(
    PeriodType type, {
    @BookingDateJsonConverter() required BookingDate startInclusive,
    @BookingDateJsonConverter() required BookingDate endExclusive,
  }) = _Period;

  factory Period.now(PeriodType type) => Period.of(BookingDate.today(), type);

  factory Period.of(BookingDate day, PeriodType type) {
    final startInclusive = type.startOf(day);
    return Period(
      type,
      startInclusive: startInclusive,
      endExclusive: type.startOf(startInclusive.addPeriod(type)),
    );
  }

  factory Period.fromJson(Map<String, dynamic> json) => _$PeriodFromJson(json);

  bool contains(BookingDate day) =>
      !day.isBefore(startInclusive) && day.isBefore(endExclusive);

  Period add({int delta = 1}) =>
      Period.of(startInclusive.addPeriod(type, delta: delta), type);

  String format() {
    final start = startInclusive;
    final lastDay = endExclusive.addDays(-1);
    return switch (type) {
      PeriodType.week =>
        '${start.year} ${start.day}.${start.month}'
            '-${lastDay.day}.${lastDay.month}',
      PeriodType.month => '${start.year} ${_getMonthName(start.month)}',
      PeriodType.year => '${start.year}',
    };
  }

  /// Average distributed evenly across the full period.
  ///
  /// Use this for fixed/predictable expenses (rent, subscriptions, insurance)
  /// where the cost is known upfront regardless of when in the period you are.
  ///
  /// Example: €800 rent in a month = €200/week consistently.
  (Decimal avg, String avgPerUnit) avgPerFullPeriod(Decimal amount) {
    const int scale = decimalScaleFactor;
    const int daysPerWeek = 7;
    const double weeksPerMonth = 4.33;
    const int monthsPerYear = 12;

    final (scaledUnits, unit) = switch (type) {
      PeriodType.week => (daysPerWeek * scale, 'day'),
      PeriodType.month => ((weeksPerMonth * scale).round(), 'week'),
      PeriodType.year => (monthsPerYear * scale, 'month'),
    };

    final avg = (amount * Decimal.fromInt(scale) / Decimal.fromInt(scaledUnits))
        .toDecimal(scaleOnInfinitePrecision: 2);

    return (avg, unit);
  }
}

enum PeriodType {
  week,
  month,
  year;

  BookingDate startOf(BookingDate day) {
    final Unit unit = switch (this) {
      PeriodType.week => Unit.week,
      PeriodType.month => Unit.month,
      PeriodType.year => Unit.year,
    };
    return BookingDate.on(
      Jiffy.parseFromDateTime(day.atMidnight).startOf(unit).dateTime,
    );
  }

  String title(BuildContext context) {
    return switch (this) {
      PeriodType.week => 'Week',
      PeriodType.month => 'Month',
      PeriodType.year => 'Year',
    };
  }
}

String _getMonthName(int month) {
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return monthNames[month - 1];
}

extension BookingDatePeriodExt on BookingDate {
  /// [delta] may be negative
  BookingDate addPeriod(PeriodType type, {int delta = 1}) => BookingDate.on(
    Jiffy.parseFromDateTime(atMidnight)
        .add(
          weeks: type == PeriodType.week ? delta : 0,
          months: type == PeriodType.month ? delta : 0,
          years: type == PeriodType.year ? delta : 0,
        )
        .dateTime,
  );
}
