import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/platform/android/android_widget_action.dart';

void main() {
  late AppDatabase database;
  late AppController controller;
  final frozenTime = DateTime.utc(2026, 10, 31, 12);
  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    controller = AppController(
      LifeRepository(database, taskClock: () => frozenTime),
    );
    await controller.refresh();
  });
  tearDown(() async => database.close());

  Map<String, dynamic> command(LifeTask task, bool complete) => {
    'id': task.id,
    'revision': task.revision,
    'complete': complete,
  };

  test('completion identifies same-title tasks by ID and can reopen', () async {
    final first = await controller.repository.addTask(TaskDraft(title: 'Same'));
    final second = await controller.repository.addTask(
      TaskDraft(title: 'Same'),
    );
    await applyAndroidWidgetAction(controller, command(second, true));
    expect(
      controller.tasks.singleWhere((t) => t.id == first.id).isOpen,
      isTrue,
    );
    final done = controller.tasks.singleWhere((t) => t.id == second.id);
    expect(done.status, TaskStatus.completed);
    await applyAndroidWidgetAction(controller, command(done, false));
    expect(
      controller.tasks.singleWhere((t) => t.id == second.id).isOpen,
      isTrue,
    );
  });

  test('stale completion cannot overwrite an edit', () async {
    final task = await controller.repository.addTask(
      TaskDraft(title: 'Before'),
    );
    await controller.repository.updateTask(task, TaskDraft(title: 'After'));
    await expectLater(
      applyAndroidWidgetAction(controller, command(task, true)),
      throwsStateError,
    );
    expect((await controller.repository.tasks()).single.title, 'After');
    expect((await controller.repository.tasks()).single.isOpen, isTrue);
  });

  test(
    'repeated completion advances after-completion recurrence once',
    () async {
      final first = await controller.repository.addRecurringTask(
        TaskDraft(title: 'Repeat', scheduledDate: localDate(frozenTime)),
        RecurrenceRule(
          kind: RecurrenceKind.afterCompletion,
          startDate: localDate(frozenTime),
          interval: 2,
        ),
      );
      final action = command(first, true);
      await applyAndroidWidgetAction(controller, action);
      await applyAndroidWidgetAction(controller, action);
      expect(controller.tasks.length, 2);
      expect(controller.tasks.where((t) => t.isOpen).length, 1);
      final done = controller.tasks.singleWhere((t) => t.id == first.id);
      await expectLater(
        applyAndroidWidgetAction(controller, command(done, false)),
        throwsStateError,
      );
    },
  );

  test('deleted tasks cannot be completed', () async {
    final task = await controller.repository.addTask(TaskDraft(title: 'Gone'));
    await controller.repository.deleteTask(task.id);
    await expectLater(
      applyAndroidWidgetAction(controller, command(task, true)),
      throwsStateError,
    );
  });
}
