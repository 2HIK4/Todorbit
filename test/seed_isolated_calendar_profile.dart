// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/profile_paths.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  test('seed isolated calendar profile with representative synthetic data', () async {
    final profileDir = ProfilePaths.activeDirectory();
    print('Seeding database in: ${profileDir.path}');
    await profileDir.create(recursive: true);

    final db = await AppDatabase.openDefault();
    final repo = LifeRepository(db);

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = localDate(today);

      // 1. Standup (09:00 - 09:30)
      await repo.addEvent(
        EventDraft(
          title: 'Morning Standup',
          startsAt: DateTime(today.year, today.month, today.day, 9, 0),
          endsAt: DateTime(today.year, today.month, today.day, 9, 30),
          colorValue: 0xFF2563EB,
        ),
      );

      // 2. Overlapping 3-lane collision cluster (10:00 - 12:00)
      // Event A: 10:00 - 11:30
      await repo.addEvent(
        EventDraft(
          title: 'Sprint Planning',
          startsAt: DateTime(today.year, today.month, today.day, 10, 0),
          endsAt: DateTime(today.year, today.month, today.day, 11, 30),
          colorValue: 0xFF0D9488,
        ),
      );

      // Event B: 10:30 - 12:00 (overlaps with A and C)
      await repo.addEvent(
        EventDraft(
          title: 'Architecture Review',
          startsAt: DateTime(today.year, today.month, today.day, 10, 30),
          endsAt: DateTime(today.year, today.month, today.day, 12, 0),
          colorValue: 0xFF7C3AED,
        ),
      );

      // Event C: 10:45 - 11:15 (nested inside A and B)
      await repo.addEvent(
        EventDraft(
          title: 'Design Check-in',
          startsAt: DateTime(today.year, today.month, today.day, 10, 45),
          endsAt: DateTime(today.year, today.month, today.day, 11, 15),
          colorValue: 0xFFEA580C,
        ),
      );

      // 3. Recurring Event (Daily team sync 13:00 - 13:30)
      await repo.addEvent(
        EventDraft(
          title: 'Daily Team Sync',
          startsAt: DateTime(today.year, today.month, today.day, 13, 0),
          endsAt: DateTime(today.year, today.month, today.day, 13, 30),
          repeat: const EventRepeat(kind: EventRepeatKind.daily),
          colorValue: 0xFF059669,
        ),
      );

      // 4. Afternoon Deep Work (14:00 - 15:30)
      await repo.addEvent(
        EventDraft(
          title: 'Deep Work: Calendar Engine',
          startsAt: DateTime(today.year, today.month, today.day, 14, 0),
          endsAt: DateTime(today.year, today.month, today.day, 15, 30),
          colorValue: 0xFF4F46E5,
        ),
      );

      // 5. Task with planned date and distinct deadline
      final task = await repo.addTask(
        TaskDraft(
          title: 'Submit Quarterly Report',
          notes: 'Prepare slides and financial metrics',
          scheduledDate: todayStr,
          deadlineDate: localDate(today.add(const Duration(days: 7))),
          plannedDurationMinutes: 60,
          priority: 2,
        ),
      );

      // 6. Work session linked to the task (16:00 - 17:00)
      await repo.addSession(
        SessionDraft(
          taskId: task.id,
          startsAt: DateTime(today.year, today.month, today.day, 16, 0),
          endsAt: DateTime(today.year, today.month, today.day, 17, 0),
        ),
      );

      // 7. All-day event
      await repo.addEvent(
        EventDraft(
          title: 'Q4 Strategy Offsite',
          startsAt: today,
          endsAt: today.add(const Duration(days: 1)),
          allDay: true,
          colorValue: 0xFFDC2626,
        ),
      );

      // 8. Untimed planned task
      await repo.addTask(
        TaskDraft(
          title: 'Review Pull Request #42',
          scheduledDate: todayStr,
          priority: 1,
        ),
      );

      // 9. Across the week (yesterday, tomorrow, +2 days)
      final yesterday = today.subtract(const Duration(days: 1));
      await repo.addEvent(
        EventDraft(
          title: 'Client Demo & Feedback',
          startsAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 11, 0),
          endsAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 12, 0),
          colorValue: 0xFF2563EB,
        ),
      );

      final tomorrow = today.add(const Duration(days: 1));
      await repo.addEvent(
        EventDraft(
          title: '1-on-1 with Tech Lead',
          startsAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0),
          endsAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15, 0),
          colorValue: 0xFF0D9488,
        ),
      );

      final twoDaysLater = today.add(const Duration(days: 2));
      await repo.addEvent(
        EventDraft(
          title: 'Weekly Retrospective',
          startsAt: DateTime(twoDaysLater.year, twoDaysLater.month, twoDaysLater.day, 15, 0),
          endsAt: DateTime(twoDaysLater.year, twoDaysLater.month, twoDaysLater.day, 16, 30),
          colorValue: 0xFF7C3AED,
        ),
      );

      print('Successfully seeded synthetic calendar data into isolated profile.');
    } finally {
      await db.close();
    }
  });
}
