import 'support/editor_disclosure.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/workspace/task_editor.dart';
import 'package:life_manager/features/workspace/series_editor.dart';

class _DelayedPrerequisiteController extends AppController {
  _DelayedPrerequisiteController(super.repository);

  final persisted = Completer<void>();
  final finishSave = Completer<void>();

  @override
  Future<void> setPrerequisites(LifeTask task, Set<String> ids) async {
    await super.setPrerequisites(task, ids);
    persisted.complete();
    await finishSave.future;
  }
}

void main() {
  late AppDatabase database;
  late LifeRepository repository;
  late AppController controller;
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
    controller = AppController(repository);
    await controller.refresh();
  });
  tearDown(() async => database.close());

  Future<void> open(
    WidgetTester tester, {
    LifeTask? task,
    Size size = const Size(1000, 850),
    double scale = 1,
    VoidCallback? onSaved,
    VoidCallback? onCancel,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fontFile = File('C:/Windows/Fonts/segoeui.ttf');
    if (fontFile.existsSync()) {
      final font = FontLoader('Roboto');
      font.addFont(
        Future.value(ByteData.sublistView(fontFile.readAsBytesSync())),
      );
      await font.load();
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: RepaintBoundary(
          key: const ValueKey('advanced-capture'),
          child: MaterialApp(
            theme: buildAppTheme(Brightness.dark, ThemePalette.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 520,
                  child: TaskEditor(
                    task: task,
                    protectUnsavedEdits: true,
                    onSaved: onSaved,
                    onCancel: onCancel,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find
          .descendant(
            of: find.byType(TaskEditor).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final output = Platform.environment['AUDIT_CAPTURE_DIR'];
    if (output == null) return;
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('advanced-capture')),
          )
          .toImage();
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> preview(WidgetTester tester) async {
    final generate = find.widgetWithText(OutlinedButton, 'Generate preview');
    await tester.tap(generate);
    await tester.pump();
    for (
      var i = 0;
      i < 50 && tester.widget<OutlinedButton>(generate).onPressed == null;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(generate).onPressed,
      isNotNull,
      reason: 'Preview must finish before approval is tested.',
    );
  }

  testWidgets('prerequisite edits made during a save remain unsaved', (
    tester,
  ) async {
    final delayed = _DelayedPrerequisiteController(repository);
    controller = delayed;
    final task = await repository.addTask(
      const TaskDraft(title: 'Submit review'),
    );
    final prerequisite = await repository.addTask(
      const TaskDraft(title: 'Read sources'),
    );
    await controller.refresh();
    var closed = false;
    await open(tester, task: task, onCancel: () => closed = true);
    await reveal(tester, find.text('Prerequisites'));
    await tester.tap(find.text('Prerequisites'));
    await tester.pumpAndSettle();
    final candidate = find.widgetWithText(CheckboxListTile, 'Read sources');
    await reveal(tester, candidate);
    await tester.tap(candidate);
    await reveal(tester, find.text('Save prerequisites'));
    await tester.tap(find.text('Save prerequisites'));
    await tester.runAsync(() => delayed.persisted.future);
    await tester.pump();
    await reveal(tester, candidate);
    await tester.tap(candidate);
    delayed.finishSave.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close details'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(closed, isFalse);
    expect(
      (await repository.dependencies()).single.prerequisiteId,
      prerequisite.id,
    );
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(candidate).value, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'nested draft subtask keeps entered work after Escape is declined',
    (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Parent with a long description and multiple planned steps',
      );
      await expandEditorSection(tester, 'Checklist and subtasks');
      await reveal(tester, find.text('Add subtask'));
      await tester.tap(find.text('Add subtask'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('draft-subtask-title')),
        'Research sources and retain this nested draft',
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        find.text('Research sources and retain this nested draft'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      final tasks = await repository.tasks();
      expect(tasks, hasLength(2));
      final parents = await repository.taskParents();
      expect(
        tasks.singleWhere((t) => parents.containsKey(t.id)).title,
        'Research sources and retain this nested draft',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'nested subtask validation and actions fit a short enlarged window',
    (tester) async {
      await open(tester, size: const Size(390, 480), scale: 2);
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Parent draft',
      );
      await expandEditorSection(tester, 'Checklist and subtasks');
      await reveal(tester, find.text('Add subtask'));
      await tester.tap(find.text('Add subtask'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a subtask title.'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Save').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'nested-subtask-validation');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('applying a series edit protects the dirty occurrence editor', (
    tester,
  ) async {
    final task = await repository.addRecurringTask(
      const TaskDraft(
        title: 'Original recurring review',
        scheduledDate: '2026-11-04',
      ),
      RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-11-04',
        maxOccurrences: 3,
      ),
    );
    await repository.ensureRecurringTasks('2026-11-04', '2026-11-06');
    await controller.refresh();
    var closed = false;
    await open(tester, task: task, onSaved: () => closed = true);
    await expandEditorSection(tester, 'Notes');
    await tester.enterText(
      find.widgetWithText(TextField, 'Notes'),
      'Occurrence-only notes that are not saved yet',
    );
    await reveal(tester, find.text('Edit recurring series'));
    await tester.tap(find.text('Edit recurring series'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, 'Shared title'),
      'Updated series title',
    );
    await preview(tester);
    final keepBoth = find.text('Keep both on all');
    await tester.scrollUntilVisible(
      keepBoth,
      180,
      scrollable: find
          .descendant(
            of: find.byType(SeriesEditorDialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(keepBoth);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply series edit'),
          )
          .onPressed,
      isNotNull,
      reason: 'All date collisions were explicitly reviewed.',
    );
    await tester.tap(find.text('Apply series edit'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(
      (await repository.tasks()).every(
        (t) => t.title == 'Original recurring review',
      ),
      isTrue,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(
      find.text('Occurrence-only notes that are not saved yet'),
      findsOneWidget,
    );
    await reveal(tester, find.text('Edit recurring series'));
    await tester.tap(find.text('Edit recurring series'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Shared title'),
      'Approved series title',
    );
    await preview(tester);
    await tester.scrollUntilVisible(
      keepBoth,
      180,
      scrollable: find
          .descendant(
            of: find.byType(SeriesEditorDialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(keepBoth);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply series edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(find.byType(SeriesEditorDialog), findsNothing);
    expect(
      (await repository.tasks()).any((t) => t.title == 'Approved series title'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('series draft survives Escape in a compact enlarged editor', (
    tester,
  ) async {
    final task = await repository.addRecurringTask(
      const TaskDraft(title: 'Daily review', scheduledDate: '2026-11-04'),
      RecurrenceRule(
        kind: RecurrenceKind.daily,
        startDate: '2026-11-04',
        maxOccurrences: 3,
      ),
    );
    await controller.refresh();
    await open(tester, task: task, size: const Size(390, 700), scale: 2);
    await reveal(tester, find.text('Edit recurring series'));
    await tester.tap(find.text('Edit recurring series'));
    await tester.pumpAndSettle();
    final sharedTitle = find.widgetWithText(TextField, 'Shared title');
    await tester.scrollUntilVisible(
      sharedTitle,
      140,
      scrollable: find
          .descendant(
            of: find.byType(SeriesEditorDialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(sharedTitle, 'Retain the shared series draft');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(sharedTitle).controller!.text,
      'Retain the shared series draft',
    );
    expect(find.text('Generate preview').hitTestable(), findsOneWidget);
    expect(find.text('Apply series edit').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'series-draft-large');
    await tester.pumpWidget(const SizedBox());
  });

  for (final keepNotes in [false, true]) {
    testWidgets(
      'saving prerequisites clears only its own dirty state (notes=$keepNotes)',
      (tester) async {
        final task = await repository.addTask(
          const TaskDraft(title: 'Prepare final submission'),
        );
        final prerequisite = await repository.addTask(
          const TaskDraft(title: 'Review source material'),
        );
        await controller.refresh();
        var closed = false;
        await open(tester, task: task, onCancel: () => closed = true);
        if (keepNotes) {
          await expandEditorSection(tester, 'Notes');
          await tester.enterText(
            find.widgetWithText(TextField, 'Notes'),
            'Retain unrelated notes',
          );
        }
        await reveal(tester, find.text('Prerequisites'));
        await tester.tap(find.text('Prerequisites'));
        await tester.pumpAndSettle();
        final candidate = find.widgetWithText(
          CheckboxListTile,
          'Review source material',
        );
        await reveal(tester, candidate);
        await tester.tap(candidate);
        await reveal(tester, find.text('Save prerequisites'));
        await tester.tap(find.text('Save prerequisites'));
        await tester.pumpAndSettle();
        expect(
          (await repository.dependencies()).single.prerequisiteId,
          prerequisite.id,
        );
        await tester.tap(find.byTooltip('Close details'));
        await tester.pumpAndSettle();
        expect(
          find.text('Discard unsaved changes?'),
          keepNotes ? findsOneWidget : findsNothing,
        );
        expect(closed, !keepNotes);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'stale task save retains long draft and the newer stored record',
    (tester) async {
      final task = await repository.addTask(
        const TaskDraft(title: 'Original record'),
      );
      await controller.refresh();
      var closed = false;
      await open(tester, task: task, onSaved: () => closed = true);
      final longTitle = List.filled(8, 'Retained draft').join(' ');
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        longTitle,
      );
      await expandEditorSection(tester, 'Notes');
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes'),
        List.filled(20, 'Detailed notes.').join('\n'),
      );
      await repository.updateTask(
        task,
        const TaskDraft(title: 'Newer concurrent edit'),
      );
      await controller.refresh();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save task:'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('task-title-field')))
            .controller!
            .text,
        longTitle,
      );
      expect((await repository.tasks()).single.title, 'Newer concurrent edit');
      expect(closed, isFalse);
      await capture(tester, 'stale-task-save');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
