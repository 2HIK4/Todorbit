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
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
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

class _ConnectedAuth extends GoogleDriveAuth {
  _ConnectedAuth(http.Client client)
    : super(
        client: client,
        store: MemoryTokenStore(),
        flow: TestGoogleFlow(),
        clientId: 'fixture',
      );
  @override
  Future<void> load() async {
    account = const CloudAccount('test-account', 'Test account');
  }
}

class _RestoreFixture extends CloudBackupService {
  _RestoreFixture(BackupService local, MemoryCloud provider, this.settings)
    : super(local: local, provider: provider, appVersion: 'test');
  final String settings;
  int schedules = 0;
  @override
  Future<CloudRestorePreview> preview(
    CloudObject object,
    String passphrase,
    CloudProgress progress,
  ) async => CloudRestorePreview(
    {'appVersion': '1.0.18', 'profileId': 'other-device', 'settings': settings},
    null,
    const BackupSummary({'tasks': 4}),
  );
  @override
  Future<void> scheduleRestore(CloudRestorePreview preview) async {
    schedules++;
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
          // The page now reads transfer-history availability from the filesystem.
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
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
          expect(
            find.textContaining('Last successful restore on this device'),
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
    'restore warns about unknown local baseline and cancel never schedules replacement',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 800));
      final database = AppDatabase(NativeDatabase.memory());
      final local = _LocalFixture();
      final controller = AppController(
        LifeRepository(database),
        backupService: local,
      );
      await controller.initialize();
      final client = MockClient((_) async => http.Response('', 503));
      final provider = MemoryCloud();
      provider.objects.add(
        CloudObject(
          id: 'fixture',
          accountId: 'test-account',
          name: 'private-name',
          bytes: 100,
          createdAt: DateTime.utc(2026),
          properties: const {
            'kind': 'full',
            'formatVersion': '1',
            'encryption': 'aes256gcm-v1',
            'schema': '22',
            'appVersion': '1.0.18',
            'sourcePlatform': 'windows',
            'verified': 'true',
          },
          md5: 'unused',
        ),
      );
      final service = _RestoreFixture(
        local,
        provider,
        SettingsTransfer.fromController(controller)
            .encode(SettingsCategory.values.toSet()),
      );
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((_) => controller)],
            child: MaterialApp(
              home: Scaffold(
                body: ListView(
                  children: [
                    BackupsCloudPage(
                      auth: _ConnectedAuth(client),
                      service: service,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        final restore = find.text('Download & review restore');
        await tester.ensureVisible(restore);
        await tester.pumpAndSettle();
        await tester.tap(restore);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'fixture recovery phrase',
        );
        await tester.pump();
        await tester.tap(find.text('Download and unlock'));
        // The busy indicator animates while real filesystem I/O completes.
        // Advance frames and real I/O until the review modal appears.
        for (
          var attempt = 0;
          attempt < 20 &&
              find.text('Replace this local profile?').evaluate().isEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Replace this local profile?'), findsOneWidget);
        expect(
          find.textContaining('no verified transfer baseline'),
          findsOneWidget,
        );
        expect(find.textContaining('4 tasks'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(service.schedules, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        client.close();
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

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
