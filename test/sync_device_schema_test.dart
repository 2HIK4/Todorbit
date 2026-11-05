import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';

import 'support/legacy_sync_fixture.dart';

void main() {
  test('public schema22 data and open work interval survive portable ownership migration', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-owner-migration-',
    );
    final file = File('${root.path}/legacy.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    try {
      var repository = LifeRepository(db);
      await repository.addTask(const TaskDraft(title: 'Synthetic legacy task'));
      final task = (await repository.tasks()).single;
      final run = await repository.startTimer(task.id);
      final interval = (await repository.timeEntries()).single;
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        stripSyncSchemaForLegacyFixture(raw);
        raw.execute('DROP TABLE portable_preferences');
        raw.execute('ALTER TABLE timer_runs DROP COLUMN owner_device_id');
        raw.execute('PRAGMA user_version=22');
      } finally {
        raw.close();
      }
      db = AppDatabase(NativeDatabase(file));
      repository = LifeRepository(db);
      expect((await repository.tasks()).single.id, task.id);
      final migrated = (await repository.activeTimerRun())!;
      expect(migrated.id, run.id);
      expect(migrated.canControl, isTrue);
      expect(migrated.ownerDeviceId, isNull);
      expect((await repository.timeEntries()).single.id, interval.id);
      expect((await repository.timeEntries()).single.endsAt, isNull);
      expect(await repository.portablePreferences(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        AppDatabase.currentSchemaVersion,
      );
    } finally {
      await db.close();
      await root.delete(recursive: true);
    }
  });
}
