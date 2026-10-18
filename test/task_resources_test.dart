import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_resources.dart';
import 'package:life_manager/domain/trash.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class _ChangingFile implements File {
  _ChangingFile(this.source);
  final File source;

  @override
  String get path => source.path;

  @override
  Future<FileStat> stat() => source.stat();

  @override
  Future<Uint8List> readAsBytes() async {
    final bytes = await source.readAsBytes();
    await source.writeAsBytes([...bytes, 42], flush: true);
    return bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('managed copies, external references, and task lifecycle', () async {
    final directory = await Directory.systemTemp.createTemp('life-resources-');
    final database = AppDatabase(
      NativeDatabase(File('${directory.path}/life.sqlite')),
    );
    final repository = LifeRepository(database);
    try {
      final task = await repository.addTask(
        const TaskDraft(title: 'Read sources'),
      );
      final first = Directory('${directory.path}/first')..createSync();
      final second = Directory('${directory.path}/second')..createSync();
      final source = File('${first.path}/notes.txt')
        ..writeAsStringSync('alpha');
      final duplicate = File('${second.path}/notes.txt')
        ..writeAsStringSync('beta');
      final attached = await repository.attachManagedFile(task.id, source);
      final other = await repository.attachManagedFile(task.id, duplicate);
      expect(attached.id, isNot(other.id));
      expect(attached.originalName, 'notes.txt');
      expect(
        await repository.managedAttachmentBytes(attached),
        'alpha'.codeUnits,
      );
      final external = await repository.addExternalResource(
        task.id,
        TaskResourceKind.externalFile,
        source.path,
      );
      final folder = await repository.addExternalResource(
        task.id,
        TaskResourceKind.externalFolder,
        first.path,
      );
      final url = await repository.addExternalResource(
        task.id,
        TaskResourceKind.url,
        'https://example.com/work',
      );
      await repository.renameTaskResource(external, 'Reference notes');
      await repository.updateTaskUrl(url, 'obsidian://open?vault=Work');
      expect((await repository.taskResources(task.id)).length, 5);
      source.deleteSync();
      expect(
        await repository.managedAttachmentBytes(attached),
        'alpha'.codeUnits,
      );
      expect(
        (await repository.taskResources(task.id))
            .singleWhere((item) => item.id == external.id)
            .target,
        external.target,
      );
      await repository.archiveTask(task);
      expect(await repository.taskResources(task.id), hasLength(5));
      await repository.restoreArchivedTask(
        (await repository.archivedTasks()).single,
      );
      await repository.moveToTrash(TrashKind.task, task.id);
      expect(await repository.taskResources(task.id), hasLength(5));
      await repository.restoreTrashItem((await repository.trash()).single);
      expect(await repository.taskResources(task.id), hasLength(5));
      await repository.removeTaskResource(other);
      await repository.removeTaskResource(folder);
      expect(await repository.taskResources(task.id), hasLength(3));
      await repository.moveToTrash(TrashKind.task, task.id);
      await repository.permanentlyDelete((await repository.trash()).single);
      expect(await repository.taskResources(task.id), isEmpty);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test('invalid inputs and oversized files leave no resource rows', () async {
    final directory = await Directory.systemTemp.createTemp('life-resources-');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    try {
      final task = await repository.addTask(const TaskDraft(title: 'Safe'));
      for (final invalid in [
        'javascript:alert(1)',
        'file:///C:/secret',
        'http://',
      ]) {
        await expectLater(
          repository.addExternalResource(
            task.id,
            TaskResourceKind.url,
            invalid,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        repository.addExternalResource(
          task.id,
          TaskResourceKind.externalFile,
          '${directory.path}/missing.txt',
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.attachManagedFile(
          task.id,
          File('${directory.path}/missing.txt'),
        ),
        throwsArgumentError,
      );
      final changing = File('${directory.path}/changing.txt')
        ..writeAsStringSync('first');
      await expectLater(
        repository.attachManagedFile(task.id, _ChangingFile(changing)),
        throwsStateError,
      );
      final large = File('${directory.path}/large.bin');
      final handle = large.openSync(mode: FileMode.write);
      try {
        handle.truncateSync(16 * 1024 * 1024 + 1);
      } finally {
        handle.closeSync();
      }
      await expectLater(
        repository.attachManagedFile(task.id, large),
        throwsArgumentError,
      );
      expect(await repository.taskResources(task.id), isEmpty);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test('v14 upgrade keeps tasks and adds resource table', () async {
    final directory = await Directory.systemTemp.createTemp('life-resources-');
    final file = File('${directory.path}/life.sqlite');
    try {
      final created = AppDatabase(NativeDatabase(file));
      final task = await LifeRepository(created)
          .addTask(const TaskDraft(title: 'Before upgrade'));
      await created.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('DROP TABLE task_resources');
        raw.execute('PRAGMA user_version=14');
      } finally {
        raw.close();
      }
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final repository = LifeRepository(upgraded);
        expect((await repository.tasks()).single.id, task.id);
        expect(await repository.taskResources(task.id), isEmpty);
      } finally {
        await upgraded.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'portable transfer includes attachment bytes and rejects tampering',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'life-resources-',
      );
      final firstFile = File('${directory.path}/first.sqlite');
      final secondFile = File('${directory.path}/second.sqlite');
      final portable = File('${directory.path}/portable.sqlite');
      try {
        final first = AppDatabase(NativeDatabase(firstFile));
        final sourceRepository = LifeRepository(first);
        final task = await sourceRepository.addTask(
          const TaskDraft(title: 'Portable'),
        );
        final file = File('${directory.path}/payload.txt')
          ..writeAsStringSync('portable bytes');
        final attachment = await sourceRepository.attachManagedFile(
          task.id,
          file,
        );
        await BackupService(firstFile).exportTo(portable);
        await first.close();
        final second = AppDatabase(NativeDatabase(secondFile));
        await LifeRepository(second)
            .addTask(const TaskDraft(title: 'Replace me'));
        final service = BackupService(secondFile);
        final staged = await service.importSnapshot(
          portable,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        await service.scheduleRestore(
          staged,
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        await second.close();
        final before = await service.applyScheduledRestore(
          appSchemaVersion: AppDatabase.currentSchemaVersion,
        );
        expect(before?.kind, BackupKind.beforeRestore);
        final restored = AppDatabase(NativeDatabase(secondFile));
        try {
          final repository = LifeRepository(restored);
          expect((await repository.tasks()).single.id, task.id);
          final copy = (await repository.taskResources(task.id)).single;
          expect(copy.id, attachment.id);
          expect(
            await repository.managedAttachmentBytes(copy),
            'portable bytes'.codeUnits,
          );
        } finally {
          await restored.close();
        }
        final raw = sqlite.sqlite3.open(portable.path);
        try {
          raw.execute("UPDATE task_resources SET content=X'00'");
        } finally {
          raw.close();
        }
        await expectLater(
          service.importSnapshot(
            portable,
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsStateError,
        );
        final unsafeName = File('${directory.path}/unsafe-name.sqlite');
        await BackupService(secondFile).exportTo(unsafeName);
        final unsafe = sqlite.sqlite3.open(unsafeName.path);
        try {
          unsafe.execute(
            "UPDATE task_resources SET original_name='../escape.txt'",
          );
        } finally {
          unsafe.close();
        }
        await expectLater(
          service.importSnapshot(
            unsafeName,
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsStateError,
        );
        expect(await service.pendingRestoreName(), isNull);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('blocked restore keeps live attachment and pending request', () async {
    final directory = await Directory.systemTemp.createTemp('life-resources-');
    final liveFile = File('${directory.path}/live.sqlite');
    final sourceFile = File('${directory.path}/source.sqlite');
    try {
      final source = AppDatabase(NativeDatabase(sourceFile));
      final sourceRepository = LifeRepository(source);
      final sourceTask = await sourceRepository.addTask(
        const TaskDraft(title: 'Incoming'),
      );
      final incoming = File('${directory.path}/incoming.txt')
        ..writeAsStringSync('incoming bytes');
      await sourceRepository.attachManagedFile(sourceTask.id, incoming);
      final portable = File('${directory.path}/portable.sqlite');
      await BackupService(sourceFile).exportTo(portable);
      await source.close();

      final live = AppDatabase(NativeDatabase(liveFile));
      await live.customStatement('PRAGMA journal_mode=WAL');
      final liveRepository = LifeRepository(live);
      final liveTask = await liveRepository.addTask(
        const TaskDraft(title: 'Current'),
      );
      final current = File('${directory.path}/current.txt')
        ..writeAsStringSync('current bytes');
      await liveRepository.attachManagedFile(liveTask.id, current);
      final service = BackupService(liveFile);
      final staged = await service.importSnapshot(
        portable,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await service.scheduleRestore(
        staged,
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      await live.close();

      final reader = sqlite.sqlite3.open(liveFile.path);
      try {
        reader.execute('BEGIN');
        reader.select('SELECT COUNT(*) FROM task_resources');
        await expectLater(
          service.applyScheduledRestore(
            appSchemaVersion: AppDatabase.currentSchemaVersion,
          ),
          throwsA(isA<Exception>()),
        );
      } finally {
        reader.close();
      }
      expect(await service.pendingRestoreName(), isNotNull);
      final unchanged = AppDatabase(NativeDatabase(liveFile));
      try {
        final repository = LifeRepository(unchanged);
        expect((await repository.tasks()).single.id, liveTask.id);
        final attachment = (await repository.taskResources(liveTask.id)).single;
        expect(
          await repository.managedAttachmentBytes(attachment),
          'current bytes'.codeUnits,
        );
      } finally {
        await unchanged.close();
      }
      await service.applyScheduledRestore(
        appSchemaVersion: AppDatabase.currentSchemaVersion,
      );
      final restored = AppDatabase(NativeDatabase(liveFile));
      try {
        final repository = LifeRepository(restored);
        expect((await repository.tasks()).single.id, sourceTask.id);
        final attachment = (await repository.taskResources(sourceTask.id))
            .single;
        expect(
          await repository.managedAttachmentBytes(attachment),
          'incoming bytes'.codeUnits,
        );
      } finally {
        await restored.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
