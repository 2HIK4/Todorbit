import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_resources.dart';
import 'package:life_manager/features/workspace/unified_resources_section.dart';

void main() {
  testWidgets('Explorer drop links one file and ignores duplicate paths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    const channel = MethodChannel('life_manager/file_drop');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'available',
    );
    final directory = Directory.systemTemp.createTempSync('resource-drop-');
    final file = File('${directory.path}/paper.txt')..writeAsStringSync('text');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    try {
      final task = await repository.addTask(const TaskDraft(title: 'Task'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedResourcesSection.persisted(
              taskId: task.id,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No resources attached'), findsNothing);
      final center = tester.getCenter(find.byType(UnifiedResourcesSection));
      final arguments = {
        'x': center.dx,
        'y': center.dy,
        'files': [file.path, file.path],
      };
      final message = const StandardMethodCodec().encodeMethodCall(
        MethodCall('drop', arguments),
      );
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'life_manager/file_drop',
        message,
        (_) {},
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add 1 file?'), findsOneWidget);
      await tester.tap(find.text('Link originals'));
      await tester.pumpAndSettle();
      expect(await repository.taskResources(task.id), hasLength(1));
      expect(
        (await repository.taskResources(task.id)).single.kind,
        TaskResourceKind.externalFile,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await database.close();
      directory.deleteSync(recursive: true);
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('Chrome URL payload creates a resource without a shortcut file', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    const channel = MethodChannel('life_manager/file_drop');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'available',
    );
    final directory = Directory.systemTemp.createTempSync('resource-drop-');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    try {
      final task = await repository.addTask(const TaskDraft(title: 'Task'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedResourcesSection.persisted(
              taskId: task.id,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No resources attached'), findsNothing);
      final center = tester.getCenter(find.byType(UnifiedResourcesSection));
      final arguments = {
        'x': center.dx,
        'y': center.dy,
        'urls': ['https://example.com/chrome?q=one'],
      };
      final message = const StandardMethodCodec().encodeMethodCall(
        MethodCall('urlDrop', arguments),
      );
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'life_manager/file_drop',
        message,
        (_) {},
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(await repository.taskResources(task.id), hasLength(1));
      expect(
        (await repository.taskResources(task.id)).single.target,
        'https://example.com/chrome?q=one',
      );
      expect(
        (await repository.taskResources(task.id)).single.kind,
        TaskResourceKind.url,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await database.close();
      directory.deleteSync(recursive: true);
      await tester.binding.setSurfaceSize(null);
    }
  });
  testWidgets(
    'Folder drop with attach choice preserves folder as an external link',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      const channel = MethodChannel('life_manager/file_drop');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'available',
      );
      final directory = Directory.systemTemp.createTempSync('resource-drop-');
      final file = Directory('${directory.path}/folder')..createSync();
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      try {
        final task = await repository.addTask(const TaskDraft(title: 'Task'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UnifiedResourcesSection.persisted(
                taskId: task.id,
                repository: repository,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('No resources attached'), findsNothing);
        final center = tester.getCenter(find.byType(UnifiedResourcesSection));
        final arguments = {
          'x': center.dx,
          'y': center.dy,
          'files': [file.path, file.path],
        };
        final message = const StandardMethodCodec().encodeMethodCall(
          MethodCall('drop', arguments),
        );
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'life_manager/file_drop',
          message,
          (_) {},
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Add 1 file?'), findsOneWidget);
        await tester.tap(find.text('Attach copies'));
        await tester.pumpAndSettle();
        expect(await repository.taskResources(task.id), hasLength(1));
        expect(
          (await repository.taskResources(task.id)).single.kind,
          TaskResourceKind.externalFolder,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        await database.close();
        directory.deleteSync(recursive: true);
        await tester.binding.setSurfaceSize(null);
      }
    },
  );

  testWidgets('Image file drop attaches portable bytes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    const channel = MethodChannel('life_manager/file_drop');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'available',
    );
    final directory = Directory.systemTemp.createTempSync('resource-drop-');
    final file = File('${directory.path}/image.png')..writeAsStringSync('text');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    try {
      final task = await repository.addTask(const TaskDraft(title: 'Task'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedResourcesSection.persisted(
              taskId: task.id,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No resources attached'), findsNothing);
      final center = tester.getCenter(find.byType(UnifiedResourcesSection));
      final arguments = {
        'x': center.dx,
        'y': center.dy,
        'files': [file.path, file.path],
      };
      final message = const StandardMethodCodec().encodeMethodCall(
        MethodCall('drop', arguments),
      );
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'life_manager/file_drop',
        message,
        (_) {},
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add 1 file?'), findsOneWidget);
      await tester.tap(find.text('Attach copies'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 20 && (await repository.taskResources(task.id)).isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(await repository.taskResources(task.id), hasLength(1));
      expect(
        (await repository.taskResources(task.id)).single.kind,
        TaskResourceKind.managed,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await database.close();
      directory.deleteSync(recursive: true);
      await tester.binding.setSurfaceSize(null);
    }
  });
}
