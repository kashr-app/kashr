import 'package:flutter/material.dart';

class AppLifecycleListeners {
  late final AppLifecycleListener _appLifeCycleListener;

  final _onHide = <VoidCallback>[];

  AppLifecycleListeners() {
    _appLifeCycleListener = AppLifecycleListener(
      onHide: () {
        for (var hook in _onHide) {
          hook();
        }
      },
    );
  }

  void registerOnHide(VoidCallback callback) {
    _onHide.add(callback);
  }

  void dispose() {
    _onHide.clear();
    _appLifeCycleListener.dispose();
  }
}
