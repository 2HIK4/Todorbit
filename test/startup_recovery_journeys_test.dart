import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/data/profile_paths.dart';
import 'package:life_manager/main.dart' as app;
import 'package:life_manager/features/shared/app_restart_scope.dart';
import 'package:life_manager/app/sync_controller.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'database_initialization_test.dart' show legacyDatabase;
import 'support/profile_journey_environment.dart';

void main() {
  // These tests invoke the real startup entry point. Refuse personal profiles.
  if (!isolatedProfileJourneys) {
    test(
      'requires explicitly isolated Batch 5 child environment',
      () {},
      skip: 'Run tools/dev/test-profile-journeys.ps1 with disposable APPDATA/LOCALAPPDATA.',
    );
    return;
  }
  final profile = ProfilePaths.activeDirectory();
  final database = File('${profile.path}/life_manager.sqlite');
  var retainFixture = false;
  Future<void> removeFixture() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (await profile.exists()) await profile.delete(recursive: true);
        return;
      } on FileSystemException catch (failure) {
        // Retry only transient Windows sharing violations after SQLite closes.
        if (failure.osError?.errorCode != 32 || attempt == 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  setUp(() async {
    await removeFixture();
    await profile.create(recursive: true);
  });
  tearDown(() async {
    if (retainFixture) return;
    await removeFixture();
  });

  for (final name in ['appearance-settings.json', 'calendar-settings.json']) {
    testWidgets('real startup preserves malformed $name and existing records', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final db = AppDatabase(NativeDatabase(database));
        await LifeRepository(db)
            .addTask(const TaskDraft(title: 'Preserve existing work'));
        await db.close();
      });
      final settings = File('${profile.path}/$name')
        ..writeAsStringSync('{recoverable malformed preferences');
      await tester.runAsync(() => app.main([]));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('profile settings could not be loaded'),
        findsOneWidget,
      );
      expect(settings.readAsStringSync(), '{recoverable malformed preferences');
      final verify = sqlite.sqlite3.open(
        database.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(
          verify.select('SELECT title FROM tasks').single['title'],
          'Preserve existing work',
        );
        expect(verify.select('PRAGMA quick_check').single.values.single, 'ok');
      } finally {
        verify.close();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('real startup gates supported legacy profile without writes', (
    tester,
  ) async {
    await tester.runAsync(() async => legacyDatabase(database));
    final before = database.readAsBytesSync();
    await tester.runAsync(() => app.main([]));
    await tester.pumpAndSettle();
    expect(find.text('Database upgrade required'), findsOneWidget);
    expect(find.text('Back up and upgrade database'), findsOneWidget);
    expect(database.readAsBytesSync(), before);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets('real corrupt startup retains bytes and retry at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      database.writeAsStringSync('synthetic damaged SQLite file');
      final before = database.readAsBytesSync();
      try {
        await tester.runAsync(() => app.main([]));
        await tester.pumpAndSettle();
        // Exercise the actual page's reflow after startup, rather than a generic layout.
        final view = tester.view;
        view.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        expect(
          find.textContaining('could not prepare its database'),
          findsOneWidget,
        );
        expect(database.readAsBytesSync(), before);
        await tester.ensureVisible(find.text('Retry opening Todorbit'));
        await tester.pumpAndSettle();
        final dynamic retry = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Retry opening Todorbit'),
            )
            .onPressed;
        await tester.runAsync(() async => await retry());
        await tester.pumpAndSettle();
        expect(database.readAsBytesSync(), before);
        expect(tester.takeException(), isNull);
      } finally {
        tester.view.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
      }
    });
  }

  testWidgets('real privacy corruption fails closed and preserves policy', (
    tester,
  ) async {
    final policy = File('${profile.path}/privacy-settings.json');
    policy.writeAsStringSync('{"enabled":true,broken');
    final original = policy.readAsStringSync();
    await tester.runAsync(() => app.main([]));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Privacy settings could not be read'),
      findsOneWidget,
    );
    expect(find.text('Retry opening Todorbit'), findsOneWidget);
    expect(policy.readAsStringSync(), original);
    expect(database.existsSync(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real startup catches unavailable profile directory', (
    tester,
  ) async {
    profile.deleteSync(recursive: true);
    final blocked = File(profile.path)
      ..writeAsStringSync('synthetic path blocker');
    try {
      await tester.runAsync(() => app.main([]));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('could not access its local profile'),
        findsOneWidget,
      );
      expect(find.text('Retry opening Todorbit'), findsOneWidget);
      expect(blocked.readAsStringSync(), 'synthetic path blocker');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      blocked.deleteSync();
    }
  });

  testWidgets('real future-schema startup is actionable and never resets', (
    tester,
  ) async {
    final raw = sqlite.sqlite3.open(database.path);
    raw.execute('PRAGMA user_version=999');
    raw.close();
    final before = database.readAsBytesSync();
    await tester.runAsync(() => app.main([]));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Unsupported database schema 999'),
      findsOneWidget,
    );
    expect(find.text('Retry opening Todorbit'), findsOneWidget);
    expect(database.readAsBytesSync(), before);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'real automatic restore restart closes old profile and reopens verified replacement',
    (tester) async {
      // Keep the actual restored database and Before Restore as acceptance evidence.
      retainFixture = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('life_manager/activation'),
        (_) async => null,
      );
      Future<void> pumpIo() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await tester.runAsync(() => app.main([]));
      try {
        // Real profile IO and background initialization need event-loop time;
        // advancing only the fake clock starves them and spins the progress UI.
        await pumpIo();
        final oldContainer = ProviderScope.containerOf(
          tester.element(find.byType(app.LifeManagerApp)),
        );
        final oldController = oldContainer.read(appControllerProvider);
        await tester.runAsync(() async {
          await oldController.repository.addTask(
            const TaskDraft(title: 'Snapshot record'),
          );
          final selected = await oldController.backupService!.createBackup(
            BackupKind.manual,
          );
          await oldController.repository.addTask(
            const TaskDraft(title: 'Later recoverable work'),
          );
          await oldController.backupService!.scheduleRestore(
            selected,
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          );
        });
        final restart = AppRestartScope.maybeOf(
          tester.element(find.byType(app.LifeManagerApp)),
        )!;
        var completed = false;
        late Future<void> restarting;
        await tester.runAsync(() async {
          restarting = restart().whenComplete(() => completed = true);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        for (var i = 0; i < 1000 && !completed; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
        }
        expect(
          completed,
          isTrue,
          reason: 'Automatic restart must finish without a second launch',
        );
        await tester.runAsync(() => restarting);
        await pumpIo();
        final nextContainer = ProviderScope.containerOf(
          tester.element(find.byType(app.LifeManagerApp)),
        );
        final next = nextContainer.read(appControllerProvider);
        expect(identical(oldController, next), isFalse);
        expect(next.tasks.map((t) => t.title), ['Snapshot record']);
        expect(
          await tester.runAsync(
            () => next.backupService!.hasScheduledRestore(),
          ),
          isFalse,
        );
        final before = await tester.runAsync(
          () => next.backupService!.restorationRecoveryBackup(),
        );
        expect(before, isNotNull);
        final check = sqlite.sqlite3.open(
          before!.file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(
            check.select('SELECT title FROM tasks').map((r) => r['title']),
            contains('Later recoverable work'),
          );
          expect(
            check.select('PRAGMA integrity_check').single.values.single,
            'ok',
          );
        } finally {
          check.close();
        }
        expect(tester.takeException(), isNull);
      } finally {
        if (find.byType(app.LifeManagerApp).evaluate().isNotEmpty) {
          final current = ProviderScope.containerOf(
            tester.element(find.byType(app.LifeManagerApp)),
          );
          await tester.runAsync(() async {
            await current.read(syncControllerProvider)?.shutdown();
            await current.read(appControllerProvider).repository.db.close();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'real approved legacy upgrade preserves identities relationships and preferences',
    (tester) async {
      const activation = MethodChannel('life_manager/activation');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        activation,
        (_) async => null,
      );
      // Keep the successful upgrade and Before upgrade snapshot as acceptance evidence.
      retainFixture = true;
      legacyDatabase(database);
      final legacy = sqlite.sqlite3.open(database.path);
      legacy.execute(
        "INSERT INTO categories VALUES('category-id','Research','2026-10-16T00:00:00.000Z','2026-10-16T00:00:00.000Z')",
      );
      legacy.execute(
        "INSERT INTO projects VALUES('project-id','category-id','Reading','2026-10-16T00:00:00.000Z','2026-10-16T00:00:00.000Z')",
      );
      legacy.execute(
        "UPDATE tasks SET category_id='category-id',project_id='project-id',notes='Preserve notes',priority=2",
      );
      legacy.close();
      File('${profile.path}/appearance-settings.json').writeAsStringSync(
        '{"theme":"dark","firstWeekday":1,"lastCalendarMode":"week","unrecognizedMetadata":"keep"}',
      );
      await tester.runAsync(() => app.main([]));
      await tester.pumpAndSettle();
      expect(find.text('Database upgrade required'), findsOneWidget);
      final dynamic approve = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Back up and upgrade database'),
          )
          .onPressed;
      await tester.runAsync(() async => await approve());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(app.LifeManagerApp)),
      );
      final controller = container.read(appControllerProvider);
      try {
        final task = controller.tasks.single;
        expect(task.id, 'legacy-id');
        expect(task.categoryId, 'category-id');
        expect(task.projectId, 'project-id');
        expect(task.notes, 'Preserve notes');
        expect(task.priority, 2);
        expect(controller.theme, ThemeModePreference.dark);
        expect(controller.firstWeekday, 1);
        expect(controller.lastCalendarMode, 'week');
        expect(
          File('${profile.path}/appearance-settings.json').readAsStringSync(),
          contains('unrecognizedMetadata'),
        );
        final records = await tester.runAsync(
          () => BackupService(database).list(),
        );
        final snapshot = records!.singleWhere(
          (record) => record.kind == BackupKind.beforeUpgrade,
        );
        final before = sqlite.sqlite3.open(
          snapshot.file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        final after = sqlite.sqlite3.open(
          database.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          expect(before.userVersion, 1);
          expect(
            before.select('SELECT id FROM tasks').single['id'],
            'legacy-id',
          );
          expect(after.userVersion, AppDatabase.currentSchemaVersion);
          expect(after.select('PRAGMA quick_check').single.values.single, 'ok');
          expect(after.select('PRAGMA foreign_key_check'), isEmpty);
        } finally {
          before.close();
          after.close();
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => controller.repository.db.close());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          activation,
          null,
        );
      }
    },
  );
}
