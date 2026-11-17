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
import 'package:life_manager/domain/focus_session.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';
import 'package:life_manager/features/workspace/task_editor.dart';

void main() {
  testWidgets(
    'mobile details edit returns to details and Focus survives return via mini timer',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('uiux03-mobile-');
      final db = AppDatabase(NativeDatabase.memory());
      final repo = LifeRepository(db);
      final task = await repo.addTask(const TaskDraft(title: 'Mobile journey'));
      final c = AppController(repo);
      await c.refresh();
      c.navigate(WorkspaceView.all);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appControllerProvider.overrideWith((ref) => c)],
            child: MaterialApp(
              home: MobileWorkspace(
                preferenceStore: MobilePreferenceStore(
                  File('${root.path}/mobile.json'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mobile journey').first);
        await tester.pumpAndSettle();
        expect(find.text('Task Details'), findsOneWidget);
        await tester.tap(find.byTooltip('Edit task'));
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditor), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('task-title-field')),
          'Mobile journey edited',
        );
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(find.text('Task Details'), findsOneWidget);
        await tester.tap(find.byTooltip('Edit task'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('task-title-field')))
              .controller!
              .text,
          'Mobile journey edited',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Task Details'), findsOneWidget);
        await tester.tap(find.text('Start Focus Session'));
        await tester.pumpAndSettle();
        expect(c.activeTimer?.taskId, task.id);
        expect(c.tasks.single.status, TaskStatus.notStarted);
        await tester.tap(find.text('Countdown'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();
        final session = c.focusSessions[task.id]!;
        expect(session.mode, FocusMode.countdown);
        expect(session.running, isTrue);
        await tester.tap(find.byTooltip('Return to tasks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mobile journey edited').first);
        await tester.pumpAndSettle();
        expect(identical(session, c.focusSessions[task.id]), isTrue);
        expect(find.text('COUNTING DOWN'), findsOneWidget);
        await tester.tap(find.text('Pomodoro'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await tester.runAsync(() => root.delete(recursive: true));
        await tester.binding.setSurfaceSize(null);
      }
    },
  );
}
