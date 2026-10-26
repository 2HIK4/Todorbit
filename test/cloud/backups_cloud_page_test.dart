import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_backup_service.dart';
import 'package:life_manager/data/cloud/google_drive_auth.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/features/settings/backups_cloud_page.dart';
import 'package:life_manager/features/settings/settings_transfer.dart';
import 'package:life_manager/features/settings/settings_transfer_dialog.dart';

import 'cloud_test_fakes.dart';

class _LocalFixture extends BackupService {
  _LocalFixture() : super(File('unused-test-profile/life.sqlite'));
  int creates = 0;
  @override
  Future<List<BackupRecord>> list() async => [];
  @override
  Future<String?> pendingRestoreName() async => null;
  @override
  Future<String?> restoreStatus() async => null;
  @override
  Future<BackupRecord> createBackup(BackupKind kind, {DateTime? now}) async {
    creates++;
    return BackupRecord(
      file: File('unused.sqlite'),
      kind: kind,
      createdAt: DateTime.utc(2026),
      bytes: 1,
      schemaVersion: 21,
    );
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'backup page ${brightness.name} at 440px and large text keeps offline local controls usable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(440, 740));
        final database = AppDatabase(NativeDatabase.memory());
        final local = _LocalFixture();
        final controller = AppController(
          LifeRepository(database),
          backupService: local,
        );
        await controller.initialize();
        final client = MockClient((_) async => http.Response('', 503));
        final auth = GoogleDriveAuth(
          client: client,
          store: MemoryTokenStore(),
          flow: TestGoogleFlow(),
          // A known client must not bypass the unpublished build gate.
          clientId: 'public.apps.googleusercontent.com',
          clientSecret: 'public-desktop-parameter',
          enabled: false,
        );
        final service = CloudBackupService(
          local: local,
          provider: MemoryCloud()..account = null,
          appVersion: 'test',
        );
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appControllerProvider.overrideWith((_) => controller),
              ],
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  splashFactory: NoSplash.splashFactory,
                ),
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(440, 740),
                    textScaler: TextScaler.linear(1.3),
                  ),
                  child: Scaffold(
                    body: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        BackupsCloudPage(auth: auth, service: service),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final connect = find.widgetWithText(
            FilledButton,
            'Connect Google Drive',
          );
          expect(tester.widget<FilledButton>(connect).onPressed, isNull);
          expect(
            find.text('Import Google Desktop configuration'),
            findsNothing,
          );
          expect(
            find.textContaining('while public access is being prepared'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Google receives encrypted'),
            findsNothing,
          );
          expect(
            find.textContaining('Keep your recovery passphrase'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('How cloud backups work'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('How cloud backups work'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Google receives encrypted'),
            findsOneWidget,
          );
          await tester.tap(find.text('How cloud backups work'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text('Local backup actions & history'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Local backup actions & history'));
          await tester.pumpAndSettle();
          final create = find.text('Create backup now');
          await tester.ensureVisible(create);
          await tester.tap(create);
          await tester.pumpAndSettle();
          expect(local.creates, 1);
          expect(find.text('Backup created and verified.'), findsOneWidget);
          for (final label in [
            'Cloud Backups',
            'Settings & Preferences Backup',
            'Import / Export Settings JSON',
          ]) {
            await tester.ensureVisible(find.text(label));
            await tester.pumpAndSettle();
            final rect = tester.getRect(find.text(label));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(440));
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          client.close();
          await database.close();
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }

  testWidgets(
    'cloud settings preview requires confirmation and keeps task records',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(db));
      await controller.initialize();
      final settings = SettingsTransfer.decode(
        jsonEncode({
          'format': 'todorbit-shareable-settings',
          'version': 1,
          'categories': {
            'calendar': {
              'content': 'both',
              'firstWeekday': 1,
              'lastMode': 'month',
            },
          },
        }),
      );
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((_) => controller)],
            child: MaterialApp(
              theme: ThemeData(splashFactory: NoSplash.splashFactory),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          SettingsTransferDialog(initialTransfer: settings),
                    ),
                    child: const Text('Review'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        expect(find.text('Restore cloud settings'), findsOneWidget);
        expect(controller.firstWeekday, 7);
        await tester.tap(find.text('Apply selected'));
        await tester.pumpAndSettle();
        expect(find.text('Apply selected settings?'), findsOneWidget);
        expect(controller.firstWeekday, 7);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(controller.firstWeekday, 7);
        await tester.tap(find.text('Apply selected'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply settings'));
        await tester.pumpAndSettle();
        expect(controller.firstWeekday, 1);
        expect(await controller.repository.tasks(), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
      }
    },
  );
}
