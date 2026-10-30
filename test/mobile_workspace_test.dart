import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/platform/android/android_surfaces.dart';
import 'package:life_manager/features/mobile/mobile_settings.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/settings/theme_dialog.dart';
import 'package:life_manager/features/settings/task_view_settings_dialog.dart';
import 'package:life_manager/features/templates/templates_dialog.dart';
import 'package:life_manager/features/search/advanced_search_dialog.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late AppController controller;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-mobile-test-');
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(database));
    await controller.refresh();
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool rtl = false,
    bool dark = false,
    String? link,
    bool locked = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            ),
          ),
          home: MobileWorkspace(
            initialLink: link,
            locked: locked,
            preferenceStore: MobilePreferenceStore(
              File('${root.path}/mobile.json'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cold task link wins over launch preference and opens exact ID', (
    tester,
  ) async {
    final first = await controller.repository.addTask(TaskDraft(title: 'Same'));
    final second = await controller.repository.addTask(
      TaskDraft(title: 'Same'),
    );
    await open(tester, link: mobileLink('task', id: second.id));
    expect(
      tester.widget<TaskEditor>(find.byType(TaskEditor)).task?.id,
      second.id,
    );
    expect(
      tester.widget<TaskEditor>(find.byType(TaskEditor)).task?.id,
      isNot(first.id),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('locked task link waits for unlock', (tester) async {
    final task = await controller.repository.addTask(
      TaskDraft(title: 'Private'),
    );
    final link = mobileLink('task', id: task.id);
    await open(tester, link: link, locked: true);
    expect(find.byType(TaskEditor), findsNothing);
    await open(tester, link: link);
    expect(
      tester.widget<TaskEditor>(find.byType(TaskEditor)).task?.id,
      task.id,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('calendar add link opens event editor with selected date', (
    tester,
  ) async {
    await open(tester, link: mobileLink('add-event', day: '2026-11-09'));
    final editor = tester.widget<EventEditor>(find.byType(EventEditor));
    expect(editor.event, isNull);
    expect(localDate(editor.initialDay), '2026-11-09');
    expect(find.byType(TaskEditor), findsNothing);
    expect(controller.view, WorkspaceView.calendar);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('same-title event link opens exact event, not task', (
    tester,
  ) async {
    final first = await controller.repository.addEvent(
      EventDraft(
        title: 'Same',
        startsAt: DateTime(2026, 11, 9, 9),
        endsAt: DateTime(2026, 11, 9, 10),
      ),
    );
    final second = await controller.repository.addEvent(
      EventDraft(
        title: 'Same',
        startsAt: DateTime(2026, 11, 9, 11),
        endsAt: DateTime(2026, 11, 9, 12),
      ),
    );
    await controller.repository.addTask(TaskDraft(title: 'Same'));
    await open(
      tester,
      link: mobileLink('event', id: second.id, day: '2026-11-09'),
    );
    final editor = tester.widget<EventEditor>(find.byType(EventEditor));
    expect(editor.event?.id, second.id);
    expect(editor.event?.id, isNot(first.id));
    expect(find.byType(TaskEditor), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recurring event link preserves occurrence identity', (
    tester,
  ) async {
    final event = await controller.repository.addEvent(
      EventDraft(
        title: 'Recurring',
        startsAt: DateTime(2026, 11, 2, 9),
        endsAt: DateTime(2026, 11, 2, 10),
        repeat: const EventRepeat(kind: EventRepeatKind.weekly),
      ),
    );
    final occurrence = (await controller.repository.eventOccurrences(
      '2026-11-09',
      '2026-11-09',
    )).single;
    await open(
      tester,
      link: mobileLink(
        'event',
        id: event.id,
        day: '2026-11-09',
        nominal: occurrence.nominalDate,
      ),
    );
    final editor = tester.widget<EventEditor>(find.byType(EventEditor));
    expect(editor.event?.id, event.id);
    expect(editor.event?.nominalDate, occurrence.nominalDate);
    expect(localDate(editor.event!.startsAt), '2026-11-09');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('running link waits for unsaved task editor to close', (
    tester,
  ) async {
    final first = await controller.repository.addTask(
      TaskDraft(title: 'First'),
    );
    final second = await controller.repository.addTask(
      TaskDraft(title: 'Second'),
    );
    await open(tester, link: mobileLink('task', id: first.id));
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Unsaved draft',
    );
    await open(tester, link: mobileLink('task', id: second.id));
    expect(
      tester.widget<TaskEditor>(find.byType(TaskEditor)).task?.id,
      first.id,
    );
    expect(find.text('Unsaved draft'), findsOneWidget);
    await tester.tap(find.byTooltip('Close details'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TaskEditor>(find.byType(TaskEditor)).task?.id,
      second.id,
    );
    expect(
      (await controller.repository.tasks())
          .singleWhere((t) => t.id == first.id)
          .title,
      'First',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scenario in [
    (const Size(320, 640), 1.0, false, false),
    (const Size(390, 844), 1.5, true, true),
    (const Size(840, 500), 1.3, false, false),
  ]) {
    testWidgets(
      'mobile shell and calendar adapt at ${scenario.$1} / ${scenario.$2}',
      (tester) async {
        try {
          await open(
            tester,
            size: scenario.$1,
            scale: scenario.$2,
            rtl: scenario.$3,
            dark: scenario.$4,
          );
          expect(find.text('Your day, in focus'), findsOneWidget);
          controller.navigate(WorkspaceView.calendar);
          await tester.pumpAndSettle();
          expect(find.text('Month'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }

  testWidgets('new task protects Back edits and saves with notifications off', (
    tester,
  ) async {
    try {
      await open(tester);
      await tester.tap(find.byTooltip('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Mobile task',
      );
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Create task'));
      await tester.pumpAndSettle();
      final saved = await controller.repository.tasks();
      expect(saved.single.title, 'Mobile task');
      expect(saved.single.notification.enabled, isFalse);
      expect(find.byType(TaskEditor), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('mobile task completion uses shared persistent rules', (
    tester,
  ) async {
    await controller.addTask(
      TaskDraft(title: 'Check this', scheduledDate: localDate(DateTime.now())),
    );
    try {
      await open(tester);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      final saved = await controller.repository.tasks();
      expect(saved.single.status, TaskStatus.completed);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets(
    'mobile settings expose daily reminders and independent navigation',
    (tester) async {
      try {
        await open(tester, size: const Size(320, 640), scale: 1.3);
        final context = tester.element(find.byType(MobileWorkspace));
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MobileSettings(
              store: MobilePreferenceStore(File('${root.path}/mobile.json')),
              preferences: const MobilePreferences(),
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final list = find
            .descendant(
              of: find.byType(MobileSettings),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Daily summary and due reminders'),
          250,
          scrollable: list,
        );
        expect(find.text('Daily summary and due reminders'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Support Todorbit'),
          250,
          scrollable: list,
        );
        await tester.ensureVisible(find.text('Support Todorbit'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.volunteer_activism_outlined), findsOneWidget);
        await tester.tap(find.text('Support Todorbit'));
        await tester.pumpAndSettle();
        expect(find.text('Enjoying Todorbit?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  for (final view in [
    WorkspaceView.habits,
    WorkspaceView.goals,
    WorkspaceView.reports,
    WorkspaceView.contributors,
  ]) {
    testWidgets('mobile ${view.name} stays usable on a small phone', (
      tester,
    ) async {
      try {
        await open(tester, size: const Size(320, 640), scale: 1.5);
        controller.navigate(view);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
      }
    });
  }
  for (final dialog in <Widget>[
    const ThemeDialog(),
    const TaskViewSettingsDialog(),
    const TemplatesDialog(),
    const AdvancedSearchDialog(),
  ]) {
    testWidgets(
      'mobile ${dialog.runtimeType} adapts to touch width and text scaling',
      (tester) async {
        try {
          await open(tester, size: const Size(320, 640), scale: 1.3);
          final context = tester.element(find.byType(MobileWorkspace));
          showDialog<void>(context: context, builder: (_) => dialog);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }
}
