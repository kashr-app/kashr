import 'package:flutter/widgets.dart';

abstract class Restarter {
  void restart();
}

class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  static Restarter? getRestarter(BuildContext context) {
    return context.findAncestorStateOfType<_RestartWidgetState>();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> implements Restarter {
  Key key = UniqueKey();

  @override
  void restart() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: key, child: widget.child);
  }
}
