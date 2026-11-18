import 'dart:io';

import 'support/editor_disclosure.dart';

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
import 'package:life_manager/features/workspace/quick_search.dart';
import 'package:life_manager/features/search/advanced_search_dialog.dart';
import 'package:life_manager/features/time_tracking/compact_task_timer.dart';
import 'package:life_manager/features/time_tracking/focus_workspace.dart';
import 'package:life_manager/features/calendar/event_editor.dart';
import 'package:life_manager/features/calendar/session_editor.dart';
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

  for (final advanced in [false, true]) {
    testWidgets(
      'dirty task survives ${advanced ? 'Advanced Search' : 'sidebar search'} cancellation',
      (tester) async {
        final first = await controller.repository.addTask(
          const TaskDraft(title: 'First task'),
        );
        final second = await controller.repository.addTask(
          const TaskDraft(title: 'Other destination'),
        );
        await controller.refresh();
        controller.navigate(WorkspaceView.anytime);
        await open(tester);
        await tester.tap(find.text(first.title));
        await tester.pumpAndSettle();
        final title = find.byKey(const ValueKey('task-title-field'));
        await tester.enterText(title, 'Unsaved task draft');
        await tester.pump();

        if (advanced) {
          await tester.tap(find.byTooltip('Advanced search & filters'));
          await tester.pumpAndSettle();
          final search = find.descendant(
            of: find.byType(AdvancedSearchDialog),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.labelText ==
                      'Words in title, notes, category, or project',
            ),
          );
          await tester.enterText(search, second.title);
          await tester.pumpAndSettle();
          final preview = find.text('Preview Matching Tasks (1)');
          await tester.ensureVisible(preview);
          await tester.pumpAndSettle();
          await tester.tap(preview);
          await tester.pumpAndSettle();
          final result = find.descendant(
            of: find.byType(AdvancedSearchDialog),
            matching: find.widgetWithText(ListTile, second.title),
          );
          await tester.ensureVisible(result);
          await tester.pumpAndSettle();
          await tester.tap(result);
        } else {
          await tester.enterText(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  (widget.decoration?.hintText?.startsWith('Search') ?? false),
            ),
            second.title,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, second.title));
        }
        await tester.pumpAndSettle();
        final prompt = find.text('Discard unsaved changes?');
        expect(prompt, findsOneWidget);
        expect(controller.view, WorkspaceView.anytime);
        expect(controller.selectedTaskId, first.id);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(prompt, findsNothing);
        expect(
          find.byType(AdvancedSearchDialog),
          advanced ? findsOneWidget : findsNothing,
        );
        expect(
          tester.widget<TextField>(title).controller!.text,
          'Unsaved task draft',
        );
        expect(controller.view, WorkspaceView.anytime);
        expect(controller.selectedTaskId, first.id);
        expect(
          (await controller.repository.tasks()).map((task) => task.title),
          unorderedEquals([first.title, second.title]),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Save commits a task draft before the sidebar changes route', (
    tester,
  ) async {
    final task = await controller.repository.addTask(
      const TaskDraft(title: 'Original task'),
    );
    await controller.refresh();
    controller.navigate(WorkspaceView.anytime);
    await open(tester);
    await tester.tap(find.text('Original task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Saved task draft',
    );
    await tester.tap(find.widgetWithText(ListTile, 'Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(controller.view, WorkspaceView.anytime);
    expect(controller.selectedTaskId, task.id);
    expect((await controller.repository.tasks()).single.title, 'Original task');

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsNothing);
    expect(find.byType(TaskEditor), findsNothing);
    expect(controller.view, WorkspaceView.calendar);
    expect(controller.selectedTaskId, isNull);
    final saved = (await controller.repository.tasks()).single;
    expect(saved.id, task.id);
    expect(saved.title, 'Saved task draft');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final presentation in ['sidePanel', 'fullPage']) {
    for (final request in ['save', 'save failure', 'timer', 'rapid routes']) {
      testWidgets('dirty event handles $request in $presentation', (
        tester,
      ) async {
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day, 11);
        await controller.repository.addEvent(
          EventDraft(
            title: 'Original event',
            startsAt: start,
            endsAt: start.add(const Duration(hours: 1)),
          ),
        );
        await controller.setTaskViewPreferences(
          controller.taskViewPreferences.copyWith(
            detailPresentation: presentation,
          ),
        );
        if (request == 'timer') {
          final timerTask = await controller.repository.addTask(
            const TaskDraft(title: 'Timer owner'),
          );
          await controller.startTimer(timerTask.id);
        }
        await controller.refresh();
        controller.navigate(WorkspaceView.calendar);
        await open(tester);
        final event = find.text('Original event').first;
        await tester.ensureVisible(event);
        await tester.pumpAndSettle();
        await tester.tap(event);
        await tester.pumpAndSettle();
        final editor = find.byType(EventEditor);
        final eventId = tester.widget<EventEditor>(editor).event!.id;
        final title = find
            .descendant(of: editor, matching: find.byType(TextField))
            .first;
        if (request == 'save failure') {
          await database.customStatement(
            "CREATE TRIGGER reject_test_event_save BEFORE UPDATE ON fixed_events "
            "BEGIN SELECT RAISE(ABORT, 'Synthetic save failure'); END",
          );
        }
        const draft = 'Unsaved event draft';
        await tester.enterText(title, draft);
        if (request != 'rapid routes') await tester.pumpAndSettle();

        final today = find.widgetWithText(ListTile, 'Today');
        if (request == 'timer') {
          final timer = find.descendant(
            of: find.byType(CompactTaskTimer),
            matching: find.byType(ListTile),
          );
          await tester.tap(timer);
        } else {
          await tester.tap(today);
          if (request == 'rapid routes') {
            await tester.tap(
              find.widgetWithText(ListTile, 'Calendar'),
              warnIfMissed: false,
            );
          }
        }
        await tester.pumpAndSettle();
        final prompt = find.text('Discard unsaved changes?');
        expect(prompt, findsOneWidget);
        expect(controller.view, WorkspaceView.calendar);
        expect(tester.widget<EventEditor>(editor).event!.id, eventId);
        expect(
          (await controller.repository.events()).single.title,
          'Original event',
        );

        final choice = switch (request) {
          'timer' => 'Keep editing',
          'rapid routes' => 'Discard changes',
          _ => 'Save',
        };
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(choice),
          ),
        );
        await tester.pumpAndSettle();
        expect(prompt, findsNothing);
        expect(find.byType(FocusWorkspace), findsNothing);
        final persisted = (await controller.repository.events()).single;
        expect(persisted.id, eventId);
        if (request == 'save failure') {
          expect(find.textContaining('Could not save event:'), findsOneWidget);
        }
        if (request == 'timer' || request == 'save failure') {
          expect(controller.view, WorkspaceView.calendar);
          expect(tester.widget<EventEditor>(editor).event!.id, eventId);
          expect(tester.widget<TextField>(title).controller!.text, draft);
          expect(persisted.title, 'Original event');
        } else {
          expect(controller.view, WorkspaceView.today);
          expect(editor, findsNothing);
          expect(persisted.title, request == 'save' ? draft : 'Original event');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'full page event selection changes only after discarding the draft',
    (tester) async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day, 11);
      final first = await controller.repository.addEvent(
        EventDraft(
          title: 'First meeting',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 1)),
        ),
      );
      final second = await controller.repository.addEvent(
        EventDraft(
          title: 'Second meeting',
          startsAt: start.add(const Duration(hours: 2)),
          endsAt: start.add(const Duration(hours: 3)),
        ),
      );
      await controller.setTaskViewPreferences(
        controller.taskViewPreferences.copyWith(detailPresentation: 'fullPage'),
      );
      await controller.refresh();
      controller.navigate(WorkspaceView.calendar);
      await open(tester);
      final event = find.text(first.title).first;
      await tester.ensureVisible(event);
      await tester.pumpAndSettle();
      await tester.tap(event);
      await tester.pumpAndSettle();
      final editor = find.byType(EventEditor);
      final title = find
          .descendant(of: editor, matching: find.byType(TextField))
          .first;
      await tester.enterText(title, 'Unsaved first meeting');

      await tester.tap(find.byTooltip('Quick Search (Ctrl+K)'));
      await tester.pumpAndSettle();
      final search = find.byType(QuickSearchDialog);
      await tester.enterText(
        find.descendant(of: search, matching: find.byType(TextField)),
        'Second meeting',
      );
      await tester.pumpAndSettle();
      final result = find.descendant(
        of: search,
        matching: find.widgetWithText(ListTile, second.title),
      );
      final prompt = find.text('Discard unsaved changes?');
      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(prompt, findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(prompt, findsNothing);
      expect(tester.widget<EventEditor>(editor).event!.id, first.id);
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Unsaved first meeting',
      );

      await tester.tap(result);
      await tester.pumpAndSettle();
      expect(prompt, findsOneWidget);
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(prompt, findsNothing);
      expect(search, findsNothing);
      expect(controller.view, WorkspaceView.calendar);
      expect(tester.widget<EventEditor>(editor).event!.id, second.id);
      expect(tester.widget<TextField>(title).controller!.text, second.title);
      expect(
        (await controller.repository.events()).map((event) => event.title),
        [first.title, second.title],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'resource dialogs and picker cancellation preserve unsaved task edits',
    (tester) async {
      final source = await controller.repository.addTask(
        const TaskDraft(title: 'Resource source'),
      );
      await controller.setTaskViewPreferences(
        controller.taskViewPreferences.copyWith(detailPresentation: 'fullPage'),
      );
      await controller.refresh();
      controller.navigate(WorkspaceView.all);
      const picker = MethodChannel('life_manager/file_dialog');
      final pickerCalls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(picker, (
        call,
      ) async {
        pickerCalls.add(call.method);
        return null;
      });
      try {
        await open(tester);
        await tester.tap(find.text('Resource source'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Edit task'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('task-title-field')),
          'Unsaved resource draft',
        );
        await expandEditorSection(tester, 'Resources');
        final addUrl = find.descendant(
          of: find.byType(TaskEditor),
          matching: find.text('Add URL'),
        );
        await tester.ensureVisible(addUrl);
        await tester.pumpAndSettle();
        await tester.tap(addUrl);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        final attach = find.descendant(
          of: find.byType(TaskEditor),
          matching: find.text('Attach copy'),
        );
        await tester.ensureVisible(attach);
        await tester.pumpAndSettle();
        await tester.tap(attach);
        await tester.pumpAndSettle();
        if (Platform.isWindows) expect(pickerCalls, ['openFile']);
        expect(find.text('Discard unsaved changes?'), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('task-title-field')),
          -180,
          scrollable: find
              .descendant(
                of: find.byType(TaskEditor),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
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
    'saved-task editing guards close and permits switching only after discard',
    (tester) async {
      final first = await controller.repository.addTask(
        TaskDraft(title: 'First saved task'),
      );
      await controller.repository.addTask(
        TaskDraft(title: 'Second saved task'),
      );
      await controller.setTaskViewPreferences(
        controller.taskViewPreferences.copyWith(detailPresentation: 'fullPage'),
      );
      await controller.refresh();
      controller.navigate(WorkspaceView.all);
      await open(tester);
      await tester.tap(find.text('First saved task'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Unsaved first task',
      );
      await tester.tap(find.byTooltip('Close details'));
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
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second saved task'));
      await tester.pumpAndSettle();
      expect(controller.selectedTask?.title, 'Second saved task');
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
      await tester.tap(find.byTooltip('Quick Search (Ctrl+K)'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsNothing);
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  'Search tasks, events, categories, and projects',
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
    final createView = find.byTooltip('Add Custom View');
    await tester.scrollUntilVisible(
      createView,
      160,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
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
    await tester.tap(find.widgetWithText(FilledButton, 'Create Custom View'));
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
      await tester.tap(find.byTooltip('Library'));
      await tester.pumpAndSettle();
      final templates = find.text('Templates');
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
    await tester.scrollUntilVisible(
      find.text('Categories (1)'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories (1)'));
    await tester.pumpAndSettle();
    final categoryActions = find.byTooltip('Category actions');
    await tester.scrollUntilVisible(
      categoryActions,
      160,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
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
