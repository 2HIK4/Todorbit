import 'test_privacy.dart';
import 'support/editor_disclosure.dart';

import 'package:life_manager/features/workspace/workspace.dart';
import 'package:life_manager/domain/recurrence.dart';

import 'dart:async';
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
import 'package:life_manager/domain/saved_views.dart';
import 'package:life_manager/features/shared/app_motion.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/item_filters.dart';
import 'package:life_manager/features/settings/sidebar_order_dialog.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

void main() {
  late AppDatabase database;
  late AppController controller;
  late Directory root;
  late File original;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-refinement-ui-');
    original = File('${root.path}/reference.txt');
    await original.writeAsString('Synthetic source stays intact');
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(database));
    await controller.refresh();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/file_dialog'),
          (call) async => call.method == 'openFile' ? original.path : null,
        );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('life_manager/file_dialog'),
          null,
        );
    await database.close();
    await root.delete(recursive: true);
  });
  Future<void> open(
    WidgetTester tester,
    Widget child, {
    double width = 390,
    double scale = 1,
    bool dark = false,
    bool reduced = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          privacyOverride,
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            dark ? Brightness.dark : Brightness.light,
            dark ? ThemePalette.dark : ThemePalette.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: AppMotionTheme(child: child!),
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(title).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'resource can be selected before creation and discard leaves no records or changed original',
    (tester) async {
      var cancelled = false;
      await open(
        tester,
        TaskEditor(protectUnsavedEdits: true, onCancel: () => cancelled = true),
        scale: 1.4,
        dark: true,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Title *'),
        'Unsaved task',
      );
      expect(find.byKey(const ValueKey('task-notes-field')), findsNothing);
      await reveal(tester, 'Resources');
      await tester.ensureVisible(find.text('Attach a copy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attach a copy'));
      await tester.pumpAndSettle();
      expect(find.text('reference.txt'), findsOneWidget);
      expect(await controller.repository.tasks(), isEmpty);
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(await controller.repository.tasks(), isEmpty);
      expect(original.readAsStringSync(), 'Synthetic source stays intact');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('save persists a draft attachment with its task exactly once', (
    tester,
  ) async {
    final saved = Completer<void>();
    await open(
      tester,
      TaskEditor(onSaved: () => saved.complete()),
      width: 1100,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Title *'),
      'Task with attachment',
    );
    await reveal(tester, 'Resources');
    await tester.ensureVisible(find.text('Attach a copy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach a copy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task'));
    final watch = Stopwatch()..start();
    while (!saved.isCompleted && watch.elapsed < const Duration(seconds: 10)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(
      saved.isCompleted,
      isTrue,
      reason: 'Task save must complete while frames and file IO are allowed to progress',
    );
    await tester.pumpAndSettle();
    final task = (await controller.repository.tasks()).single;
    final resource = (await controller.repository.taskResources(task.id))
        .single;
    expect(
      await controller.repository.managedAttachmentBytes(resource),
      original.readAsBytesSync(),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('filters combine, show active chips and clear independently', (
    tester,
  ) async {
    final category = await controller.repository.addCategory('University');
    await controller.repository.addTask(
      TaskDraft(title: 'Course work', categoryId: category.id, priority: 3),
    );
    await controller.repository.addTask(
      const TaskDraft(title: 'Personal task'),
    );
    await controller.refresh();
    controller.navigate(WorkspaceView.all);
    await open(tester, const ItemFilters());
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('University').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(controller.visibleTasks.map((t) => t.title), ['Course work']);
    expect(find.text('Filters active'), findsOneWidget);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(controller.visibleTasks, hasLength(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('optional navigation can be hidden and restored at large text', (
    tester,
  ) async {
    await controller.addSavedView('University tasks', const TaskFilter());
    await open(tester, const SidebarOrderDialog(), width: 390, scale: 1.6);
    final checkbox = find.descendant(
      of: find.ancestor(
        of: find.text('Today'),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(controller.hiddenNavigation, contains('today'));
    await tester.ensureVisible(find.text('Reset to default'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    expect(controller.hiddenNavigation, isEmpty);
    expect(controller.savedViews.single.name, 'University tasks');
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets(
      'disclosure follows animation preference $reduced and remains operable',
      (tester) async {
        await open(
          tester,
          const ExpansionTile(
            title: Text('Advanced'),
            children: [Text('Details')],
          ),
          reduced: reduced,
          dark: true,
        );
        final context = tester.element(find.byType(ExpansionTile));
        expect(
          Theme.of(context)
              .expansionTileTheme
              .expansionAnimationStyle!
              .duration,
          reduced ? Duration.zero : AppMotion.duration,
        );
        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();
        expect(find.text('Details'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'All Tasks expands stable recurrence identities and filtered children stay independent',
    (tester) async {
      final repo = controller.repository;
      final day = localDate(DateTime.now());
      final recurring = await repo.addRecurringTask(
        TaskDraft(title: 'Shared title', scheduledDate: day),
        RecurrenceRule(
          kind: RecurrenceKind.daily,
          startDate: day,
          maxOccurrences: 3,
        ),
      );
      await repo.setComplete(recurring, true);
      await repo.addTask(const TaskDraft(title: 'Shared title'));
      final parent = await repo.addTask(
        const TaskDraft(title: 'Parent container'),
      );
      await repo.addSubtask(
        parent,
        const TaskDraft(title: 'Child independently searchable'),
      );
      await controller.refresh();
      controller.navigate(WorkspaceView.all);
      final family =
          controller.tasks
              .firstWhere((t) => t.id == recurring.id)
              .recurrenceFamilyId ??
          recurring.recurrenceSeriesId;
      await open(tester, const Workspace(), width: 1280);
      final group = find.byKey(PageStorageKey('series:$family'));
      expect(group, findsOneWidget);
      expect(find.text('Shared title'), findsNWidgets(2));
      await tester.tap(
        find
            .descendant(of: group, matching: find.byIcon(Icons.expand_more))
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Shared title'), findsNWidgets(5));
      expect(find.text('Child independently searchable'), findsNothing);
      controller.setFilter(const TaskFilter(text: 'Child independently'));
      await tester.pumpAndSettle();
      expect(find.text('Child independently searchable'), findsOneWidget);
      expect(find.text('Parent container'), findsNothing);
      expect(
        (await repo.tasks()).firstWhere((t) => t.id == recurring.id).status,
        TaskStatus.completed,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'draft checklist can be named, edited and reordered before one task commit',
    (tester) async {
      var saved = false;
      await open(tester, TaskEditor(onSaved: () => saved = true));
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Packing task',
      );
      await expandEditorSection(tester, 'Checklist and subtasks');
      await tester.tap(find.text('Add checklist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Pack');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      for (final item in ['Book', 'Pen']) {
        await tester.ensureVisible(find.text('Add item'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add item'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), item);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byTooltip('Draft checklist item actions').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Draft checklist item actions').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      expect(await controller.repository.checklistGroups(), isEmpty);
      await tester.tap(find.text('Create task'));
      for (var i = 0; i < 80 && !saved; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(saved, isTrue);
      expect(
        (await controller.repository.tasks()).single.title,
        'Packing task',
      );
      expect(
        (await controller.repository.checklistGroups()).single.title,
        'Pack',
      );
      expect(
        (await controller.repository.checklistItems()).map((i) => i.title),
        ['Pen', 'Book'],
      );
      expect(tester.takeException(), isNull);
    },
  );
}
