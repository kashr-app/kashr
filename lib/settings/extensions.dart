import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:kashr/settings/settings_cubit.dart';
import 'package:provider/provider.dart';

extension SettingsContext on BuildContext {
  DateFormat get dateFormat =>
      select<SettingsCubit, DateFormat>((cubit) => cubit.state.dateFormat);
}
