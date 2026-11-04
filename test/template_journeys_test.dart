import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/features/templates/templates_dialog.dart';

void main() {
  testWidgets(
    'unsupported and stale templates leave records unchanged with actionable feedback',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final source = await repository.addTask(
        const TaskDraft(title: 'Research'),
      );
      final recipe = await repository.saveTaskTemplate(
        source,
        'Current recipe',
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await database.customStatement(
        'INSERT INTO templates VALUES(?,?,?,?,?,?)',
        ['future', 'Future recipe', 'task', '{"version":999}', now, now],
      );
      final controller = AppController(repository);
      await controller.refresh();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(home: Scaffold(body: TemplatesDialog())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Future recipe'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('unsupported or incomplete format'),
          findsOneWidget,
        );
        await repository.deleteTemplate(recipe);
        await tester.tap(find.text('Current recipe'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create from template'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Template changed. Refresh first.'),
          findsOneWidget,
        );
        expect(await repository.tasks(), hasLength(1));
        expect(await repository.templates(), hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      }
    },
  );
  testWidgets(
    'template save retains failure and prevents duplicate pending saves',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () => showSaveTemplateDialog(
                  context,
                  sourceName: 'Research routine',
                  save: (name) async {
                    calls++;
                    if (name.trim().isEmpty) {
                      throw ArgumentError('Template name is required');
                    }
                    await pending.future;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save template'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Template name is required'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '週次 research – دراسة');
      final submit = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save template'),
          )
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Save reusable template'), findsOneWidget);
      expect(calls, 2);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Save reusable template'), findsNothing);
    },
  );

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets('dense templates and invalid payload are reachable at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final task = await repository.addTask(
        const TaskDraft(title: 'Read and annotate'),
      );
      await repository.saveTaskTemplate(task, 'A working recipe');
      final now = DateTime.now().toUtc().toIso8601String();
      await database.customStatement(
        'INSERT INTO templates VALUES(?,?,?,?,?,?)',
        [
          'invalid',
          'A incomplete project',
          'project',
          '{"version":1}',
          now,
          now,
        ],
      );
      for (var index = 0; index < 20; index++) {
        await repository.saveTaskTemplate(
          task,
          'Recipe $index — ${'دراسة résumé '.padRight(100, '長')}',
        );
      }
      final controller = AppController(repository);
      await controller.refresh();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appControllerProvider.overrideWith((ref) => controller),
            ],
            child: MaterialApp(
              theme: ThemeData(
                brightness: size.width == 360
                    ? Brightness.light
                    : Brightness.dark,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(body: TemplatesDialog()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('A working recipe'), 80);
        await tester.pumpAndSettle();
        await tester.tap(find.text('A working recipe'));
        await tester.pumpAndSettle();
        expect(find.text('Create from template'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('A incomplete project'), -80);
        await tester.pumpAndSettle();
        await tester.tap(find.text('A incomplete project'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('unsupported or incomplete format'),
          findsOneWidget,
        );
        expect(await repository.tasks(), hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byTooltip('Delete A incomplete project'),
          80,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Delete A incomplete project'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await repository.templates(), hasLength(22));
        await tester.tap(find.byTooltip('Delete A incomplete project'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete template').last);
        await tester.pumpAndSettle();
        expect(await repository.templates(), hasLength(21));
        expect(await repository.tasks(), hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.binding.setSurfaceSize(null);
      }
    });
  }

  testWidgets('routine can be applied repeatedly with independent identities', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    final today = localDate(DateTime.now());
    final source = await repository.addRecurringTask(
      TaskDraft(
        title: 'Reading routine',
        scheduledDate: today,
        priority: 2,
        plannedDurationMinutes: 25,
      ),
      RecurrenceRule(kind: RecurrenceKind.daily, startDate: today),
    );
    await repository.saveTaskTemplate(source, 'Reading days');
    final controller = AppController(repository);
    await controller.refresh();
    Future<void> mount() => tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const TemplatesDialog(),
                ),
                child: const Text('Templates'),
              ),
            ),
          ),
        ),
      ),
    );
    try {
      await mount();
      await tester.pumpAndSettle();
      for (var index = 0; index < 2; index++) {
        await tester.tap(find.text('Templates'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reading days'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create from template'));
        await tester.pumpAndSettle();
      }
      final tasks = await repository.tasks();
      // The controller materializes recurrence windows; compare series, not occurrence count.
      expect(tasks.map((t) => t.recurrenceSeriesId).toSet(), hasLength(3));
      expect(
        tasks.every((t) => t.priority == 2 && t.plannedDurationMinutes == 25),
        isTrue,
      );
      expect(tasks.every((t) => t.status == TaskStatus.notStarted), isTrue);
      expect(tasks.map((t) => t.id).toSet(), hasLength(tasks.length));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    }
  });
}
