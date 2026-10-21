import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_resources.dart';
import 'package:life_manager/features/workspace/task_resources_section.dart';
import 'package:life_manager/features/workspace/windows_resource_dialog.dart';

class _FileDialog extends WindowsResourceDialog {
  _FileDialog(this.file);
  final File file;

  @override
  Future<File?> chooseFile() async => file;
}

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
            body: TaskResourcesSection(taskId: task.id, repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No resources attached'), findsNothing);
      final center = tester.getCenter(find.byType(TaskResourcesSection));
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

  testWidgets('missing external file stays visible as unavailable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    final directory = Directory.systemTemp.createTempSync('life-resource-ui-');
    final file = File('${directory.path}/external.txt')
      ..writeAsStringSync('linked');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    try {
      final task = await repository.addTask(const TaskDraft(title: 'Task'));
      await repository.addExternalResource(
        task.id,
        TaskResourceKind.externalFile,
        file.path,
      );
      file.deleteSync();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskResourcesSection(taskId: task.id, repository: repository),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('external.txt'), findsOneWidget);
      expect(
        find.textContaining('Unavailable or inaccessible'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      directory.deleteSync(recursive: true);
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('task resource controls attach, rename, and remove a copy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    final directory = Directory.systemTemp.createTempSync('life-resource-ui-');
    final file = File('${directory.path}/document.txt')
      ..writeAsStringSync('document');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = LifeRepository(database);
    try {
      final task = await repository.addTask(const TaskDraft(title: 'Task'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TaskResourcesSection(
                taskId: task.id,
                repository: repository,
                dialog: _FileDialog(file),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Attach a copy of a file'), findsOneWidget);
      await tester.tap(find.byTooltip('Attach a copy of a file'));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byIcon(Icons.attach_file),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if ((await repository.taskResources(task.id)).isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(await repository.taskResources(task.id), hasLength(1));
      expect(find.text('document.txt'), findsOneWidget);
      expect(
        (await repository.taskResources(task.id)).single.label,
        'document.txt',
      );
      await tester.tap(find.byTooltip('Resource actions for document.txt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Reference copy');
      await tester.tap(find.text('Save'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reference copy'), findsOneWidget);
      await tester.tap(find.byTooltip('Resource actions for Reference copy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.textContaining('stored copy'), findsOneWidget);
      await tester.tap(find.text('Remove').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(await repository.taskResources(task.id), isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
      directory.deleteSync(recursive: true);
      await tester.binding.setSurfaceSize(null);
    }
  });
}
