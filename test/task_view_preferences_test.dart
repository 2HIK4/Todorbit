import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_view_preferences.dart';

void main() {
  test(
    'completed tasks remain eligible only when display preference allows',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final controller = AppController(repository);
      try {
        final today = localDate(DateTime.now());
        final finished = await repository.addTask(
          TaskDraft(title: 'Finished', scheduledDate: today),
        );
        await repository.addTask(
          TaskDraft(title: 'Open', scheduledDate: today),
        );
        await controller.refresh();
        await controller.setComplete(finished, true);
        controller.navigate(WorkspaceView.today);
        expect(controller.visibleTasks.map((task) => task.title), ['Open']);

        await controller.setTaskViewPreferences(
          const TaskViewPreferences(keepCompletedVisible: true),
        );
        expect(controller.visibleTasks.map((task) => task.title), [
          'Open',
          'Finished',
        ]);
        controller.navigate(WorkspaceView.completed);
        expect(
          controller.visibleTasks.map((task) => task.title),
          contains('Finished'),
        );
      } finally {
        await database.close();
      }
    },
  );
}
