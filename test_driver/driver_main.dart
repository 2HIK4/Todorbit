import 'package:flutter_driver/driver_extension.dart';

import 'package:life_manager/main.dart' as app;

/// Test-only entry point for inspecting an isolated desktop profile.
Future<void> main(List<String> args) async {
  enableFlutterDriverExtension();
  await app.main(args);
}
