import 'package:kashr/theme.dart';
import 'package:flutter/material.dart';

enum LogLevelSetting {
  trace,
  debug,
  info,
  warning,
  error,
  fatal,
  off;

  String get displayName {
    return switch (this) {
      LogLevelSetting.trace => 'All (Trace+)',
      LogLevelSetting.debug => 'Debug+',
      LogLevelSetting.info => 'Info+',
      LogLevelSetting.warning => 'Warning+',
      LogLevelSetting.error => 'Error+',
      LogLevelSetting.fatal => 'Fatal Only',
      LogLevelSetting.off => 'Off',
    };
  }

  Color color(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final customColors = theme.extension<CustomColors>()!;
    return switch (this) {
      LogLevelSetting.trace => customColors.info,
      LogLevelSetting.debug => customColors.info,
      LogLevelSetting.info => customColors.info,
      LogLevelSetting.warning => customColors.warning,
      LogLevelSetting.error => colorScheme.error,
      LogLevelSetting.fatal => colorScheme.error,
      LogLevelSetting.off => colorScheme.onSurface,
    };
  }

  IconData get icon => switch (this) {
    LogLevelSetting.info => Icons.info,
    LogLevelSetting.warning => Icons.warning,
    LogLevelSetting.error || LogLevelSetting.fatal => Icons.error,
    _ => Icons.circle,
  };

  int get threshold => switch (this) {
    LogLevelSetting.trace => 0,
    LogLevelSetting.debug => 1,
    LogLevelSetting.info => 2,
    LogLevelSetting.warning => 3,
    LogLevelSetting.error => 4,
    LogLevelSetting.fatal => 5,
    LogLevelSetting.off => 999,
  };

  bool shouldLog(LogLevelSetting logLevel) {
    return logLevel.threshold >= threshold;
  }
}
