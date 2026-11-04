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
import 'package:life_manager/platform/android/android_platform.dart';

import 'support/profile_journey_environment.dart';

class _Picker extends WindowsResourceDialog {
  File? file;
  Directory? folder;
  bool denied = false;
  final opened = <String>[];
  @override
  Future<File?> chooseFile() async {
    if (denied) throw const FileSystemException('Synthetic permission denied');
    return file;
  }

  @override
  Future<Directory?> chooseFolder() async => folder;
  @override
  Future<void> open(String target) async {
    if (denied) throw const FileSystemException('Synthetic access denied');
    opened.add(target);
  }
}

Future<void> _io(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    final attach = find.ancestor(
      of: find.byIcon(Icons.attach_file),
      matching: find.byType(IconButton),
    );
    if (attach.evaluate().isNotEmpty &&
        tester.widget<IconButton>(attach).onPressed != null &&
        find.byType(LinearProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Resource operation did not finish');
}

Future<void> _action(WidgetTester tester, String label, String action) async {
  final target = find.byTooltip('Resource actions for $label');
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await _io(tester);
}

void main() {
  testWidgets(
    'Android document adapter returns cancellation selection and denied access',
    (tester) async {
      String? selected;
      bool denied = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AndroidPlatform.channel,
        (call) async {
          expect(call.method, 'importDocument');
          expect(call.arguments, 'application/pdf');
          if (denied) {
            throw PlatformException(
              code: 'document',
              message: 'Synthetic provider denied access',
            );
          }
          return selected;
        },
      );
      try {
        expect(
          await AndroidPlatform.importDocument(mime: 'application/pdf'),
          isNull,
        );
        selected = '/data/user/0/synthetic/cache/ورقة.pdf';
        expect(
          (await AndroidPlatform.importDocument(mime: 'application/pdf'))!.path,
          selected,
        );
        denied = true;
        await expectLater(
          AndroidPlatform.importDocument(mime: 'application/pdf'),
          throwsA(isA<PlatformException>()),
        );
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          AndroidPlatform.channel,
          null,
        );
      }
    },
  );
  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets(
      'dense Unicode resources remain removable at 200 percent $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        final database = AppDatabase(NativeDatabase.memory());
        final repository = LifeRepository(database);
        final task = await repository.addTask(
          const TaskDraft(title: 'Reading collection'),
        );
        for (var index = 0; index < 30; index++) {
          await repository.addExternalResource(
            task.id,
            TaskResourceKind.url,
            'https://example.com/paper/$index',
            label: 'Paper $index — ${'دراسة résumé 長'.padRight(100, '長')}',
          );
        }
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: size.width == 360
                    ? Brightness.light
                    : Brightness.dark,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: TaskResourcesSection(
                    taskId: task.id,
                    repository: repository,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final last = (await repository.taskResources(task.id)).last;
          await _action(tester, last.label, 'Remove');
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(await repository.taskResources(task.id), hasLength(30));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await database.close();
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }

  testWidgets(
    'resource picker cancel, denial, all types, open and safe removal',
    (tester) async {
      final root = Directory.systemTemp.createTempSync(
        'todorbit-b5-resources-',
      );
      final file = File('${root.path}/ورقة – résumé 📎.txt')
        ..writeAsStringSync('original bytes');
      final folder = Directory('${root.path}/资料')..createSync();
      final database = AppDatabase(NativeDatabase.memory());
      final repository = LifeRepository(database);
      final task = await repository.addTask(const TaskDraft(title: 'Research'));
      final picker = _Picker();
      Future<void> mount() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TaskResourcesSection(
                taskId: task.id,
                repository: repository,
                dialog: picker,
              ),
            ),
          ),
        ),
      );
      try {
        await mount();
        await _io(tester);
        await tester.tap(find.byTooltip('Attach a copy of a file'));
        await _io(tester);
        await tester.tap(find.byTooltip('Link an existing folder'));
        await _io(tester);
        expect(await repository.taskResources(task.id), isEmpty);
        picker.denied = true;
        await tester.tap(find.byTooltip('Attach a copy of a file'));
        await _io(tester);
        expect(
          find.textContaining('Synthetic permission denied'),
          findsOneWidget,
        );
        expect(await repository.taskResources(task.id), isEmpty);
        picker.denied = false;
        picker.file = file;
        picker.folder = folder;
        for (final tooltip in [
          'Attach a copy of a file',
          'Link an existing file',
          'Link an existing folder',
        ]) {
          await tester.tap(find.byTooltip(tooltip));
          await _io(tester);
        }
        await tester.tap(find.byTooltip('Add a URL'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'https://example.com/research',
        );
        await tester.tap(find.text('Save'));
        await _io(tester);
        final resources = await repository.taskResources(task.id);
        expect(
          resources.map((r) => r.kind).toSet(),
          TaskResourceKind.values.toSet(),
        );
        final managed = resources.singleWhere(
          (r) => r.kind == TaskResourceKind.managed,
        );
        final external = resources.singleWhere(
          (r) => r.kind == TaskResourceKind.externalFile,
        );
        await repository.renameTaskResource(managed, 'Portable paper');
        await tester.pumpWidget(const SizedBox.shrink());
        await mount();
        await _io(tester);
        // Opening a managed copy writes only into the runner's isolated profile cache.
        expect(isolatedProfileJourneys, isTrue);
        for (final resource in resources) {
          await _action(
            tester,
            resource.kind == TaskResourceKind.managed
                ? 'Portable paper'
                : resource.label,
            'Open',
          );
        }
        expect(picker.opened, hasLength(4));
        expect(
          File(picker.opened.first).readAsBytesSync(),
          'original bytes'.codeUnits,
        );
        picker.denied = true;
        await _action(tester, external.label, 'Open');
        expect(find.textContaining('Synthetic access denied'), findsOneWidget);
        picker.denied = false;
        final renamed = file.renameSync('${root.path}/renamed.txt');
        await _action(tester, external.label, 'Open');
        expect(
          find.textContaining('External resource is unavailable'),
          findsOneWidget,
        );
        await _action(tester, external.label, 'Remove');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await repository.taskResources(task.id), hasLength(4));
        await _action(tester, external.label, 'Remove');
        await tester.tap(find.text('Remove').last);
        await _io(tester);
        expect(renamed.readAsStringSync(), 'original bytes');
        expect(folder.existsSync(), isTrue);
        final saved = (await repository.taskResources(task.id))
            .singleWhere((r) => r.id == managed.id);
        expect(
          await repository.managedAttachmentBytes(saved),
          'original bytes'.codeUnits,
        );
        expect(saved.sha256, managed.sha256);
        expect(saved.originalName, managed.originalName);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
        await tester.runAsync(() => root.delete(recursive: true));
      }
    },
    skip: !isolatedProfileJourneys,
  );

  testWidgets(
    'native Windows picker adapter cancellation selection and errors',
    (tester) async {
      const channel = MethodChannel('life_manager/file_dialog');
      final adapter = const WindowsResourceDialog();
      String? answer;
      bool denied = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (denied) {
          throw PlatformException(code: 'denied', message: 'Access denied');
        }
        return answer;
      });
      try {
        expect(await adapter.chooseFile(), isNull);
        expect(await adapter.chooseFolder(), isNull);
        answer = 'C:\\synthetic\\résumé.txt';
        expect((await adapter.chooseFile())!.path, answer);
        answer = 'C:\\synthetic\\资料';
        expect((await adapter.chooseFolder())!.path, answer);
        denied = true;
        await expectLater(
          adapter.chooseFile(),
          throwsA(isA<PlatformException>()),
        );
        await expectLater(
          adapter.open('https://example.com'),
          throwsA(isA<PlatformException>()),
        );
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      }
    },
    skip: !Platform.isWindows,
  );
}
