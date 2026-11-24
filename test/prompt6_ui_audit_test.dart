import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/shared_inbox_store.dart';
import 'package:life_manager/domain/appearance.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_list_projection.dart';
import 'package:life_manager/features/shared/app_spacing.dart';
import 'package:life_manager/features/shared/app_theme.dart';
import 'package:life_manager/features/shared/pointer_cancellation_scope.dart';
import 'package:life_manager/features/shared/task_list_group.dart';
import 'package:life_manager/features/shared_inbox/shared_inbox_screen.dart';

void main() {
  group('Prompt 6 UI Audit & Coherent Design Tokens', () {
    test('Theme establishes subtle hover and distinct focus indicators', () {
      final theme = buildAppTheme(Brightness.dark, ThemePalette.dark);

      // Verify subtle hover (0.04 alpha, not harsh 0.08 default)
      expect(theme.hoverColor, isNotNull);
      expect(theme.hoverColor.a, closeTo(0.04, 0.01));

      // Verify distinct keyboard focus indicator (primary with 0.14 alpha)
      expect(theme.focusColor, isNotNull);
      expect(theme.focusColor.a, closeTo(0.14, 0.02));

      // Verify card theme clipping and normalized margin
      expect(theme.cardTheme.clipBehavior, equals(Clip.antiAlias));
      expect(theme.cardTheme.margin, equals(const EdgeInsets.only(bottom: 8)));

      // Verify list tile rounded corners eliminate square hover boxes
      expect(theme.listTileTheme.shape, isA<RoundedRectangleBorder>());
      final shape = theme.listTileTheme.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        equals(BorderRadius.circular(AppRadius.control)),
      );
    });

    testWidgets('Normal vs recurring task row widths are identical', (
      tester,
    ) async {
      final theme = buildAppTheme(Brightness.dark, ThemePalette.dark);
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final task1 = LifeTask(
        id: 't1',
        title: 'Ordinary Task',
        notes: '',
        status: TaskStatus.notStarted,
        priority: 0,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final recurring1 = LifeTask(
        id: 'r1',
        title: 'Recurring Occurrence',
        notes: '',
        status: TaskStatus.notStarted,
        priority: 0,
        recurrenceSeriesId: 'series_1',
        scheduledDate: '2026-11-20',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final normalGroup = TaskListGroup('g1', [task1], recurring: false);

      final recurringGroup = TaskListGroup('g2', [recurring1], recurring: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                children: [
                  TaskListGroupView(
                    key: const ValueKey('normal-group'),
                    group: normalGroup,
                    items: [task1],
                    parents: const {},
                    row: (t) => Card(
                      key: ValueKey('card-${t.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(title: Text(t.title)),
                    ),
                  ),
                  TaskListGroupView(
                    key: const ValueKey('recurring-group'),
                    group: recurringGroup,
                    items: [recurring1],
                    parents: const {},
                    row: (t) => Card(
                      key: ValueKey('card-${t.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(title: Text(t.title)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final ordinary = tester.getRect(find.byKey(const ValueKey('card-t1')));
      final recurring = tester.getRect(find.byType(ExpansionTile));
      expect(recurring.left, ordinary.left);
      expect(recurring.right, ordinary.right);
    });

    testWidgets('Subtasks render with hierarchy connector and no outer card', (
      tester,
    ) async {
      final theme = buildAppTheme(Brightness.dark, ThemePalette.dark);
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final parentTask = LifeTask(
        id: 'parent_1',
        title: 'Parent Task',
        notes: '',
        status: TaskStatus.notStarted,
        priority: 0,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final subtask = LifeTask(
        id: 'sub_1',
        title: 'Child Subtask',
        notes: '',
        status: TaskStatus.notStarted,
        priority: 0,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final group = TaskListGroup('parent_group', [
        parentTask,
      ], recurring: false);

      bool subtaskCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ListView(
              children: [
                TaskListGroupView(
                  group: group,
                  items: [parentTask, subtask],
                  parents: {'sub_1': 'parent_1'},
                  row: (t) => Card(
                    key: ValueKey('card-${t.id}'),
                    child: ListTile(title: Text(t.title)),
                  ),
                  subtaskRow: (t) => Material(
                    key: ValueKey('subtask-row-${t.id}'),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        Checkbox(
                          value: subtaskCompleted,
                          onChanged: (v) => subtaskCompleted = v ?? false,
                        ),
                        Text(t.title),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Parent is in a Card
      expect(find.byKey(const ValueKey('card-parent_1')), findsOneWidget);

      // Subtask is rendered via subtaskRow without being wrapped in another Card
      expect(find.byKey(const ValueKey('subtask-row-sub_1')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('subtask-row-sub_1')),
          matching: find.byType(Card),
        ),
        findsNothing,
      );

      final connector = find.ancestor(
        of: find.byKey(const ValueKey('subtask-row-sub_1')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).border is BorderDirectional,
        ),
      );
      expect(connector, findsOneWidget);

      // Subtask checkbox operates correctly
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(subtaskCompleted, isTrue);

      final toggle = find.widgetWithText(TextButton, '1 subtask');
      expect(toggle.hitTestable(), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      // Subtask is collapsed
      expect(find.byKey(const ValueKey('subtask-row-sub_1')), findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('subtask-row-sub_1')), findsOneWidget);
    });

    testWidgets('PointerCancellationScope handles deactivation and resume', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PointerCancellationScope(
              child: Center(
                child: InkWell(
                  key: const ValueKey('hover-item'),
                  onTap: () {},
                  child: const SizedBox(width: 100, height: 50),
                ),
              ),
            ),
          ),
        ),
      );

      final finder = find.byKey(const ValueKey('hover-item'));
      final center = tester.getCenter(finder);

      // Pointer down
      final gesture = await tester.startGesture(
        center,
        pointer: 5,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Trigger inactive
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      // Trigger resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      await gesture.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Responsive viewports render without overflow (Desktop & Android)',
      (tester) async {
        final theme = buildAppTheme(Brightness.dark, ThemePalette.dark);

        final viewports = [
          const Size(800, 600),
          const Size(1024, 768),
          const Size(1280, 800),
          const Size(1920, 1080),
          const Size(320, 640),
          const Size(360, 800),
          const Size(393, 852),
        ];

        for (final size in viewports) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: ListView(
                  children: [
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.task_alt),
                        title: const Text(
                          'Very long task title that must wrap cleanly across various screen sizes and text scalers',
                        ),
                        subtitle: const Text(
                          'Plan 2026-11-20 · Due 2026-11-25 · Priority 2',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Shared Files screen displays on-device local storage clarity',
      (tester) async {
        final root = Directory.systemTemp.createTempSync('shared-files-audit-');
        addTearDown(() => root.delete(recursive: true));
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.dark, ThemePalette.dark),
            home: SharedInboxScreen(store: SharedInboxStore(root)),
          ),
        );
        final empty = find.text('No shared files yet');
        for (
          var attempt = 0;
          attempt < 100 && empty.evaluate().isEmpty;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(empty, findsOneWidget);
        expect(
          find.textContaining('Files stay on this device until attached.'),
          findsOneWidget,
        );
      },
    );
  });
}
