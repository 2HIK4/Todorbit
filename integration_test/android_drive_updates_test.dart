// One disposable-device runner covers the existing mobile/restore workflow and
// the new native APK gates, avoiding separate application installations.
import 'android_workflow_test.dart' as workflow;
import 'android_update_verification_test.dart' as updates;

import 'package:life_manager/main.dart' as app;

// Native reminder jobs resolve this function in the entry-point library.
@pragma('vm:entry-point')
Future<void> androidBackgroundMain() => app.androidBackgroundMain();

void main() {
  workflow.main();
  updates.main();
}
