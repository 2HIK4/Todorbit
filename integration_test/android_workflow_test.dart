import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/mobile_preference_store.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/features/mobile/mobile_workspace.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android mobile task, calendar, persistence and snapshot workflow',(tester) async {
    // Fresh app-private temporary data only. Never reset the active profile.
    final root=await Directory.systemTemp.createTemp('todorbit-integration-');
    final file=File('${root.path}/life_manager.sqlite');
    var database=AppDatabase(NativeDatabase(file));
    final repository=LifeRepository(database);
    final controller=AppController(repository);
    try {
      final category=await repository.addCategory('Integration category');
      final project=await repository.addProject(category.id,'Integration project');
      await controller.refresh();
      await tester.pumpWidget(ProviderScope(overrides:[appControllerProvider.overrideWith((ref)=>controller)],
        child:MaterialApp(theme:ThemeData(useMaterial3:true),home:MobileWorkspace(
          preferenceStore:MobilePreferenceStore(File('${root.path}/mobile.json'))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New task'));await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('task-title-field')),'Android integration task');
      await tester.tap(find.widgetWithText(FilledButton,'Create task'));await tester.pumpAndSettle();
      final task=(await repository.tasks()).single;
      expect(task.notification.enabled,isFalse);
      await repository.updateTask(task,TaskDraft(title:task.title,categoryId:category.id,projectId:project.id,
        scheduledDate:localDate(DateTime.now()),deadlineDate:localDate(DateTime.now().add(const Duration(days:2)))));
      await controller.refresh();
      final start=DateTime.now().add(const Duration(hours:1));
      await controller.addEvent(EventDraft(title:'Android integration event',startsAt:start,endsAt:start.add(const Duration(hours:1))));
      controller.navigate(WorkspaceView.calendar);await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Android integration event'));await tester.tap(find.text('Android integration event'));
      await tester.pumpAndSettle();expect(find.text('Title *'),findsOneWidget);
      // Closing an unchanged event uses the shared event editor.
      final close=find.byTooltip('Close event');
      if(close.evaluate().isNotEmpty) {await tester.tap(close);await tester.pumpAndSettle();}
      final snapshot=await BackupService(file).exportTo(File('${root.path}/portable.sqlite'));
      expect(await snapshot.exists(),isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      database=AppDatabase(NativeDatabase(file));
      final reopened=LifeRepository(database);
      expect((await reopened.tasks()).single.id,task.id);
      expect((await reopened.projects()).single.id,project.id);
      expect((await reopened.events()).single.title,'Android integration event');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();await root.delete(recursive:true);
    }
  });
}
