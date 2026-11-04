import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/calendar/session_editor.dart';
import 'package:life_manager/features/workspace/quick_search.dart';
import 'package:life_manager/main.dart';

import 'test_privacy.dart';

void main() {
  late AppDatabase database;
  late AppController controller;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(LifeRepository(database));
    await controller.refresh();
  });
  tearDown(() async => database.close());

  Future<void> open(WidgetTester tester, {double width = 1280}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          privacyOverride,
        ],
        child: const LifeManagerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'resource dialogs and picker cancellation preserve unsaved task edits',
    (tester) async {
      final source = await controller.repository.addTask(
        const TaskDraft(title: 'Resource source'),
      );
      await controller.refresh();
      controller.navigate(WorkspaceView.all);
      const picker = MethodChannel('life_manager/file_dialog');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        picker,
        (_) async => null,
      );
      try {
        await open(tester);
        await tester.tap(find.text('Resource source'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('task-title-field')),
          'Unsaved resource draft',
        );
        await tester.ensureVisible(find.byTooltip('Add a URL'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add a URL'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Attach a copy of a file'));
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsNothing);
        expect(find.text('Unsaved resource draft'), findsOneWidget);
        expect(
          (await controller.repository.tasks()).single.title,
          'Resource source',
        );
        expect(await controller.repository.taskResources(source.id), isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          picker,
          null,
        );
      }
    },
  );

  for (final target in ['close', 'Calendar', 'New task']) {
    testWidgets('desktop draft survives $target until explicit discard', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Keep this draft',
      );
      if (target == 'close') {
        await tester.tap(find.byTooltip('Close details'));
      } else if (target == 'Calendar') {
        await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
      } else {
        await tester.tap(find.widgetWithText(FilledButton, 'New task'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(await controller.repository.tasks(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'switching desktop tasks preserves draft when discard is declined',
    (tester) async {
      final first = await controller.repository.addTask(
        TaskDraft(title: 'First saved task'),
      );
      await controller.repository.addTask(
        TaskDraft(title: 'Second saved task'),
      );
      await controller.refresh();
      controller.navigate(WorkspaceView.all);
      await open(tester);
      await tester.tap(find.text('First saved task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Unsaved first task',
      );
      await tester.tap(find.text('Second saved task'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved first task'), findsOneWidget);
      expect(controller.selectedTaskId, first.id);
      expect(
        (await controller.repository.tasks())
            .firstWhere((t) => t.id == first.id)
            .title,
        'First saved task',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('compact desktop Escape protects task draft', (tester) async {
    await open(tester, width: 900);
    await tester.tap(find.widgetWithText(FilledButton, 'New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Compact draft',
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsOneWidget);
    expect(find.text('Compact draft'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'accepted discard opens a fresh task without saving the old draft',
    (tester) async {
      await open(tester);
      final create = find.widgetWithText(FilledButton, 'New task');
      await tester.tap(create);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Discard me',
      );
      await tester.tap(create);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Discard me'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('task-title-field')))
            .controller!
            .text,
        isEmpty,
      );
      expect(await controller.repository.tasks(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'desktop resize retains the active draft and saves it after widening',
    (tester) async {
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Resize-safe draft',
      );
      await tester.pumpAndSettle();
      final editorState = tester.state(find.byType(TaskEditor));
      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TaskEditor)), same(editorState));
      expect(find.text('Resize-safe draft'), findsOneWidget);
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TaskEditor)), same(editorState));
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      expect(
        (await controller.repository.tasks()).single.title,
        'Resize-safe draft',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'search opens without discarding a draft and guards result navigation',
    (tester) async {
      await controller.repository.addTask(TaskDraft(title: 'Search target'));
      await controller.refresh();
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Search-safe draft',
      );
      await tester.tap(find.byIcon(Icons.search_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byType(QuickSearchDialog),
          matching: find.byType(TextField),
        ),
        'Search target',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Search target'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.text('Search-safe draft'), findsOneWidget);
      expect(controller.selectedTaskId, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('creating a saved view guards the desktop draft before saving', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Saved-view-safe draft',
    );
    final createView = find.byTooltip('Create saved view');
    await tester.scrollUntilVisible(
      createView,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(createView);
    await tester.pumpAndSettle();
    await tester.tap(createView);
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, 'View name *'),
      'Audit view',
    );
    await tester.tap(find.text('Create view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(controller.savedViews, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Saved-view-safe draft'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'template inspection preserves draft and creation awaits discard',
    (tester) async {
      final source = await controller.repository.addTask(
        TaskDraft(title: 'Recipe source'),
      );
      await controller.saveTaskTemplate(source, 'Audit recipe');
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Template-safe draft',
      );
      final templates = find.byTooltip('Templates');
      await tester.ensureVisible(templates);
      await tester.tap(templates);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Audit recipe'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsNothing);
      await tester.tap(find.text('Create from template'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect((await controller.repository.tasks()), hasLength(1));
      await tester.tap(find.text('Create from template'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect((await controller.repository.tasks()), hasLength(2));
      expect(find.text('Template-safe draft'), findsNothing);
      expect(find.byKey(const ValueKey('task-title-field')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('category deletion cannot dispose a draft without approval', (
    tester,
  ) async {
    await controller.addCategory('Audit category');
    await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Category-safe draft',
    );
    final categoryActions = find.byTooltip('Category actions');
    await tester.scrollUntilVisible(
      categoryActions,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(categoryActions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(controller.categories.single.name, 'Audit category');
    expect(find.text('Category-safe draft'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final entry in ['Event', 'Work session']) {
    testWidgets('desktop Calendar $entry protects unsaved input on close', (
      tester,
    ) async {
      await controller.repository.addTask(TaskDraft(title: 'Session task'));
      await controller.refresh();
      controller.navigate(WorkspaceView.calendar);
      await open(tester);
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
      if (entry == 'Event') {
        await tester.enterText(
          find.widgetWithText(TextField, 'Title *'),
          'Uncommitted event',
        );
      } else {
        await tester.tap(
          find.descendant(
            of: find.byType(SessionEditor),
            matching: find.text('Upcoming'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MenuItemButton, 'Completed'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        find.byType(entry == 'Event' ? EventEditor : SessionEditor),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
