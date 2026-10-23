// Debug-only entry point for isolated Windows UI acceptance.
// Production builds continue to use main.dart. flutter_driver is a dev dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';

import 'main.dart' as app;

Future<void> main(List<String> args) async {
  enableFlutterDriverExtension();
  await app.main(args);
}
