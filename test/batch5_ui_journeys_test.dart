import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/appearance_preference_store.dart';
import 'package:life_manager/data/calendar_preference_store.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_resources.dart';
import 'package:life_manager/features/templates/templates_dialog.dart';
import 'package:life_manager/features/workspace/task_resources_section.dart';

void main() {
  test('repeated task recipes preserve fields and leave composition and resources with their source', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    try {
      final category = await repository.addCategory('Research');
      final source = await repository.addTaskWithComposition(
        TaskDraft(
          title: 'Read paper',
          notes: 'Annotate key claims',
          priority: 2,
          categoryId: category.id,
          scheduledDate: '2026-11-05',
          deadlineDate: '2026-11-07',
          plannedDurationMinutes: 45,
        ),
        ['Download supplementary material'],
        [const TaskDraft(title: 'Discuss results')],
      );
      await repository.addExternalResource(
        source.id,
        TaskResourceKind.url,
        'https://example.com/paper',
      );
      final template = await repository.saveTaskTemplate(
        source,
        'Reading setup',
      );
      final copies = <String>[];
      for (final anchor in ['2026-12-01', '2026-12-02']) {
        copies.add(
          await repository.instantiateTemplate(
            template,
            anchorDay: anchor,
            categoryId: category.id,
          ),
        );
      }
      final tasks = await repository.tasks();
      expect(tasks, hasLength(4));
      expect(copies.toSet(), hasLength(2));
      for (final id in copies) {
        final copy = tasks.singleWhere((t) => t.id == id);
        expect(copy.title, source.title);
        expect(copy.notes, source.notes);
        expect(copy.priority, 2);
        expect(copy.plannedDurationMinutes, 45);
        expect(copy.categoryId, category.id);
        expect(copy.status, TaskStatus.notStarted);
        expect(await repository.taskResources(id), isEmpty);
      }
      expect((await repository.taskParents()).values.toList(), [source.id]);
      expect((await repository.checklistItems()).single.taskId, source.id);
      expect(await repository.taskResources(source.id), hasLength(1));
      expect(
        tasks.singleWhere((t) => t.id == copies.first).deadlineDate,
        '2026-12-03',
      );
    } finally {
      await database.close();
    }
  });
  test(
    'duplicate template names explain the correction without creating rows',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      try {
        final task = await repository.addTask(
          const TaskDraft(title: 'Research'),
        );
        await repository.saveTaskTemplate(task, 'Research setup');
        await expectLater(
          repository.saveTaskTemplate(task, 'RESEARCH SETUP'),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('already exists'),
            ),
          ),
        );
        expect(await repository.templates(), hasLength(1));
        expect(await repository.tasks(), hasLength(1));
      } finally {
        await database.close();
      }
    },
  );

  test(
    'malformed calendar and invalid customization preserve original bytes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'todorbit-b5-invalid-settings-',
      );
      try {
        final appearance = File('${root.path}/appearance.json');
        const original = '{"customization":{"version":999},"unknown":"keep"}';
        await appearance.writeAsString(original);
        await expectLater(
          AppearancePreferenceStore(appearance).loadCustomization(),
          throwsFormatException,
        );
        expect(await appearance.readAsString(), original);
        final calendar = File('${root.path}/calendar.json');
        await calendar.writeAsString('{unfinished');
        final store = CalendarPreferenceStore(calendar);
        await expectLater(store.load(), throwsFormatException);
        await expectLater(
          store.save(CalendarContent.tasksOnly),
          throwsFormatException,
        );
        expect(await calendar.readAsString(), '{unfinished');
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets('invalid resource URL keeps input for correction', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final task = await repository.addTask(const TaskDraft(title: 'Read paper'));
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskResourcesSection(taskId: task.id, repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add a URL'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'not a URL');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Add URL'), findsOneWidget);
      expect(find.text('not a URL'), findsOneWidget);
      expect(await repository.taskResources(task.id), isEmpty);
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/paper',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        (await repository.taskResources(task.id)).single.target,
        'https://example.com/paper',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    }
  });

  testWidgets('template burst activation requests draft approval once', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final source = await repository.addTask(const TaskDraft(title: 'Write'));
    await repository.saveTaskTemplate(source, 'Weekly writing');
    final controller = AppController(repository);
    await controller.refresh();
    final approval = Completer<bool>();
    var requests = 0;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((ref) => controller)],
          child: MaterialApp(
            home: Scaffold(
              body: TemplatesDialog(
                beforeNavigate: () {
                  requests++;
                  return approval.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly writing'));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create from template'),
      );
      button.onPressed!();
      button.onPressed!();
      expect(requests, 1);
      approval.complete(false);
      await tester.pumpAndSettle();
      expect(await repository.tasks(), hasLength(1));
    } finally {
      if (!approval.isCompleted) approval.complete(false);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    }
  });

  test('startup preserves malformed preference bytes', () async {
    final root = await Directory.systemTemp.createTemp('todorbit-b5-prefs-');
    final file = File('${root.path}/appearance.json');
    const original = '{"theme":"dark","recoverable":"unfinished';
    await file.writeAsString(original);
    final database = AppDatabase(NativeDatabase.memory());
    final controller = AppController(
      LifeRepository(database),
      appearanceStore: AppearancePreferenceStore(file),
    );
    try {
      await expectLater(controller.initialize(), throwsFormatException);
      expect(await file.readAsString(), original);
    } finally {
      controller.dispose();
      await database.close();
      await root.delete(recursive: true);
    }
  });
}
