import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';

void main() {
  late AppDatabase database;
  late LifeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(database);
  });

  tearDown(() async => database.close());

  test('task lifecycle persists through queries', () async {
    final category = await repository.addCategory('University');
    final project = await repository.addProject(category.id, 'Thesis');
    final task = await repository.addTask(
      TaskDraft(
        title: '  Draft outline  ',
        categoryId: category.id,
        projectId: project.id,
        scheduledDate: '2026-10-16',
        deadlineDate: '2026-10-20',
      ),
    );
    expect(task.title, 'Draft outline');
    expect(task.scheduledDate, '2026-10-16');
    expect(task.deadlineDate, '2026-10-20');
    expect(task.status, TaskStatus.notStarted);

    await repository.setComplete(task, true);
    final completed = (await repository.tasks()).single;
    expect(completed.status, TaskStatus.completed);
    expect(completed.completedAt, isNotNull);

    await repository.setComplete(completed, false);
    final reopened = (await repository.tasks()).single;
    expect(reopened.status, TaskStatus.notStarted);
    expect(reopened.completedAt, isNull);

    await repository.updateTask(
      reopened,
      TaskDraft(
        title: 'Write first draft',
        notes: 'Chapter one',
        categoryId: category.id,
        projectId: project.id,
        deadlineDate: '2026-10-20',
        priority: 3,
      ),
    );
    final edited = (await repository.tasks()).single;
    expect(edited.title, 'Write first draft');
    expect(edited.notes, 'Chapter one');
    expect(edited.scheduledDate, isNull);
    expect(edited.deadlineDate, '2026-10-20');

    await repository.deleteTask(edited.id);
    expect(await repository.tasks(), isEmpty);
  });

  test('rejects invalid project/category association', () async {
    final first = await repository.addCategory('Personal');
    final second = await repository.addCategory('Work');
    final project = await repository.addProject(first.id, 'Home');
    await expectLater(
      repository.addTask(
        TaskDraft(
          title: 'Bad association',
          categoryId: second.id,
          projectId: project.id,
        ),
      ),
      throwsArgumentError,
    );
    expect(await repository.tasks(), isEmpty);
  });

  test('task survives database close and reopen', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp(
      'life_manager_test_',
    );
    final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    try {
      await LifeRepository(first)
          .addTask(const TaskDraft(title: 'Persistent task'));
      await first.close();
      final second = AppDatabase(NativeDatabase(file));
      try {
        final tasks = await LifeRepository(second).tasks();
        expect(tasks.single.title, 'Persistent task');
      } finally {
        await second.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
