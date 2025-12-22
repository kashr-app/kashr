import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/logging/services/log_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class LoggingModule implements Module {
  late final LogService logService;

  @override
  late final List<SingleChildWidget> providers;

  LoggingModule() {
    logService = LogService();

    providers = [Provider.value(value: logService)];
  }

  @override
  void dispose() {
    logService.dispose();
  }
}
