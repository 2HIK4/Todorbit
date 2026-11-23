import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/panel_resize_handle.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/workspace/workspace.dart';

void main() {
  late AppDatabase database;
  late AppController controller;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(database));
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 10);
    await controller.repository.addEvent(
      EventDraft(
        title: 'Calendar commitment',
        startsAt: start,
        endsAt: start.add(const Duration(minutes: 40)),
      ),
    );
    await controller.repository.addTask(
      TaskDraft(
        title: 'Prepare the weekly review',
        scheduledDate: localDate(now),
        deadlineDate: localDate(DateTime(now.year, now.month, now.day + 2)),
      ),
    );
    await controller.refresh();
  });

  tearDown(() => database.close());

  Future<void> open(WidgetTester tester, Brightness brightness) async {
    const activation = MethodChannel('life_manager/activation');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(activation, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(activation, null));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          theme: buildAppTheme(
            brightness,
            brightness == Brightness.light
                ? ThemePalette.light
                : ThemePalette.dark,
          ),
          home: const Workspace(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Today opens fixed events and keeps the task list distinct', (
    tester,
  ) async {
    await open(tester, Brightness.light);
    expect(find.text('On your calendar'), findsOneWidget);
    expect(find.text('Planned tasks'), findsOneWidget);
    expect(find.text('Prepare the weekly review'), findsOneWidget);
    await tester.tap(find.text('Calendar commitment'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EventEditor>(find.byType(EventEditor)).event?.title,
      'Calendar commitment',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resize keeps the edit draft when the workspace becomes narrow', (
    tester,
  ) async {
    await open(tester, Brightness.dark);
    await tester.tap(find.text('Prepare the weekly review'));
    await tester.pumpAndSettle();
    final editor = find.byType(TaskEditor);
    final title = find.byKey(const ValueKey('task-title-field'));
    final handle = find.byType(PanelResizeHandle);
    expect(handle, findsOneWidget);
    await tester.enterText(title, 'Unsaved weekly review');
    final before = tester.getSize(editor).width;
    await tester.drag(handle, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(editor).width, greaterThan(before));
    expect(controller.taskPanelWidth, greaterThan(before));

    tester.view.physicalSize = const Size(800, 660);
    await tester.pumpAndSettle();
    expect(handle, findsNothing);
    expect(
      tester.widget<TextField>(title).controller?.text,
      'Unsaved weekly review',
    );
    expect(find.text('Save changes').hitTestable(), findsOneWidget);

    await tester.tap(find.byTooltip('Close details'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(controller.tasks.single.title, 'Prepare the weekly review');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !Platform.isWindows);
}
