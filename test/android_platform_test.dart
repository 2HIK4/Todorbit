import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/app/privacy_manager.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/data/privacy_store.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/notifications.dart';
import 'package:life_manager/platform/android/android_surfaces.dart';
import 'package:life_manager/platform/android/android_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'screenshot and unlock policy do not wait for projection debounce',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-android-policy-',
      );
      final database = AppDatabase(NativeDatabase.memory());
      final controller = AppController(LifeRepository(database));
      final privacy = PrivacyManager(
        PrivacyStore(File('${root.path}/privacy.json')),
        const PrivacySettings(enabled: true),
      );
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AndroidPlatform.channel, (call) async {
        calls.add(call);
        return null;
      });
      final surfaces = AndroidSurfaceCoordinator(controller, privacy);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(calls.map((call) => call.method), [
          'protectScreen',
          'uiUnlocked',
        ]);
        expect(calls.first.arguments, isTrue);
        expect(calls.last.arguments, isFalse);
      } finally {
        surfaces.dispose();
        controller.dispose();
        await privacy.shutdown();
        privacy.dispose();
        messenger.setMockMethodCallHandler(AndroidPlatform.channel, null);
        await database.close();
        await root.delete(recursive: true);
      }
    },
  );
  LifeTask task(
    String id, {
    TaskNotification notification = const TaskNotification(),
    TaskStatus status = TaskStatus.notStarted,
    String? deadline,
    String? planned,
  }) => LifeTask(
    id: id,
    title: id,
    notes: '',
    status: status,
    priority: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    notification: notification,
    deadlineDate: deadline,
    scheduledDate: planned,
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
      await expectLater(store.save(next), throwsFormatException);
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
  test(
    'quiet-hour replanning retains the original reminder receipt identity',
    () {
      final original = DateTime(2026, 10, 27, 21, 30);
      final now = DateTime(2026, 10, 28, 2);
      final plans = androidReminderPlan(
        tasks: [
          task(
            'late',
            notification: TaskNotification(
              mode: 'custom',
              at: original.toUtc(),
            ),
          ),
        ],
        sessions: [],
        events: [],
        now: now,
        preferences: const MobilePreferences(quietHours: true),
        pendingReceipts: {
          'task:late:custom:${original.millisecondsSinceEpoch}',
        },
      );
      expect(plans.single['occurrenceAt'], original.millisecondsSinceEpoch);
      expect(
        plans.single['at'],
        DateTime(2026, 10, 28, 7).millisecondsSinceEpoch,
      );
    },
  );
  test('refresh preserves pending late reminders but drops delivered, changed and stale occurrences', () {
    final now = DateTime.utc(2026, 10, 28, 8);
    final late = now.subtract(const Duration(minutes: 2));
    final stale = now.subtract(const Duration(hours: 24));
    final plans = androidReminderPlan(
      tasks: [
        for (final id in ['pending', 'delivered', 'changed', 'imported'])
          task(
            id,
            notification: TaskNotification(mode: 'custom', at: late),
          ),
        task(
          'stale',
          notification: TaskNotification(mode: 'custom', at: stale),
        ),
        task(
          'completed',
          status: TaskStatus.completed,
          notification: TaskNotification(mode: 'custom', at: late),
        ),
      ],
      sessions: [],
      events: [],
      now: now,
      preferences: const MobilePreferences(),
      pendingReceipts: {
        'task:pending:custom:${late.millisecondsSinceEpoch}',
        'task:delivered:custom:${late.millisecondsSinceEpoch}',
        'task:changed:custom:${late.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch}',
        'task:stale:custom:${stale.millisecondsSinceEpoch}',
        'task:completed:custom:${late.millisecondsSinceEpoch}',
      },
      deliveredReceipts: {
        'task:delivered:custom:${late.millisecondsSinceEpoch}',
      },
    );
    expect(plans.single['key'], 'task:pending:custom');
    expect(plans.single['occurrenceAt'], late.millisecondsSinceEpoch);
  });
  test('late session and previous-day reminder survive midnight refresh', () {
    final now = DateTime(2026, 10, 29, 0, 5);
    final start = now.subtract(const Duration(minutes: 10));
    final at = start.subtract(const Duration(minutes: 15));
    final plans = androidReminderPlan(
      tasks: [
        task(
          'session',
          notification: const TaskNotification(
            mode: 'session',
            minutesBefore: 15,
          ),
        ),
      ],
      sessions: [
        WorkSession(
          id: 'late-session',
          taskId: 'session',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 1)),
          outcome: SessionOutcome.upcoming,
          createdAt: now,
          updatedAt: now,
        ),
        WorkSession(
          id: 'next-session',
          taskId: 'session',
          startsAt: now.add(const Duration(hours: 2)),
          endsAt: now.add(const Duration(hours: 3)),
          outcome: SessionOutcome.upcoming,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      events: [],
      now: now,
      preferences: const MobilePreferences(),
      settings: const NotificationSettings(dailySummary: true),
      pendingReceipts: {
        'task:session:session:late-session:${at.millisecondsSinceEpoch}',
        'summary:2026-10-28',
      },
    );
    expect(
      plans.map((p) => p['key']),
      containsAll([
        'task:session:session:late-session',
        'task:session:session:next-session',
        'summary:2026-10-28',
      ]),
    );
  });
  test('delivered reminders cannot fill the native pending alarm limit', () {
    final now = DateTime.utc(2026, 10, 28, 8);
    final at = now.add(const Duration(hours: 1));
    final plans = androidReminderPlan(
      tasks: [
        for (var i = 0; i < 70; i++)
          task(
            '$i',
            notification: TaskNotification(mode: 'custom', at: at),
          ),
      ],
      sessions: [],
      events: [],
      now: now,
      preferences: const MobilePreferences(),
      deliveredReceipts: {
        for (var i = 0; i < 65; i++)
          'task:$i:custom:${at.millisecondsSinceEpoch}',
      },
    );
    expect(plans.map((p) => p['key']), [
      for (var i = 65; i < 70; i++) 'task:$i:custom',
    ]);
  });
  test(
    'daily reminders include overdue work and summaries use real task counts',
    () {
      final now = DateTime(2026, 10, 28, 8);
      final plans = androidReminderPlan(
        tasks: [
          task('overdue', deadline: '2026-10-27', planned: '2026-10-28'),
          task('future', deadline: '2026-10-29'),
          task('done', deadline: '2026-10-27', status: TaskStatus.completed),
        ],
        sessions: [],
        events: [],
        now: now,
        preferences: const MobilePreferences(),
        settings: const NotificationSettings(
          dueReminders: true,
          dailySummary: true,
        ),
      );
      expect(plans.any((p) => p['key'] == 'due:overdue:2026-10-28'), isTrue);
      expect(plans.any((p) => p['key'] == 'due:future:2026-10-28'), isFalse);
      expect(
        plans.any((p) => (p['key'] as String).startsWith('due:done:')),
        isFalse,
      );
      expect(
        plans.firstWhere((p) => p['key'] == 'summary:2026-10-28')['body'],
        '1 planned · 1 due or overdue',
      );
    },
  );
}
