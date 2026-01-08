import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:provider/provider.dart';

/// Extension to access settings from BuildContext.
///
/// Use [dateFormat] in the build() method for reactive updates.
/// Use [dateFormatValue] in callbacks, helper methods, or when you don't
/// need reactive updates.
extension SettingsContext on BuildContext {
  /// Gets the current date format and rebuilds when it changes.
  ///
  /// Use this directly in your build() method when you want the widget
  /// to automatically rebuild when the date format setting changes.
  ///
  /// ⚠️ Cannot be used in callbacks or helper methods called from build().
  /// For those cases, use [dateFormatValue] instead.
  DateFormat get dateFormat =>
      select<SettingsCubit, DateFormat>((cubit) => cubit.state.dateFormat);

  /// Gets the current date format value without subscribing to changes.
  ///
  /// Use this in:
  /// - Callbacks (onTap, onPressed, etc.)
  /// - Helper methods called from build()
  /// - ListView/GridView item builders
  /// - Anywhere you just need the current value without reactive updates
  ///
  /// The widget won't rebuild when the date format changes.
  DateFormat get dateFormatValue => read<SettingsCubit>().state.dateFormat;
}
