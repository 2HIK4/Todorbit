import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../app/app_controller.dart';
import '../../app/privacy_manager.dart';
import '../../data/life_repository.dart';
import '../../data/appearance_preference_store.dart';
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
  Set<String> pendingReceipts = const {},
  Set<String> deliveredReceipts = const {},
}) {
  final plans = <Map<String, Object>>[];
  void add(String key, DateTime at, String title, String link, String body) {
    final receipt = key.startsWith('due:') || key.startsWith('summary:')
        ? key
        : '$key:${at.millisecondsSinceEpoch}';
    if (deliveredReceipts.contains(receipt)) return;
    var delivery = outsideQuietHours(at, preferences);
    // Keep a bounded quiet-hour deferral when Doze delivered an earlier alarm
    // late. Native receipts use the original occurrence time to prevent repeats.
    if (!delivery.isAfter(now) &&
        pendingReceipts.contains(receipt) &&
        preferences.quietHours &&
        now.difference(at) < const Duration(hours: 24)) {
      delivery = outsideQuietHours(now, preferences);
    }
    // An inexact alarm may still be pending after its requested time. Keep
    // that known occurrence through refresh/resume, without reviving arbitrary
    // past reminders from an imported backup or replaying a delivered one.
    if (!delivery.isAfter(now) &&
        (!pendingReceipts.contains(receipt) ||
            now.difference(at) >= const Duration(hours: 24))) {
      return;
    }
    plans.add({
      'key': key,
      'at': delivery.millisecondsSinceEpoch,
      'occurrenceAt': at.millisecondsSinceEpoch,
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
      for (final session in sessions.where(
        (s) =>
            s.taskId == task.id &&
            s.outcome == SessionOutcome.upcoming &&
            !s.startsAt.isAfter(now),
      )) {
        final at = session.startsAt.subtract(
          Duration(minutes: notification.minutesBefore),
        );
        final key = 'task:${task.id}:session:${session.id}';
        if (!pendingReceipts.contains('$key:${at.millisecondsSinceEpoch}')) {
          continue;
        }
        add(
          key,
          at,
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
  for (var n = -1; n < 7; n++) {
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
        '${tasks.where((t) => t.isOpen && t.scheduledDate == day).length} planned · ${tasks.where((t) => t.isOpen && t.deadlineDate != null && t.deadlineDate!.compareTo(day) <= 0).length} due or overdue',
      );
    }
    if (settings.dueReminders) {
      for (final task in tasks.where(
        (t) =>
            t.isOpen &&
            t.deadlineDate != null &&
            t.deadlineDate!.compareTo(day) <= 0,
      )) {
        add(
          'due:${task.id}:$day',
          time,
          task.title,
          mobileLink('task', id: task.id),
          task.deadlineDate == day ? 'Task deadline today' : 'Overdue task',
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
  final appearance = await (await AppearancePreferenceStore.openDefault())
      .loadCustomization();
  final preferences = await MobilePreferenceStore.forActiveProfile().load();
  final now = DateTime.now();
  final today = localDate(now);
  final through = localDate(DateTime(now.year, now.month, now.day + 90));
  final tasks = await repository.tasks();
  final sessions = await repository.sessions();
  final categories = await repository.categories();
  final events = await repository.eventOccurrences(
    localDate(DateTime(now.year, now.month, now.day - 1)),
    through,
  );
  final settings = await repository.notificationSettings();
  final receipts = await AndroidPlatform.channel
      .invokeMapMethod<String, dynamic>('reminderReceipts');
  final agenda = <Map<String, Object>>[
    for (final e in events.where(
      (e) =>
          !e.cancelled &&
          e.endsAt.isAfter(DateTime(now.year, now.month, now.day)),
    ))
      {
        'kind': 'event',
        'color':
            ?e.colorValue ??
            categories
                .where((c) => c.id == e.categoryId)
                .firstOrNull
                ?.eventColor,
        'allDay': e.allDay,
        'title': e.title,
        'day': localDate(e.startsAt.toLocal()),
        'through': localDate(
          e.endsAt.subtract(const Duration(microseconds: 1)).toLocal(),
        ),
        'at': e.startsAt.millisecondsSinceEpoch,
        'until': e.endsAt.millisecondsSinceEpoch,
        'detail':
            '${localDate(e.startsAt.toLocal())} · ${e.allDay ? 'All day' : '${e.startsAt.toLocal().hour.toString().padLeft(2, '0')}:${e.startsAt.toLocal().minute.toString().padLeft(2, '0')}'}',
        'link': mobileLink(
          'event',
          id: e.id,
          day: localDate(e.startsAt.toLocal()),
          nominal: e.nominalDate,
        ),
      },
    for (final s in sessions.where(
      (s) => s.endsAt.isAfter(now) && s.outcome == SessionOutcome.upcoming,
    ))
      {
        'kind': 'session',
        'title':
            tasks.where((t) => t.id == s.taskId).firstOrNull?.title ??
            'Work session',
        'day': localDate(s.startsAt.toLocal()),
        'at': s.startsAt.millisecondsSinceEpoch,
        'until': s.endsAt.millisecondsSinceEpoch,
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
      'palettes': {
        'light': appearance.light.toJson(),
        'dark': appearance.dark.toJson(),
      },
      'private': privacy.enabled,
      'hidePreview': privacy.enabled,
      'suppressNotifications': privacy.enabled && privacy.hideNotifications,
      'tasks': [
        for (final t
            in tasks
                .where(
                  (t) =>
                      t.isOpen ||
                      t.status == TaskStatus.completed &&
                          (t.scheduledDate == today ||
                              localDate(t.updatedAt.toLocal()) == today),
                )
                .take(500))
          {
            'id': t.id,
            'revision': t.revision,
            'due': t.deadlineDate ?? '',
            'title': t.title,
            'day': t.scheduledDate ?? '',
            'done': t.status == TaskStatus.completed,
            'inbox': t.categoryId == null && t.projectId == null,
            'detail': t.deadlineDate == null
                ? switch (t.status) {
                    TaskStatus.notStarted => 'Not started',
                    TaskStatus.inProgress => 'In progress',
                    TaskStatus.waiting => 'Waiting',
                    TaskStatus.onHold => 'On hold',
                    TaskStatus.completed => 'Completed',
                    TaskStatus.cancelled => 'Cancelled',
                  }
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
        pendingReceipts: ((receipts?['pending'] as List?) ?? [])
            .cast<String>()
            .toSet(),
        deliveredReceipts: ((receipts?['delivered'] as List?) ?? [])
            .cast<String>()
            .toSet(),
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
    // Lock/screenshot policy must reach the activity immediately, including
    // when the user backgrounds the app before the projection debounce fires.
    unawaited(
      AndroidPlatform.protectScreen(privacy.enabled).catchError((Object _) {}),
    );
    unawaited(
      AndroidPlatform.channel
          .invokeMethod<void>('uiUnlocked', !privacy.locked)
          .catchError((Object _) {}),
    );
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () {
      writes = writes.catchError((Object _) {}).then((_) async {
        if (disposed) return;
        try {
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
