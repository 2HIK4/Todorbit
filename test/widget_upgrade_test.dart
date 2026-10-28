import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/widget_configuration_store.dart';
import 'package:life_manager/domain/widget_configuration.dart';
import 'package:life_manager/domain/widget_presets.dart';
import 'package:life_manager/domain/settings_history.dart';
import 'package:life_manager/domain/navigation_request.dart';
import 'package:life_manager/domain/notifications.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/settings/settings_transfer.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('history coalesces gestures, bounds snapshots and invalidates redo', () {
    final history = SettingsHistory<int>(limit: 2, equal: (a, b) => a == b);
    history.begin(100);
    history.record(100, 80);
    history.record(80, 60);
    history.end(60);
    expect(history.undo(60), 100);
    expect(history.redo(100), 60);
    history.record(60, 40);
    expect(history.undo(40), 60);
    history.record(60, 30);
    expect(history.canRedo, false);
    history.record(30, 20);
    history.record(20, 10);
    expect(history.undo(10), 20);
    expect(history.undo(20), 30);
    expect(history.canUndo, false);
  });
  test('order including hidden views, alpha, split and preset selection round-trip', () {
    final config = WidgetConfiguration(
      views: ['today', 'all'],
      navigationOrder: ['all', 'inbox', 'today', 'upcoming'],
      calendarSplit: .7,
      presetName: 'Study',
      surfaces: {
        'taskRow': const WidgetSurface(
          color: '#660099',
          opacity: 35,
          textColor: '#FFFFFF',
          textOpacity: 90,
        ),
        'selectedNavigation': const WidgetSurface(opacity: 75),
      },
    );
    final loaded = WidgetConfiguration.fromJson(
      jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
    );
    expect(loaded.visibleViews, ['all', 'today']);
    expect(loaded.navigationOrder, ['all', 'inbox', 'today', 'upcoming']);
    expect(loaded.calendarSplit, .7);
    expect(loaded.presetName, 'Study');
    expect(loaded.surfaces['taskRow']!.opacity, 35);
    expect(loaded.surfaces['taskRow']!.textOpacity, 90);
    expect(loaded.surfaces['shell']!.opacity, 100);
    expect(
      WidgetConfiguration.fromJson({
        'version': 1,
        'views': ['all', 'today'],
      }).visibleViews,
      ['all', 'today'],
    );
  });
  test('built-ins remain independent; custom create/rename/duplicate/delete persist', () async {
    final dir = await Directory.systemTemp.createTemp('todorbit-presets-');
    try {
      final store = WidgetConfigurationStore(dir);
      final built = WidgetPresets.builtIn(DesktopWidgetKind.tasks);
      var library = WidgetPresets().put(
        'Study',
        built['Minimal']!,
        DesktopWidgetKind.tasks,
      );
      library = library.put(
        'Copy',
        library.custom['Study']!,
        DesktopWidgetKind.tasks,
      );
      library = library
          .remove('Study')
          .put('Renamed', library.custom['Study']!, DesktopWidgetKind.tasks);
      await store.savePresets(DesktopWidgetKind.tasks, library);
      final loaded = await store.loadPresets(DesktopWidgetKind.tasks);
      expect(loaded.custom.keys, containsAll(['Copy', 'Renamed']));
      expect(
        (await store.loadPresets(DesktopWidgetKind.calendar)).custom,
        isEmpty,
      );
      expect(loaded.remove('Copy').custom.containsKey('Copy'), false);
      expect(WidgetPresets.builtIn(DesktopWidgetKind.tasks).length, 5);
      final active = WidgetPresets.apply(
        built['Minimal']!,
        WidgetConfiguration(enabled: true, layoutLocked: true),
      );
      expect(active.enabled, true);
      expect(active.layoutLocked, true);
      expect(active.showTitle, false);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test(
    'local snapshot/import/restore applies widget configuration and presets',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'todorbit-widgets-backup-',
      );
      final db = AppDatabase(NativeDatabase(File('${dir.path}/life.sqlite')));
      final store = WidgetConfigurationStore(dir);
      try {
        await LifeRepository(db).addTask(const TaskDraft(title: 'Preserve'));
        await store.save(
          DesktopWidgetKind.tasks,
          WidgetConfiguration(
            enabled: true,
            navigationOrder: ['all', 'today', 'inbox', 'upcoming'],
            calendarSplit: .65,
          ),
        );
        await store.savePresets(
          DesktopWidgetKind.tasks,
          WidgetPresets().put(
            'Study',
            WidgetConfiguration(textScale: 1.3),
            DesktopWidgetKind.tasks,
          ),
        );
        final backups = BackupService(File('${dir.path}/life.sqlite'));
        final snapshot = await backups.createBackup(BackupKind.manual);
        await db.close();
        await store.save(
          DesktopWidgetKind.tasks,
          WidgetConfiguration(enabled: false),
        );
        await store.savePresets(DesktopWidgetKind.tasks, WidgetPresets());
        // Stage through the same external SQLite import used for cloud full restore.
        final imported = await backups.importSnapshot(
          snapshot.file,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        await backups.scheduleRestore(
          imported,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        await backups.applyScheduledRestore(
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        final restored = await store.load(DesktopWidgetKind.tasks);
        expect(restored.navigationOrder.first, 'all');
        expect(restored.enabled, false);
        expect(
          (await store.loadPresets(DesktopWidgetKind.tasks))
              .custom['Study']!
              .textScale,
          1.3,
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test('settings transfer applies widget personalization, preserving device controls', () async {
    final dir = await Directory.systemTemp.createTemp(
      'todorbit-widget-transfer-',
    );
    final db = AppDatabase(NativeDatabase.memory());
    final store = WidgetConfigurationStore(dir);
    final controller = AppController(LifeRepository(db), widgetStore: store);
    try {
      await store.save(
        DesktopWidgetKind.calendar,
        WidgetConfiguration(calendarSplit: .7, enabled: true),
      );
      final settings = SettingsTransfer.decode(
        SettingsTransfer.fromController(controller)
            .encode({SettingsCategory.widgets}),
      );
      await store.save(
        DesktopWidgetKind.calendar,
        WidgetConfiguration(enabled: false),
      );
      await settings.applyTo(controller, {SettingsCategory.widgets});
      expect((await store.load(DesktopWidgetKind.calendar)).calendarSplit, .7);
      expect((await store.load(DesktopWidgetKind.calendar)).enabled, false);
    } finally {
      controller.dispose();
      await db.close();
      await dir.delete(recursive: true);
    }
  });
  test(
    'task notifications default off, update, disable and survive v21 migration',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'todorbit-task-reminders-',
      );
      final file = File('${dir.path}/tasks.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      try {
        var repo = LifeRepository(db);
        final task = await repo.addTask(
          const TaskDraft(title: 'No automatic reminder'),
        );
        expect(task.notification.enabled, false);
        await repo.updateTask(
          task,
          TaskDraft(
            title: task.title,
            notification: TaskNotification(
              mode: 'custom',
              at: DateTime.utc(2030),
            ),
          ),
        );
        var current = (await repo.tasks()).single;
        expect(current.notification.at, DateTime.utc(2030));
        await repo.updateTask(
          current,
          TaskDraft(title: current.title),
        ); // unrelated callers preserve
        current = (await repo.tasks()).single;
        expect(current.notification.enabled, true);
        await db.close();
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute('PRAGMA user_version=21');
        raw.close();
        db = AppDatabase(NativeDatabase(file));
        repo = LifeRepository(db);
        current = (await repo.tasks()).single;
        expect(current.notification.enabled, true);
        await repo.updateTask(
          current,
          TaskDraft(
            title: current.title,
            notification: const TaskNotification(),
          ),
        );
        expect((await repo.tasks()).single.notification.enabled, false);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test('typed navigation round-trips IDs/nominal dates and rejects invalid targets', () {
    const request = NavigationRequest(
      kind: 'event',
      id: 'stable-id',
      day: '2026-10-28',
      nominalDate: '2026-10-20',
    );
    final loaded = NavigationRequest.decode(request.encode());
    expect(loaded.id, 'stable-id');
    expect(loaded.nominalDate, '2026-10-20');
    expect(
      () => NavigationRequest.decode('{"kind":"title"}'),
      throwsFormatException,
    );
  });
}
