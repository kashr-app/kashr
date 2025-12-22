import 'package:finanalyzer/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:finanalyzer/core/module.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:provider/single_child_widget.dart';

class ComdirectModule implements Module {
  @override
  late final List<SingleChildWidget> providers;

  ComdirectModule(Logger log) {
    providers = [BlocProvider(create: (_) => ComdirectAuthCubit(log))];
  }

  @override
  void dispose() {}
}
