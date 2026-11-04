import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/features/settings/backup_dialog.dart';
import 'package:life_manager/features/startup/startup_page.dart';

class _BackupFixture extends BackupService {
  _BackupFixture() : super(File('unused-synthetic-profile.sqlite'));
  bool fail = true;
  bool scheduled = false;
  int previews = 0;
  Completer<BackupSummary>? preview;
  final record = BackupRecord(
    file: File('synthetic-snapshot.sqlite'),
    kind: BackupKind.manual,
    createdAt: DateTime.utc(2026, 11, 4),
    bytes: 2048,
    schemaVersion: AppDatabase.currentSchemaVersion,
  );
  @override
  Future<List<BackupRecord>> list() async {
    if (fail) throw StateError('Synthetic backup storage unavailable');
    return [record];
  }

  @override
  Future<String?> pendingRestoreName() async =>
      scheduled ? 'synthetic-snapshot.sqlite' : null;
  @override
  Future<String?> restoreStatus() async => null;
  @override
  Future<BackupSummary> summarize(BackupRecord selected) async {
    previews++;
    return preview?.future ??
        Future.value(const BackupSummary({'tasks': 2, 'goals': 1}));
  }

  @override
  Future<void> scheduleRestore(
    BackupRecord selected, {
    required int appSchemaVersion,
    String? portableSettings,
    String? expectedLocalFingerprint,
    String? expectedLocalPreferences,
    Map<String, dynamic>? cloudTransfer,
  }) async {
    scheduled = true;
  }

  @override
  Future<void> cancelScheduledRestore() async {
    scheduled = false;
  }
}

void main() {
  testWidgets('backup preview rejects repeat activation before review', (
    tester,
  ) async {
    final service = _BackupFixture()..fail = false;
    final preview = service.preview = Completer<BackupSummary>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BackupDialog(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restore'));
    await tester.pumpAndSettle();
    final restore = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Restore'))
        .onPressed!;
    restore();
    restore();
    await tester.pump();
    expect(service.previews, 1);
    preview.complete(const BackupSummary({'tasks': 2}));
    await tester.pumpAndSettle();
    expect(find.text('Confirm replacement'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.scheduled, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets(
    'backup list failure offers retry and restore remains an explicit cancellable decision',
    (tester) async {
      final service = _BackupFixture();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: BackupDialog(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Retry loading backups'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      service.fail = false;
      await tester.tap(find.text('Retry loading backups'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Restore'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.textContaining('It does not merge them.'), findsOneWidget);
      expect(service.scheduled, isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.scheduled, isFalse);
      await tester.ensureVisible(find.text('Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm replacement'));
      await tester.pumpAndSettle();
      expect(service.scheduled, isTrue);
      await tester.ensureVisible(find.text('Cancel scheduled restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel scheduled restore'));
      await tester.pumpAndSettle();
      expect(service.scheduled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets(
      'startup recovery controls remain reachable at $size and 200 percent',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var cancelled = false;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: StartupPage(
              children: [
                const Text(
                  'Todorbit could not prepare its database. The main app was not started. Review the error below before retrying.',
                ),
                SelectableText(
                  List.filled(
                    8,
                    'Synthetic unavailable database path / long error details.',
                  ).join(' '),
                ),
                const Text(
                  'Check disk space and file access, then restart the app.',
                ),
                OutlinedButton(
                  onPressed: () => cancelled = true,
                  child: const Text(
                    'Cancel scheduled restore and retry current database',
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(OutlinedButton));
        await tester.tap(find.byType(OutlinedButton));
        expect(cancelled, isTrue);
      },
    );
  }
}
