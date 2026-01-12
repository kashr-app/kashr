import 'package:intl/intl.dart';
import 'package:kashr/core/bool_json_converter.dart';
import 'package:kashr/logging/model/log_level_setting.dart';
import 'package:kashr/local_auth/auth_delay.dart';
import 'package:kashr/settings/model/amazon_order_behavior.dart';
import 'package:kashr/settings/model/feature_tip.dart';
import 'package:kashr/settings/model/onboarding_converters.dart';
import 'package:kashr/settings/model/week_start_day.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../_gen/settings/settings_state.freezed.dart';
part '../_gen/settings/settings_state.g.dart';

const defaultDateFormat = 'MMM d, yyyy';

@freezed
abstract class SettingsState with _$SettingsState {
  // required to enable manual getters with freezed
  const SettingsState._();

  const factory SettingsState({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @BoolJsonConverter() @Default(false) bool fastFormMode,
    @LogLevelSettingConverter()
    @Default(LogLevelSetting.error)
    LogLevelSetting logLevel,
    @AuthDelayOptionConverter()
    @Default(AuthDelayOption.immediate)
    AuthDelayOption authDelay,
    @WeekStartDayConverter()
    @Default(WeekStartDay.monday)
    WeekStartDay weekStartDay,
    @Default(defaultDateFormat) dateFormatStr,
    @AmazonOrderBehaviorConverter()
    @Default(AmazonOrderBehavior.askOnTap)
    AmazonOrderBehavior amazonOrderBehavior,
    @AmazonTldConverter() @Default(AmazonTld.de) AmazonTld amazonTld,
    @NullableDateTimeConverter() DateTime? onboardingCompletedOn,
    @FeatureTipMapConverter()
    @Default({})
    Map<FeatureTip, bool> featureTipsShown,
  }) = _SettingsState;

  factory SettingsState.fromJson(Map<String, Object?> json) =>
      _$SettingsStateFromJson(json);

  DateFormat get dateFormat => DateFormat(dateFormatStr);

  bool hasSeenFeatureTip(FeatureTip tip) => featureTipsShown[tip] ?? false;
}

class LogLevelSettingConverter
    implements JsonConverter<LogLevelSetting, String> {
  const LogLevelSettingConverter();

  @override
  LogLevelSetting fromJson(String json) {
    return LogLevelSetting.values.firstWhere(
      (e) => e.name == json,
      orElse: () => LogLevelSetting.error,
    );
  }

  @override
  String toJson(LogLevelSetting object) => object.name;
}
