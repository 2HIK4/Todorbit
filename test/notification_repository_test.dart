import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/notifications.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('notifications are off by default and settings persist', () async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      final repo = LifeRepository(db);
      expect((await repo.notificationSettings()).enabled, isFalse);
      expect((await repo.notificationSettings()).localMinute, 540);
      await repo.saveNotificationSettings(
        const NotificationSettings(
          dueReminders: true,
          dailySummary: true,
          localMinute: 23 * 60 + 45,
        ),
      );
      expect((await repo.notificationSettings()).localMinute, 1425);
      expect((await repo.notificationSettings()).enabled, isTrue);
      await expectLater(
        repo.saveNotificationSettings(
          const NotificationSettings(localMinute: 1440),
        ),
        throwsArgumentError,
      );
      expect((await repo.notificationSettings()).localMinute, 1425);
    } finally {
      await db.close();
    }
  });

  test('disposable v13 migrates to v14 retaining tasks', () async {
    final directory = await Directory.systemTemp.createTemp(
      'life-notifications-v13-',
    );
    final file = File('${directory.path}/legacy.sqlite');
    try {
      final original = AppDatabase(NativeDatabase(file));
      final task = await LifeRepository(original)
          .addTask(const TaskDraft(title: 'Keep across upgrade'));
      await original.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE notification_deliveries');
        raw.execute('DROP TABLE notification_settings');
        raw.execute('PRAGMA user_version=13');
      } finally {
        raw.close();
      }
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final repo = LifeRepository(upgraded);
        expect((await repo.tasks()).single.id, task.id);
        expect((await repo.notificationSettings()).enabled, isFalse);
        await repo.saveNotificationSettings(
          const NotificationSettings(dailySummary: true),
        );
        expect((await repo.notificationSettings()).dailySummary, isTrue);
        expect(
          await upgraded.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await upgraded.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
