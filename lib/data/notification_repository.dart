part of 'life_repository.dart';

extension NotificationRepository on LifeRepository {
  Future<NotificationSettings> notificationSettings() async {
    final row = await db
        .customSelect(
          'SELECT due_reminders,daily_summary,local_minute FROM notification_settings WHERE id=1',
        )
        .getSingleOrNull();
    if (row == null) return const NotificationSettings();
    return NotificationSettings(
      dueReminders: row.read<int>('due_reminders') == 1,
      dailySummary: row.read<int>('daily_summary') == 1,
      localMinute: row.read<int>('local_minute'),
    );
  }

  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    if (settings.localMinute < 0 || settings.localMinute > 1439) {
      throw ArgumentError.value(settings.localMinute, 'localMinute');
    }
    await db.customStatement(
      '''
      INSERT INTO notification_settings
        (id,due_reminders,daily_summary,local_minute,updated_at)
      VALUES(1,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET
        due_reminders=excluded.due_reminders,
        daily_summary=excluded.daily_summary,
        local_minute=excluded.local_minute,
        updated_at=excluded.updated_at
    ''',
      [
        settings.dueReminders ? 1 : 0,
        settings.dailySummary ? 1 : 0,
        settings.localMinute,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }
}
