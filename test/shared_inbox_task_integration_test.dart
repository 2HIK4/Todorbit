import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/shared_inbox_store.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/task_resources.dart';
import 'package:life_manager/features/workspace/unified_resources_section.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late LifeRepository repository;
  late SharedInboxStore inboxStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todorbit_task_inbox_test_');
    db = AppDatabase(NativeDatabase.memory());
    repository = LifeRepository(db);
    inboxStore = SharedInboxStore(tempDir);
  });

  tearDown(() async {
    await db.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  testWidgets('From Shared Inbox button is available in draft resources section', (tester) async {
    final drafts = <DraftTaskResource>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedResourcesSection.draft(
            resources: drafts,
            onChanged: (updated) {},
            sharedInboxStore: inboxStore,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('From Shared Inbox'), findsOneWidget);
    expect(find.text('Attach copy'), findsOneWidget);
    expect(find.text('Add URL'), findsOneWidget);
  });

  testWidgets('draft task creation: attaching from Shared Inbox stages files without modifying inbox originals', (tester) async {
    final fileBytes = [10, 20, 30, 40, 50];
    final entry = inboxStore.addBytesSync(
      fileBytes,
      displayName: 'SpecDoc.pdf',
      mimeType: 'application/pdf',
    );

    var drafts = <DraftTaskResource>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return UnifiedResourcesSection.draft(
                resources: drafts,
                onChanged: (updated) => setState(() => drafts = updated),
                sharedInboxStore: inboxStore,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap From Shared Inbox
    await tester.tap(find.text('From Shared Inbox'));
    await tester.pumpAndSettle();

    // Verify dialog shows SpecDoc.pdf
    expect(find.text('Attach from Shared Inbox'), findsOneWidget);
    expect(find.text('SpecDoc.pdf'), findsOneWidget);

    // Select the file and attach
    await tester.tap(find.text('SpecDoc.pdf'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Attach (1)'));
    await tester.pumpAndSettle();

    // Dialog dismissed; draft resources list updated
    expect(drafts.length, 1);
    expect(drafts.first.label, 'SpecDoc.pdf');
    expect(drafts.first.kind, TaskResourceKind.managed);
    expect(drafts.first.target, entry.fileIn(tempDir).path);

    // Verify inbox original still exists
    expect(entry.fileIn(tempDir).existsSync(), isTrue);

    // Scenario A: User cancels task creation -> No database changes occur
    // (Simulated by simply not calling addDraftResources).
    // Database has 0 tasks and 0 task resources.
    expect((await repository.tasks()).isEmpty, isTrue);

    // Scenario B: User commits/saves task -> Creates durable TaskResource
    final task = await repository.addTask(
      TaskDraft(title: 'Review specifications'),
    );
    await tester.runAsync(() async {
      await repository.addDraftResources(task.id, drafts);
    });

    final persisted = await repository.taskResources(task.id);
    expect(persisted.length, 1);
    expect(persisted.first.label, 'SpecDoc.pdf');
    expect(persisted.first.kind, TaskResourceKind.managed);

    // Verify byte content in database matches original bytes
    final storedBytes = await repository.managedAttachmentBytes(persisted.first);
    expect(storedBytes, fileBytes);

    // Verify inbox original remains available
    final inboxEntries = inboxStore.loadSync();
    expect(inboxEntries.length, 1);
    expect(entry.fileIn(tempDir).existsSync(), isTrue);
  });

  testWidgets('persisted task: attaching from Shared Inbox creates durable copy in task_resources', (tester) async {
    final pdfBytes = [0x25, 0x50, 0x44, 0x46]; // %PDF
    final entry = inboxStore.addBytesSync(
      pdfBytes,
      displayName: 'Architecture.pdf',
      mimeType: 'application/pdf',
    );

    final task = await repository.addTask(
      TaskDraft(title: 'Design review'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedResourcesSection.persisted(
            taskId: task.id,
            repository: repository,
            sharedInboxStore: inboxStore,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap From Shared Inbox
    await tester.tap(find.text('From Shared Inbox'));
    await tester.pumpAndSettle();

    expect(find.text('Architecture.pdf'), findsOneWidget);

    // Select and attach
    await tester.tap(find.text('Architecture.pdf'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Attach (1)'));
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if ((await repository.taskResources(task.id)).isNotEmpty) break;
    }
    await tester.pumpAndSettle();

    // Verify attached resource is displayed in the persisted resources section
    expect(find.text('Architecture.pdf'), findsOneWidget);

    final attachments = await repository.taskResources(task.id);
    expect(attachments.length, 1);
    expect(attachments.first.label, 'Architecture.pdf');
    expect(attachments.first.kind, TaskResourceKind.managed);
    expect(attachments.first.sha256, entry.sha256);

    // Verify independent copy: delete inbox original, task attachment still works
    inboxStore.deleteEntrySync(entry.id);
    expect(inboxStore.loadSync().isEmpty, isTrue);

    final bytesFromDb = await repository.managedAttachmentBytes(attachments.first);
    expect(bytesFromDb, pdfBytes);
  });

  testWidgets('independent copy semantics: deleting task attachment does not delete inbox original', (tester) async {
    final bytes = [1, 2, 3, 4, 5, 6];
    final entry = inboxStore.addBytesSync(
      bytes,
      displayName: 'Guide.pdf',
    );

    final task = await repository.addTask(
      TaskDraft(title: 'Read manual'),
    );

    // Attach to task
    late final TaskResource resource;
    await tester.runAsync(() async {
      resource = await repository.attachManagedFile(
        task.id,
        entry.fileIn(tempDir),
      );
    });

    expect((await repository.taskResources(task.id)).length, 1);

    // Delete task attachment
    await repository.removeTaskResource(resource);
    expect((await repository.taskResources(task.id)).isEmpty, isTrue);

    // Verify inbox file is untouched
    final inboxEntries = inboxStore.loadSync();
    expect(inboxEntries.length, 1);
    expect(inboxEntries.first.id, entry.id);
    expect(entry.fileIn(tempDir).existsSync(), isTrue);
  });

  testWidgets('picker dialog marks already attached files to prevent duplicate attachments', (tester) async {
    final entry = inboxStore.addBytesSync(
      [1, 2, 3],
      displayName: 'Existing.pdf',
    );

    final task = await repository.addTask(
      TaskDraft(title: 'Duplicate test'),
    );

    // Attach to task directly
    await tester.runAsync(() async {
      await repository.attachManagedFile(
        task.id,
        entry.fileIn(tempDir),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedResourcesSection.persisted(
            taskId: task.id,
            repository: repository,
            sharedInboxStore: inboxStore,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap From Shared Inbox
    await tester.tap(find.text('From Shared Inbox'));
    await tester.pumpAndSettle();

    // Verify item is marked already attached
    expect(find.textContaining('Already attached'), findsOneWidget);
  });
}
