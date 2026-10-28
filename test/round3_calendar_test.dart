import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/calendar_view.dart';
import 'package:life_manager/features/calendar/event_editor.dart';

void main() {
  test('month capacity grows with height and shrinks with text scale', () {
    expect(monthEntryCapacity(95, 1), lessThan(monthEntryCapacity(190, 1)));
    expect(monthEntryCapacity(190, 2), lessThan(monthEntryCapacity(190, 1)));
    expect(monthEntryCapacity(45, 1), 0);
  });

  test('undated tasks stay in Anytime until scheduled', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final controller = AppController(repo);
    try {
      final task = await repo.addTask(const TaskDraft(title: 'Learn Docker'));
      await controller.refresh();
      controller.navigate(WorkspaceView.anytime);
      expect(controller.visibleTasks.single.id, task.id);
      expect(controller.visibleTasks.single.deadlineDate, isNull);
      expect(controller.visibleTasks.single.scheduledDate, isNull);
      controller.navigate(WorkspaceView.all);
      expect(controller.visibleTasks.single.id, task.id);
    } finally {
      await db.close();
    }
  });

  testWidgets('month preview retains the grid and opens day only on request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final controller = AppController(repo);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${DateTime.now().day}').first);
      await tester.pumpAndSettle();
      expect(find.text('Open Day View'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      await tester.tap(find.text('Open Day View'));
      await tester.pumpAndSettle();
      expect(find.text('Time slots'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('month right click offers creation for the selected date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final db = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(db));
    await controller.refresh();
    DateTime? requestedTaskDate;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                initialDate: DateTime(2026, 10, 15),
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (date) => requestedTaskDate = date,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      final cell = find.text('15');
      await tester.tapAt(
        tester.getCenter(cell),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Event'), findsOneWidget);
      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();
      expect(localDate(requestedTaskDate!), '2026-10-15');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('event color selection persists', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    final db = AppDatabase(NativeDatabase.memory());
    final controller = AppController(LifeRepository(db));
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 460,
                  height: 650,
                  child: EventEditor(
                    initialDay: DateTime.now(),
                    onClose: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Ocean event',
      );
      await tester.ensureVisible(find.byType(PopupMenuButton<int>));
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ocean').last);
      await tester.tap(find.text('Ocean').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();
      expect(controller.events.single.colorValue, 0xFF3376A3);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('scheduled subtask shows its parent and opens the child', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final parent = await repo.addTask(
      const TaskDraft(title: 'Study Flutter Course'),
    );
    final child = await repo.addSubtask(
      parent,
      TaskDraft(
        title: 'Complete Dart Exercises',
        scheduledDate: localDate(DateTime.now()),
      ),
    );
    final controller = AppController(repo);
    await controller.refresh();
    LifeTask? opened;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                onTaskTap: (task) => opened = task,
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.text('Study Flutter Course'), findsOneWidget);
      expect(find.text('Complete Dart Exercises'), findsOneWidget);
      await tester.tap(find.text('Complete Dart Exercises'));
      await tester.pumpAndSettle();
      expect(opened?.id, child.id);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('cancelled event keeps its title with strikethrough', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day, 9);
    await repo.addEvent(
      EventDraft(
        title: 'Database Systems Lecture',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
        repeat: EventRepeat(
          kind: EventRepeatKind.weekdays,
          weekdays: {today.weekday},
        ),
      ),
    );
    final occurrence = (await repo.eventOccurrences(
      localDate(today),
      localDate(today),
    )).single;
    await repo.setEventOccurrenceCancelled(occurrence, true);
    final controller = AppController(repo);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      final titles = tester.widgetList<Text>(
        find.text('Database Systems Lecture'),
      );
      expect(titles, isNotEmpty);
      expect(
        titles.any(
          (title) => title.style?.decoration == TextDecoration.lineThrough,
        ),
        isTrue,
      );
      expect(
        find.textContaining('Cancelled Database Systems Lecture'),
        findsNothing,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('right-clicking a week entry does not open creation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    final db = AppDatabase(NativeDatabase.memory());
    final repo = LifeRepository(db);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day, 9);
    await repo.addEvent(
      EventDraft(
        title: 'Existing entry',
        startsAt: start,
        endsAt: start.add(const Duration(hours: 1)),
      ),
    );
    final controller = AppController(repo);
    await controller.refresh();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: CalendarView(
                onTaskTap: (_) {},
                onSmartReschedule: () {},
                onAddTask: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(
        tester.getCenter(find.text('Existing entry')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Event'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
