import 'package:flutter/material.dart';

class AppLifecycleListeners {
  late final AppLifecycleListener _appLifeCycleListener;

  final _onHide = <VoidCallback>[];
  final _onShow = <VoidCallback>[];

  AppLifecycleListeners() {
    _appLifeCycleListener = AppLifecycleListener(
      onHide: () {
        for (var hook in _onHide) {
          hook();
        }
      },
      onShow: () {
        for (var hook in _onShow) {
          hook();
        }
      },
    );
  }

  void registerOnHide(VoidCallback callback) {
    _onHide.add(callback);
  }

  void registerOnShow(VoidCallback callback) {
    _onShow.add(callback);
  }

  void dispose() {
    _onHide.clear();
    _onShow.clear();
    _appLifeCycleListener.dispose();
  }
}
