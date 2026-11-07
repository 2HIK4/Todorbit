import 'dart:convert';
import 'dart:io';

import '../data/cloud/google_drive_provider.dart';
import '../data/private_test_environment.dart';
import 'sync_controller.dart';

/// Private build only. Bounded operational receipts, never credential values.
/// Preflight only lists metadata; Sync requires the separate approved gate.
Future<void> runPrivateAcceptanceProbe(
  List<String> args,
  SyncController sync,
) async {
  if (!PrivateTestEnvironment.enabled) return;
  final root = PrivateTestEnvironment.validate();
  if (args.contains('--private-cloud-preflight')) {
    if (sync.auth.account == null) {
      throw StateError('Authorize the test account first.');
    }
    final objects = await GoogleDriveProvider.sync(
      sync.auth,
      sync.auth.client,
    ).list();
    await File('${root.path}/cloud-preflight.json').writeAsString(
      jsonEncode({
        'account': sync.auth.account!.id,
        'objectCount': objects.length,
        'objects': [
          for (final object in objects)
            {'id': object.id, 'properties': object.properties},
        ],
        'readOnly': true,
        'observedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }
  if (args.contains('--private-sync-now')) {
    final paired = await sync.pairing.saved();
    if (paired == null ||
        !PrivateTestEnvironment.syncApproved(
          sync.auth.account?.id,
          mode: paired.key.isStandard ? 'standard' : 'private',
          workspace: paired.binding.workspace,
        )) {
      throw StateError('Disposable account/workspace approval required.');
    }
    await sync.syncNow(manual: true);
    await File('${root.path}/sync-result.json').writeAsString(
      jsonEncode({
        'phase': sync.status.phase.name,
        'message': sync.message,
        'pending': sync.snapshot?.pending,
        'observedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }
}
