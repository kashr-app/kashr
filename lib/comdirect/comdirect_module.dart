import 'package:kashr/comdirect/cubit/comdirect_auth_cubit.dart';
import 'package:kashr/core/module.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class ComdirectModule implements Module {
  @override
  late final List<SingleChildWidget> providers;

  ComdirectModule(Logger log) {
    providers = [
      Provider.value(value: this),
      BlocProvider(create: (_) => ComdirectAuthCubit(log)),
    ];
  }

  @override
  void dispose() {}
}
