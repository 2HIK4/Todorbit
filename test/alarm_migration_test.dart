import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/alarms.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  test('schema27 upgrade preserves journal bytes and existing work', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-alarm-migration-',
    );

    final file = File('${root.path}/synthetic.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });
    await db.customSelect('SELECT 1').get();
    await db.customStatement('DROP TABLE alarm_rules');
    await db.customStatement('PRAGMA user_version=27');
    await db.customStatement(
      "UPDATE sync_capture_context SET workspace_id='8b41595f-3258-40e7-8499-856772bf5fb8',account_id='fixture',device_id='df0293d3-c369-4db8-a998-0ae0b076397d',capture_enabled=1 WHERE id=1",
    );
    final task = await LifeRepository(db)
        .addTask(const TaskDraft(title: 'Retained schema27 work'));
    final before = jsonEncode(
      (await db
              .customSelect('SELECT * FROM sync_journal ORDER BY sequence')
              .get())
          .map((r) => r.data)
          .toList(),
    );
    await db.close();
    db = AppDatabase(NativeDatabase(file));

    final repo = LifeRepository(db);
    expect((await repo.tasks()).single.id, task.id);
    expect(await repo.alarmRules(), isEmpty);
    expect(
      jsonEncode(
        (await db
                .customSelect('SELECT * FROM sync_journal ORDER BY sequence')
                .get())
            .map((r) => r.data)
            .toList(),
      ),
      before,
    );
    await repo.saveAlarm(
      AlarmConfig(mode: 'custom', at: DateTime.utc(2027, 1, 1)),
      taskId: task.id,
      expectedRevision: 'new',
    );
    expect(
      (await db
          .customSelect(
            "SELECT entity FROM sync_journal WHERE entity='alarm_rules'",
          )
          .get()),
      isNotEmpty,
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    final rule = (await repo.alarmRules()).single;
    await repo.saveAlarm(
      const AlarmConfig(),
      taskId: task.id,
      expectedRevision: rule.updatedAt,
    );
    expect(
      () => repo.saveAlarm(
        rule.config,
        taskId: task.id,
        expectedRevision: rule.updatedAt,
      ),
      throwsStateError,
    );
    expect((await repo.alarmRules()).single.config.enabled, isFalse);
  });
}
