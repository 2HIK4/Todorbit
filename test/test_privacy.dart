import 'dart:io';

import 'package:life_manager/app/privacy_manager.dart';
import 'package:life_manager/data/privacy_store.dart';
import 'package:life_manager/features/settings/privacy_dialog.dart';

// Tests that exercise the workspace without privacy settings explicitly use an
// unlocked, disabled policy. Each ProviderScope gets its own manager instance.
final privacyOverride = privacyManagerProvider.overrideWith(
  (ref) => PrivacyManager(
    PrivacyStore(File('unused-test-privacy.json')),
    const PrivacySettings(),
  ),
);
