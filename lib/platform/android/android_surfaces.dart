import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../app/app_controller.dart';
import '../../app/privacy_manager.dart';
import '../../data/life_repository.dart';
import '../../data/mobile_preference_store.dart';
import '../../data/privacy_store.dart';
import '../../domain/models.dart';
import '../../domain/notifications.dart';
import 'android_platform.dart';

String mobileLink(String kind, {String? id, String? day, String? nominal}) =>
    Uri(
      scheme: 'todorbit',
      host: kind,
      queryParameters: {'id': ?id, 'day': ?day, 'nominal': ?nominal},
    ).toString();

DateTime outsideQuietHours(DateTime instant, MobilePreferences preferences) {
  if (!preferences.quietHours ||
      preferences.quietStart == preferences.quietEnd) {
    return instant;
  }
  final local = instant.toLocal();
  final minute = local.hour * 60 + local.minute;
  final start = preferences.quietStart, end = preferences.quietEnd;
  final overnight = start > end;
  final quiet = overnight
      ? minute >= start || minute < end
      : minute >= start && minute < end;
  if (!quiet) return instant;
  return DateTime(
    local.year,
    local.month,
    local.day + (overnight && minute >= start ? 1 : 0),
    end ~/ 60,
    end % 60,
  ).toUtc();
}

/// Projects reminders from the same explicit task/session/event semantics as Windows.
List<Map<String, Object>> androidReminderPlan({
  required List<LifeTask> tasks,
  required List<WorkSession> sessions,
  required List<FixedEvent> events,
  required DateTime now,
  required MobilePreferences preferences,
  NotificationSettings settings = const NotificationSettings(),
}) {
  final plans = <Map<String, Object>>[];
  void add(String key, DateTime at, String title, String link, String body) {
    // Do not resurrect expired custom reminders after a restore/reboot.
    if (!at.isAfter(now)) return;
    final delivery = outsideQuietHours(at, preferences);
    plans.add({
      'key': key,
      'at': delivery.millisecondsSinceEpoch,
      'title': title,
      'body': body,
      'link': link,
    });
  }

  for (final task in tasks.where((t) => t.isOpen && t.notification.enabled)) {
    final notification = task.notification;
    if (notification.mode == 'custom' && notification.at != null) {
      add(
        'task:${task.id}:custom',
        notification.at!,
        task.title,
        mobileLink('task', id: task.id),
        'Task reminder',
      );
    } else if (notification.mode == 'session') {
      final upcoming =
          sessions
              .where(
                (s) =>
                    s.taskId == task.id &&
                    s.outcome == SessionOutcome.upcoming &&
                    s.startsAt.isAfter(now),
              )
              .toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      if (upcoming.isNotEmpty) {
        final session = upcoming.first;
        add(
          'task:${task.id}:session:${session.id}',
          session.startsAt.subtract(
            Duration(minutes: notification.minutesBefore),
          ),
          task.title,
          mobileLink(
            'session',
            id: session.id,
            day: localDate(session.startsAt.toLocal()),
          ),
          'Scheduled work session',
        );
      }
    }
  }
  for (final e in events.where(
    (e) => !e.cancelled && e.reminderMinutes != null,
  )) {
    add(
      'event:${e.id}:${e.nominalDate ?? e.startsAt.toUtc().toIso8601String()}',
      e.startsAt.subtract(Duration(minutes: e.reminderMinutes!)),
      e.title,
      mobileLink(
        'event',
        id: e.id,
        day: localDate(e.startsAt.toLocal()),
        nominal: e.nominalDate,
      ),
      'Calendar event',
    );
  }
  final local = now.toLocal();
  for (var n = 0; n < 7; n++) {
    final time = DateTime(
      local.year,
      local.month,
      local.day + n,
      settings.localMinute ~/ 60,
      settings.localMinute % 60,
    );
    final day = localDate(time);
    if (settings.dailySummary) {
      add(
        'summary:$day',
        time,
        'Your Todorbit day',
        mobileLink('tasks', day: day),
        'Open your daily plan',
      );
    }
    if (settings.dueReminders) {
      for (final task in tasks.where(
        (t) => t.isOpen && t.deadlineDate == day,
      )) {
        add(
          'due:${task.id}:$day',
          time,
          task.title,
          mobileLink('task', id: task.id),
          'Task deadline today',
        );
      }
    }
  }
  plans.sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
  return plans.take(64).toList();
}

Future<void> publishAndroidRepository(
  LifeRepository repository,
  PrivacySettings privacy,
) async {
  final preferences = await MobilePreferenceStore.forActiveProfile().load();
  final now = DateTime.now();
  final today = localDate(now);
  final through = localDate(DateTime(now.year, now.month, now.day + 90));
  final tasks = await repository.tasks();
  final sessions = await repository.sessions();
  final events = await repository.eventOccurrences(today, through);
  final settings = await repository.notificationSettings();
  final agenda = <Map<String, Object>>[
    for (final e in events.where((e) => !e.cancelled))
      {
        'title': e.title,
        'day': localDate(e.startsAt.toLocal()),
        'through': localDate(e.endsAt.toLocal()),
        'at': e.startsAt.millisecondsSinceEpoch,
        'detail':
            '${localDate(e.startsAt.toLocal())} · ${e.allDay ? 'All day' : '${e.startsAt.toLocal().hour.toString().padLeft(2, '0')}:${e.startsAt.toLocal().minute.toString().padLeft(2, '0')}'}',
        'link': mobileLink(
          'event',
          id: e.id,
          day: localDate(e.startsAt.toLocal()),
          nominal: e.nominalDate,
        ),
      },
    for (final s in sessions.where((s) => s.endsAt.isAfter(now)))
      {
        'title':
            tasks.where((t) => t.id == s.taskId).firstOrNull?.title ??
            'Work session',
        'day': localDate(s.startsAt.toLocal()),
        'at': s.startsAt.millisecondsSinceEpoch,
        'detail': '${localDate(s.startsAt.toLocal())} · Work session',
        'link': mobileLink(
          'session',
          id: s.id,
          day: localDate(s.startsAt.toLocal()),
        ),
      },
  ]..sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
  await AndroidPlatform.channel.invokeMethod<void>(
    'publish',
    jsonEncode({
      'version': 1,
      'private': privacy.enabled,
      'hidePreview': privacy.enabled,
      'suppressNotifications': privacy.enabled && privacy.hideNotifications,
      'tasks': [
        for (final t
            in tasks
                .where((t) => t.isOpen || t.scheduledDate == today)
                .take(500))
          {
            'id': t.id,
            'title': t.title,
            'day': t.scheduledDate ?? '',
            'done': t.status == TaskStatus.completed,
            'inbox': t.categoryId == null && t.projectId == null,
            'detail': t.deadlineDate == null
                ? t.status.name
                : 'Due ${t.deadlineDate}',
            'link': mobileLink('task', id: t.id),
          },
      ],
      'agenda': agenda.take(100).toList(),
      'reminders': androidReminderPlan(
        tasks: tasks,
        sessions: sessions,
        events: events,
        now: now,
        preferences: preferences,
        settings: settings,
      ),
    }),
  );
}

class AndroidSurfaceCoordinator {
  AndroidSurfaceCoordinator(this.controller, this.privacy) {
    controller.addListener(changed);
    privacy.addListener(changed);
    changed();
  }
  final AppController controller;
  final PrivacyManager privacy;
  Timer? debounce;
  Future<void> writes = Future.value();
  bool disposed = false;
  void changed() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () {
      writes = writes.catchError((Object _) {}).then((_) async {
        if (disposed) return;
        try {
          await AndroidPlatform.protectScreen(privacy.enabled);
          await publishAndroidRepository(
            controller.repository,
            privacy.settings,
          );
        } catch (_) {
          debugPrint('Android surface refresh failed; open Todorbit to retry.');
        }
      });
    });
  }

  void dispose() {
    disposed = true;
    debounce?.cancel();
    controller.removeListener(changed);
    privacy.removeListener(changed);
  }
}
