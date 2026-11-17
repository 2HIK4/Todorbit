import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/saved_views.dart';
import 'package:life_manager/features/calendar/calendar_models.dart';
import 'package:life_manager/features/calendar/calendar_month_view.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/calendar_week_view.dart';

class RecordingRepository extends LifeRepository {
  RecordingRepository(super.db);
  final wideWindows = <(String, String)>[];
  final entered = Completer<void>();
  final release = Completer<void>();
  bool blockFirstWindow = false;
  bool failNextWindow = false;

  @override
  Future<void> ensureRecurringTasks(String fromDate, String throughDate) async {
    if (RecurrenceRule.daysBetween(fromDate, throughDate) >= 80) {
      wideWindows.add((fromDate, throughDate));
      if (failNextWindow) {
        failNextWindow = false;
        throw StateError('Synthetic recurrence failure');
      }
      if (blockFirstWindow && wideWindows.length == 1) {
        entered.complete();
        await release.future;
      }
    }
    await super.ensureRecurringTasks(fromDate, throughDate);
  }
}

void main() {
  test(
    'explicit Side Panel preference overrides a theme presentation value',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final c = AppController(LifeRepository(db));
      try {
        c.customization = c.customization.copyWith(
          detailPresentation: 'fullPage',
        );
        await c.setTaskViewPreferences(
          c.taskViewPreferences.copyWith(detailPresentation: 'sidePanel'),
        );
        expect(c.isFullPageDetails, isFalse);
        await c.setTaskViewPreferences(
          c.taskViewPreferences.copyWith(detailPresentation: 'fullPage'),
        );
        expect(c.isFullPageDetails, isTrue);
      } finally {
        c.dispose();
        await db.close();
      }
    },
  );

  test('prefetch covers exact previous/current/next civil months at year and leap boundaries', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = RecordingRepository(db);
    final c = AppController(repo);
    try {
      final edgeEvents = <String>[];
      for (final edge in [DateTime(2026, 12, 1, 9), DateTime(2027, 2, 28, 9)]) {
        final event = await repo.addEvent(
          EventDraft(
            title: 'Boundary event',
            startsAt: edge,
            endsAt: edge.add(const Duration(hours: 1)),
          ),
        );
        edgeEvents.add(event.id);
      }
      for (final date in [
        DateTime(2027, 1),
        DateTime(2028, 2),
        DateTime(2027, 3),
        DateTime(2027, 8),
        DateTime(2027, 12),
      ]) {
        await c.ensureRecurringMonth(date);
        expect(
          c.eventWindowFrom,
          localDate(DateTime(date.year, date.month - 1, 1)),
        );
        expect(
          c.eventWindowThrough,
          localDate(DateTime(date.year, date.month + 2, 0)),
        );
        expect(
          RecurrenceRule.daysBetween(c.eventWindowFrom, c.eventWindowThrough),
          lessThanOrEqualTo(93),
        );
        if (date.year == 2027 && date.month == 1) {
          expect(c.events.map((event) => event.id), containsAll(edgeEvents));
        }
      }
      final count = repo.wideWindows.length;
      await c.ensureRecurringMonth(DateTime(2027, 12, 25));
      expect(
        repo.wideWindows,
        hasLength(count),
        reason:
            'Unchanged same-month requests must not rematerialize recurrence',
      );
    } finally {
      c.dispose();
      await db.close();
    }
  });

  test(
    'overlapping month loads serialize and coalesce to the latest request',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = RecordingRepository(db)..blockFirstWindow = true;
      final c = AppController(repo);
      try {
        final initial = c.ensureRecurringMonth(DateTime(2027, 1));
        await repo.entered.future;
        final intermediate = c.ensureRecurringMonth(DateTime(2027, 7));
        final latest = c.ensureRecurringMonth(DateTime(2027, 12));
        repo.release.complete();
        await Future.wait([initial, intermediate, latest]);
        expect(repo.wideWindows, hasLength(2));
        expect(c.eventWindowFrom, '2027-11-01');
        expect(c.eventWindowThrough, '2028-01-31');
      } finally {
        c.dispose();
        await db.close();
      }
    },
  );

  test(
    'failed month load keeps the previously confirmed window and can retry',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repo = RecordingRepository(db);
      final c = AppController(repo);
      try {
        await c.ensureRecurringMonth(DateTime(2027, 1));
        final previous = (c.eventWindowFrom, c.eventWindowThrough);
        repo.failNextWindow = true;
        await expectLater(
          c.ensureRecurringMonth(DateTime(2027, 12)),
          throwsStateError,
        );
        expect((c.eventWindowFrom, c.eventWindowThrough), previous);
        await c.ensureRecurringMonth(DateTime(2027, 12));
        expect(c.eventWindowThrough, '2028-01-31');
      } finally {
        c.dispose();
        await db.close();
      }
    },
  );

  test('assigned and unassigned event metadata survives organization Trash and restore', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    try {
      final category = await repo.addCategory('Assigned category');
      final project = await repo.addProject(category.id, 'Assigned project');
      final assigned = await repo.addEvent(
        EventDraft(
          title: 'Assigned event',
          startsAt: DateTime(2027, 1, 15, 9),
          endsAt: DateTime(2027, 1, 15, 10),
          categoryId: category.id,
          projectId: project.id,
        ),
      );
      final unassigned = await repo.addEvent(
        EventDraft(
          title: 'Unassigned event',
          startsAt: DateTime(2027, 1, 15, 11),
          endsAt: DateTime(2027, 1, 15, 12),
        ),
      );
      await repo.deleteCategory(category.id);
      expect((await repo.events()).single.id, unassigned.id);
      await repo.restoreTrashItem((await repo.trash()).single);
      final restored = (await repo.events()).firstWhere(
        (event) => event.id == assigned.id,
      );
      expect(
        (restored.categoryId, restored.projectId),
        (category.id, project.id),
      );
      await repo.deleteProject(project.id);
      expect((await repo.events()).single.id, unassigned.id);
      await repo.restoreTrashItem((await repo.trash()).single);
      final restoredAgain = (await repo.events()).firstWhere(
        (event) => event.id == assigned.id,
      );
      expect(
        (restoredAgain.categoryId, restoredAgain.projectId),
        (category.id, project.id),
      );
      final stillUnassigned = (await repo.events()).firstWhere(
        (event) => event.id == unassigned.id,
      );
      expect(
        (stillUnassigned.categoryId, stillUnassigned.projectId),
        (null, null),
      );
    } finally {
      await db.close();
    }
  });

  for (final calendarMode in ['month', 'week']) {
    testWidgets(
      '$calendarMode cache survives resize and invalidates for every shared data notification',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final repo = LifeRepository(db);
        final category = await repo.addCategory('Calendar category');
        final event = await repo.addEvent(
          EventDraft(
            title: 'Initial event',
            startsAt: DateTime(2026, 11, 15, 9),
            endsAt: DateTime(2026, 11, 15, 10),
            categoryId: category.id,
          ),
        );
        final task = await repo.addTask(
          const TaskDraft(title: 'Calendar task', scheduledDate: '2026-11-15'),
        );
        final session = await repo.addSession(
          SessionDraft(
            taskId: task.id,
            startsAt: DateTime(2026, 11, 15, 11),
            endsAt: DateTime(2026, 11, 15, 12),
          ),
        );
        final c = AppController(repo);
        c.navigate(WorkspaceView.calendar);
        c.lastCalendarMode = calendarMode;
        await c.ensureRecurringMonth(DateTime(2026, 11));
        await tester.binding.setSurfaceSize(const Size(1000, 800));
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appControllerProvider.overrideWith((ref) => c)],
              child: MaterialApp(
                home: Scaffold(
                  body: CalendarView(
                    initialDate: DateTime(2026, 11, 15),
                    onTaskTap: (_) {},
                    onSmartReschedule: () {},
                    onAddTask: (_) {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Map<DateTime, List<CalendarItem>> projection() =>
              calendarMode == 'month'
              ? tester
                    .widget<CalendarMonthView>(find.byType(CalendarMonthView))
                    .itemsByDay
              : tester
                    .widget<CalendarWeekView>(find.byType(CalendarWeekView))
                    .itemsByDay;
          final original = projection();
          await tester.binding.setSurfaceSize(const Size(900, 800));
          await tester.pumpAndSettle();
          expect(
            identical(projection(), original),
            isTrue,
            reason: 'Resize with unchanged data must reuse the projection',
          );

          await c.updateEvent(
            c.events.firstWhere((item) => item.id == event.id),
            EventDraft(
              title: 'Edited event',
              startsAt: DateTime(2026, 11, 16, 9),
              endsAt: DateTime(2026, 11, 16, 10),
              categoryId: category.id,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            projection()[DateTime(2026, 11, 15)]!.any(
              (item) => item.id == event.id,
            ),
            isFalse,
          );
          expect(
            projection()[DateTime(2026, 11, 16)]!
                .singleWhere((item) => item.id == event.id)
                .title,
            'Edited event',
          );
          await c.setCategoryEventColor(category.id, 0xff336699);
          await tester.pumpAndSettle();
          expect(
            projection()[DateTime(2026, 11, 16)]!.single.colorValue,
            0xff336699,
          );
          await repo.deletePlannedSession(session);
          await c.refresh();
          await tester.pumpAndSettle();
          expect(
            projection().values
                .expand((items) => items)
                .any((item) => item.id == session.id),
            isFalse,
          );
          await c.setComplete(
            c.tasks.firstWhere((item) => item.id == task.id),
            true,
          );
          await tester.pumpAndSettle();
          expect(
            projection()[DateTime(2026, 11, 15)]!.single.task!.status,
            TaskStatus.completed,
          );
          c.setFilter(const TaskFilter(text: 'Edited'));
          await tester.pumpAndSettle();
          expect(projection()[DateTime(2026, 11, 15)], isEmpty);
          c.setFilter(const TaskFilter());
          await c.deleteEvent(event.id);
          await tester.pumpAndSettle();
          expect(projection()[DateTime(2026, 11, 16)], isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await db.close();
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }
}
