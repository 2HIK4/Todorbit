import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/notifications.dart';
import 'package:life_manager/platform/android/android_surfaces.dart';

void main() {
  LifeTask task(
    String id, {
    TaskNotification notification = const TaskNotification(),
    TaskStatus status = TaskStatus.notStarted,
  }) => LifeTask(
    id: id,
    title: id,
    notes: '',
    status: status,
    priority: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    notification: notification,
  );
  test('mobile preferences round trip independently and reject future/malformed values', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-mobile-preferences-',
    );
    try {
      final store = MobilePreferenceStore(File('${root.path}/mobile.json'));
      final next = (await store.load()).copyWith(
        destinations: [
          WorkspaceView.inbox,
          WorkspaceView.calendar,
          WorkspaceView.today,
        ],
        start: WorkspaceView.inbox,
      );
      await store.save(next);
      expect((await store.load()).toJson(), next.toJson());
      await store.file.writeAsString(jsonEncode({'version': 999}));
      await expectLater(store.load(), throwsFormatException);
      expect(jsonDecode(await store.file.readAsString()), {'version': 999});
      expect(
        () => MobilePreferences.fromJson({
          ...next.toJson(),
          'destinations': ['today', 'today', 'all'],
        }),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('reminders are opt in, use session identity, exclude completed and expired tasks', () {
    final now = DateTime.utc(2026, 10, 28, 8);
    final future = now.add(const Duration(hours: 1));
    final tasks = [
      task('off'),
      task(
        'custom',
        notification: TaskNotification(mode: 'custom', at: future),
      ),
      task(
        'expired',
        notification: TaskNotification(
          mode: 'custom',
          at: now.subtract(const Duration(minutes: 1)),
        ),
      ),
      task(
        'completed',
        status: TaskStatus.completed,
        notification: TaskNotification(mode: 'custom', at: future),
      ),
      task(
        'session',
        notification: const TaskNotification(
          mode: 'session',
          minutesBefore: 15,
        ),
      ),
    ];
    final sessions = [
      WorkSession(
        id: 'stable-session',
        taskId: 'session',
        startsAt: future,
        endsAt: future.add(const Duration(hours: 1)),
        outcome: SessionOutcome.upcoming,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final plans = androidReminderPlan(
      tasks: tasks,
      sessions: sessions,
      events: [],
      now: now,
      preferences: const MobilePreferences(),
    );
    expect(plans.map((p) => p['key']), [
      'task:session:session:stable-session',
      'task:custom:custom',
    ]);
    expect(
      Uri.parse(plans.first['link'] as String).queryParameters['id'],
      'stable-session',
    );
    expect(
      plans.first['at'],
      future.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch,
    );
  });
  test(
    'quiet hours postpone across midnight without changing record identity',
    () {
      final preferences = const MobilePreferences(
        quietHours: true,
        quietStart: 1320,
        quietEnd: 420,
      );
      final night = DateTime(2026, 10, 28, 23, 30);
      expect(
        outsideQuietHours(night, preferences).toLocal(),
        DateTime(2026, 10, 29, 7),
      );
      expect(
        outsideQuietHours(DateTime(2026, 10, 28, 12), preferences).toLocal(),
        DateTime(2026, 10, 28, 12),
      );
    },
  );
}
