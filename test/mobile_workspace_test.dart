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
          expect(find.text('Make room for what matters'), findsOneWidget);
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
