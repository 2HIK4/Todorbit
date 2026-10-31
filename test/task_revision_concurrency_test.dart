import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/app_controller.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/platform/android/android_widget_action.dart';

class _PausedCompletionRepository extends LifeRepository {
  _PausedCompletionRepository(super.db, {super.taskClock});
  final entered = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<void> setComplete(LifeTask task, bool complete) async {
    entered.complete();
    await resume.future;
    await super.setComplete(task, complete);
  }
}

void main() {
  late AppDatabase db;
  late LifeRepository repository;
  late DateTime clock;
  setUp(() {
    clock = DateTime.utc(2030, 1, 1);
    db = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(db, taskClock: () => clock);
  });
  tearDown(() => db.close());
  Future<LifeTask> current(String id) async =>
      (await repository.tasks()).singleWhere((t) => t.id == id);

  test('identical wall times and ABA edits never reuse a revision', () async {
    final first = await repository.addTask(const TaskDraft(title: 'A'));
    await repository.updateTask(first, const TaskDraft(title: 'B'));
    final second = await current(first.id);
    await repository.updateTask(second, const TaskDraft(title: 'A'));
    final third = await current(first.id);
    expect(first.createdAt, clock);
    expect(second.updatedAt, clock.add(const Duration(microseconds: 1)));
    expect(third.updatedAt, clock.add(const Duration(microseconds: 2)));
    await expectLater(repository.setComplete(first, true), throwsStateError);
    expect((await current(first.id)).isOpen, isTrue);
  });

  test(
    'rapid edits and clock rollback keep persistent tokens increasing',
    () async {
      var task = await repository.addTask(const TaskDraft(title: 'Start'));
      final oldest = task;
      clock = clock.subtract(const Duration(days: 1));
      for (var i = 0; i < 50; i++) {
        await repository.updateTask(task, TaskDraft(title: 'Edit $i'));
        final next = await current(task.id);
        expect(next.updatedAt.isAfter(task.updatedAt), isTrue);
        task = next;
      }
      await expectLater(
        repository.updateTask(oldest, const TaskDraft(title: 'Lost')),
        throwsStateError,
      );
      await repository.setComplete(task, true);
      final done = await current(task.id);
      expect(done.updatedAt.isAfter(task.updatedAt), isTrue);
      expect(
        done.completedAt,
        clock,
      ); // Actual completion time is separate from revision.
    },
  );

  test('edit between widget snapshot validation and completion is rejected atomically', () async {
    final directory = await Directory.systemTemp.createTemp(
      'todorbit-revision-',
    );
    final file = File('${directory.path}/isolated.sqlite');
    final firstDb = AppDatabase(NativeDatabase(file));
    final secondDb = AppDatabase(NativeDatabase(file));
    try {
      final first = _PausedCompletionRepository(
        firstDb,
        taskClock: () => clock,
      );
      final second = LifeRepository(secondDb, taskClock: () => clock);
      final task = await first.addTask(const TaskDraft(title: 'Before'));
      final controller = AppController(first);
      final pending = applyAndroidWidgetAction(controller, {
        'id': task.id,
        'revision': task.revision,
        'complete': true,
      });
      final rejected = expectLater(pending, throwsStateError);
      await first.entered.future;
      await second.updateTask(
        task,
        const TaskDraft(title: 'Other connection edit'),
      );
      first.resume.complete();
      await rejected;
      final after = (await second.tasks()).single;
      expect(after.title, 'Other connection edit');
      expect(after.isOpen, isTrue);
    } finally {
      await firstDb.close();
      await secondDb.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'competing completion and edit cannot both mutate the same snapshot',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Before'));
      Future<Object?> result(Future<void> operation) async {
        try {
          await operation;
          return null;
        } catch (error) {
          return error;
        }
      }

      final outcomes = await Future.wait([
        result(repository.setComplete(task, true)),
        result(repository.updateTask(task, const TaskDraft(title: 'After'))),
      ]);
      expect(outcomes.where((o) => o == null).length, 1);
      expect(outcomes.whereType<StateError>().length, 1);
      final after = await current(task.id);
      expect(
        after.status == TaskStatus.completed
            ? after.title == 'Before'
            : after.title == 'After',
        isTrue,
      );
    },
  );

  test(
    'duplicate widgets do not write twice; delayed tap cannot undo reopening',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Task'));
      final firstWidget = AppController(repository);
      final secondWidget = AppController(repository);
      final command = {
        'id': task.id,
        'revision': task.revision,
        'complete': true,
      };
      await Future.wait([
        applyAndroidWidgetAction(firstWidget, command),
        applyAndroidWidgetAction(secondWidget, command),
      ]);
      final done = await current(task.id);
      await expectLater(repository.setComplete(task, true), throwsStateError);
      await repository.setComplete(done, true);
      expect((await current(task.id)).revision, done.revision);
      await repository.setComplete(done, false);
      await expectLater(
        applyAndroidWidgetAction(firstWidget, command),
        throwsStateError,
      );
      expect((await current(task.id)).isOpen, isTrue);
    },
  );

  test('legacy native token format is preserved through SQLite CAS', () async {
    final task = await repository.addTask(const TaskDraft(title: 'Native'));
    await db.customStatement('UPDATE tasks SET updated_at=? WHERE id=?', [
      '2030-01-01T00:00:00.000000Z',
      task.id,
    ]);
    final native = await current(task.id);
    expect(native.revision, '2030-01-01T00:00:00.000000Z');
    await repository.setComplete(native, true);
    final done = await current(task.id);
    expect(done.revision, '2030-01-01T00:00:00.000001Z');
    expect(AppDatabase.currentSchemaVersion, 22);
  });

  test(
    'trash and restoration invalidate old commands even with a frozen clock',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Task'));
      await repository.deleteTask(task.id);
      await expectLater(repository.setComplete(task, true), throwsStateError);
      final trash = (await repository.trash()).single;
      await repository.restoreTrashItem(trash);
      await expectLater(repository.setComplete(task, true), throwsStateError);
      await repository.setComplete(await current(task.id), true);
    },
  );

  test(
    'working status and prerequisite edits invalidate frozen-clock snapshots',
    () async {
      final task = await repository.addTask(const TaskDraft(title: 'Task'));
      await repository.setTaskWorking(task, true);
      await expectLater(repository.setComplete(task, true), throwsStateError);
      final working = await current(task.id);
      await repository.setPrerequisites(working, {});
      await expectLater(
        repository.setComplete(working, true),
        throwsStateError,
      );
    },
  );
}
