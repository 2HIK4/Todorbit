import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/shared/weekdays.dart';
import 'package:life_manager/features/settings/sidebar_order_dialog.dart';
import 'package:life_manager/main.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'test_privacy.dart';

void main() {
  testWidgets('sidebar order controls update navigation immediately', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    final db = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(db));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: SidebarOrderDialog())),
        ),
      );
      await tester.tap(find.byTooltip('Move Today down'));
      await tester.pumpAndSettle();
      expect(controller.sidebarOrder.first, WorkspaceView.all);
      await tester.tap(find.text('Reset to default'));
      await tester.pumpAndSettle();
      expect(controller.sidebarOrder, AppController.defaultSidebarOrder);
      await tester.drag(find.byType(ReorderableDragStartListener).first,
          const Offset(0, 90));
      await tester.pumpAndSettle();
      expect(controller.sidebarOrder.first, WorkspaceView.all);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('month view and weekday headers survive navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    final db = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(db));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            privacyOverride,
          ],
          child: const LifeManagerApp(),
        ),
      );
      await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
      await tester.pumpAndSettle();
      expect(
        MaterialLocalizations.of(tester.element(find.byType(CalendarView)))
            .firstDayOfWeekIndex,
        0,
      );
      await controller.setFirstWeekday(DateTime.monday);
      await tester.pumpAndSettle();
      expect(
        MaterialLocalizations.of(tester.element(find.byType(CalendarView)))
            .firstDayOfWeekIndex,
        1,
      );
      await controller.setFirstWeekday(DateTime.sunday);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(controller.lastCalendarMode, 'month');
      expect(find.text('Sun'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<CalendarMode>>(
              find.byType(SegmentedButton<CalendarMode>),
            )
            .selected,
        {CalendarMode.month},
      );
      expect(find.text('Sun'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  test(
    'navigation, week start, and last calendar view persist per profile',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-calendar-settings-',
      );
      final file = File('${root.path}${Platform.pathSeparator}appearance.json');
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final controller = AppController(
          LifeRepository(db),
          appearanceStore: AppearancePreferenceStore(file),
        );
        await controller.initialize();
        expect(controller.firstWeekday, DateTime.sunday);
        expect(controller.lastCalendarMode, isNull);
        expect(controller.sidebarOrder, AppController.defaultSidebarOrder);
        await controller.setFirstWeekday(DateTime.wednesday);
        await controller.setLastCalendarMode('month');
        final reversed = AppController.defaultSidebarOrder.reversed.toList();
        await controller.setSidebarOrder(reversed);
        final reopened = AppController(
          LifeRepository(db),
          appearanceStore: AppearancePreferenceStore(file),
        );
        await reopened.initialize();
        expect(reopened.firstWeekday, DateTime.wednesday);
        expect(reopened.lastCalendarMode, 'month');
        expect(reopened.sidebarOrder, reversed);
        expect(weekdaysFrom(reopened.firstWeekday), [3, 4, 5, 6, 7, 1, 2]);
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'event details, custom types, and category color survive database reopen',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-event-details-',
      );
      final file = File('${root.path}${Platform.pathSeparator}events.sqlite');
      try {
        final first = AppDatabase(NativeDatabase(file));
        final repo = LifeRepository(first);
        final category = await repo.addCategory('Classes');
        await repo.setCategoryEventColor(category.id, 0xFF123456);
        final type = await repo.addEventDetailType('Instructor');
        final event = await repo.addEvent(
          EventDraft(
            title: 'Lecture',
            startsAt: DateTime(2026, 10, 25, 9),
            endsAt: DateTime(2026, 10, 25, 10),
            categoryId: category.id,
            repeat: const EventRepeat(kind: EventRepeatKind.weekly),
            details: [
              EventDetail(typeId: type.id, label: type.name, value: 'Dr. Lee'),
            ],
          ),
        );
        expect(event.colorValue, isNull);
        final controller = AppController(repo);
        await controller.refresh();
        expect(controller.effectiveEventColor(event), 0xFF123456);
        final explicit = await repo.addEvent(
          EventDraft(
            title: 'Override',
            startsAt: DateTime(2026, 10, 25, 11),
            endsAt: DateTime(2026, 10, 25, 12),
            categoryId: category.id,
            colorValue: 0xFFABCDEF,
          ),
        );
        expect(controller.effectiveEventColor(explicit), 0xFFABCDEF);
        await repo.deleteEventDetailType(type.id);
        await first.close();
        final second = AppDatabase(NativeDatabase(file));
        final reopened = LifeRepository(second);
        final saved = (await reopened.events()).firstWhere(
          (item) => item.id == event.id,
        );
        expect(saved.details.single.label, 'Instructor');
        expect(saved.details.single.value, 'Dr. Lee');
        expect(
          (await reopened.eventOccurrences(
            '2026-11-01',
            '2026-11-01',
          )).single.details.single.value,
          'Dr. Lee',
        );
        expect((await reopened.categories()).single.eventColor, 0xFF123456);
        expect(
          (await reopened.events())
              .firstWhere((item) => item.id == explicit.id)
              .colorValue,
          0xFFABCDEF,
        );
        await second.close();
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('schema 20 location is migrated into event details', () async {
    final root = await Directory.systemTemp.createTemp(
      'todorbit-location-migration-',
    );
    final file = File('${root.path}${Platform.pathSeparator}events.sqlite');
    try {
      final first = AppDatabase(NativeDatabase(file));
      await LifeRepository(first).addEvent(
        EventDraft(
          title: 'Meeting',
          location: 'Room 204',
          startsAt: DateTime(2026, 10, 25, 9),
          endsAt: DateTime(2026, 10, 25, 10),
        ),
      );
      await first.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('ALTER TABLE fixed_events DROP COLUMN details_json');
      raw.execute('ALTER TABLE categories DROP COLUMN event_color');
      raw.execute('DROP TABLE event_detail_types');
      raw.execute('PRAGMA user_version=20');
      raw.close();
      final second = AppDatabase(NativeDatabase(file));
      final event = (await LifeRepository(second).events()).single;
      expect(event.location, 'Room 204');
      expect(event.details.single.value, 'Room 204');
      await second.close();
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('duration uses full dates and all-day calendar days', () {
    expect(
      eventDurationLabel(
        DateTime(2026, 10, 1, 23, 30),
        DateTime(2026, 10, 2, 1),
      ),
      '1 hour 30 minutes',
    );
    expect(
      eventDurationLabel(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 3),
        allDay: true,
      ),
      '2 days',
    );
    expect(
      eventDurationLabel(DateTime(2026, 10, 2), DateTime(2026, 10, 1)),
      'End must follow Start',
    );
  });
}
