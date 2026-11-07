import 'package:flutter/widgets.dart';

/// Reopens the active profile through the normal guarded startup path.
class AppRestartScope extends InheritedWidget {
  const AppRestartScope({
    super.key,
    required this.restart,
    required super.child,
  });

  final Future<void> Function() restart;

  static Future<void> Function()? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppRestartScope>()?.restart;

  @override
  bool updateShouldNotify(AppRestartScope oldWidget) =>
      restart != oldWidget.restart;
}
