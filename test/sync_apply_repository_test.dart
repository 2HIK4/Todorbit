import 'package:life_manager/domain/task_composition.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/data/app_database.dart';
import 'package:life_manager/data/backup_service.dart';
import 'package:life_manager/data/cloud/cloud_storage_provider.dart';
import 'package:life_manager/data/cloud/sync_batch_codec.dart';
import 'package:life_manager/data/life_repository.dart';
import 'package:life_manager/data/sync_exchange_models.dart';
import 'package:life_manager/domain/models.dart';
import 'package:life_manager/domain/recurrence.dart';
import 'package:life_manager/domain/task_resources.dart';

class _BeforeApplyDatabase extends AppDatabase {
  _BeforeApplyDatabase(super.executor);
  Future<void> Function()? beforeTransaction;
  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    final checkpoint = beforeTransaction;
    beforeTransaction = null;
    if (checkpoint != null) await checkpoint();
    return super.transaction(action, requireNew: requireNew);
  }
}

void main() {
  const a = SyncBinding(
    workspace: '8b41595f-3258-40e7-8499-856772bf5fb8',
    account: 'mocked-apply-only',
    device: 'df0293d3-c369-4db8-a998-0ae0b076397d',
  );
  const b = SyncBinding(
    workspace: '8b41595f-3258-40e7-8499-856772bf5fb8',
    account: 'mocked-apply-only',
    device: 'b870f5ae-b161-4241-bd65-63b9553d9de3',
  );
  late Directory root;
  late AppDatabase left, right;
  late LifeRepository sender, receiver;
  late SyncWorkspaceKey key;
  SyncLease? leftLease, rightLease;
  CloudObject remote(PendingSyncBatch batch) => CloudObject(
    id: batch.id,
    accountId: a.account,
    name: 'opaque.tdsync',
    bytes: batch.bytes.length,
    createdAt: DateTime.now().toUtc(),
    md5: crypto.md5.convert(batch.bytes).toString(),
    properties: {
      ...batch.properties,
      'application': 'todorbit-sync',
      'verified': 'true',
    },
  );
  Future<List<PendingSyncBatch>> exchange({bool reverse = false}) async {
    final from = reverse ? receiver : sender, to = reverse ? sender : receiver;
    final fromBinding = reverse ? b : a, toBinding = reverse ? a : b;
    final fromLease = reverse ? rightLease : leftLease,
        toLease = reverse ? leftLease : rightLease;
    final batches = <PendingSyncBatch>[];
    while (true) {
      final batch = await from.prepareNextSyncBatch(
        fromBinding,
        key,
        lease: fromLease,
      );
      if (batch == null) break;
      await to.retainIncomingSyncBatch(
        toBinding,
        key,
        remote(batch),
        batch.bytes,
        lease: toLease,
      );
      await from.acknowledgeSyncBatch(batch, remote(batch), lease: fromLease);
      batches.add(batch);
    }
    return batches;
  }

  Future<SyncApplyResult> apply({bool reverse = false}) async {
    if (reverse) {
      leftLease ??= await sender.acquireSyncLease(a);
      return sender.applyNextSyncGroup(a, lease: leftLease!);
    }
    rightLease ??= await receiver.acquireSyncLease(b);
    return receiver.applyNextSyncGroup(b, lease: rightLease!);
  }

  Future<void> seed() async {
    await exchange();
    final result = await apply();
    expect(result.state, SyncApplyState.applied, reason: result.reason);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('todorbit-sync-apply-');
    final leftFile = File('${root.path}/left.sqlite'),
        rightFile = File('${root.path}/right.sqlite');
    left = AppDatabase(NativeDatabase(leftFile));
    right = _BeforeApplyDatabase(NativeDatabase(rightFile));
    sender = LifeRepository(left);
    receiver = LifeRepository(right, taskClock: () => DateTime.utc(2050));
    key = SyncWorkspaceKey.generate();
    leftLease = null;
    rightLease = null;
    await sender.addTask(const TaskDraft(title: 'Original synthetic task'));
    await sender.activateSyncCapture(
      workspaceId: a.workspace,
      accountId: a.account,
      deviceId: a.device,
      recovery: BackupService(leftFile),
    );
    await receiver.activateSyncCapture(
      workspaceId: b.workspace,
      accountId: b.account,
      deviceId: b.device,
      recovery: BackupService(rightFile),
    );
  });
  tearDown(() async {
    await left.close();
    await right.close();
    await root.delete(recursive: true);
  });

  for (final standard in [true, false]) {
    test(
      'event project and named checklist exchange is idempotent (${standard ? 'Standard' : 'Private'})',
      () async {
        if (standard) key = SyncWorkspaceKey.standard();
        final category = await sender.addCategory('University');
        final project = await sender.addProject(category.id, 'Course');
        final event = await sender.addEvent(
          EventDraft(
            title: 'Lecture',
            startsAt: DateTime(2026, 11, 5, 9),
            endsAt: DateTime(2026, 11, 5, 10),
            categoryId: category.id,
            projectId: project.id,
          ),
        );
        final task = await sender.addTaskWithComposition(
          const TaskDraft(title: 'Prepare'),
          const [],
          const [],
          groups: [
            DraftChecklistGroup('Packing', ['Book', 'Pen']),
          ],
        );
        final batches = await exchange();
        while ((await apply()).state == SyncApplyState.applied) {}
        expect((await receiver.events()).single.projectId, project.id);
        expect((await receiver.checklistGroups()).single.taskId, task.id);
        expect((await receiver.checklistItems()).map((i) => i.title), [
          'Book',
          'Pen',
        ]);
        for (final batch in batches) {
          expect(
            await receiver.retainIncomingSyncBatch(
              b,
              key,
              remote(batch),
              batch.bytes,
              lease: rightLease,
            ),
            0,
          );
        }
        expect((await receiver.events()).single.id, event.id);
        expect(await receiver.checklistGroups(), hasLength(1));
        await sender.deleteEvent(event.id);
        await exchange();
        while ((await apply()).state == SyncApplyState.applied) {}
        expect(await receiver.events(), isEmpty);
      },
    );
  }

  for (final standard in [true, false]) {
    test(
      'schema 26 event and checklist facts apply unchanged and replay safely ($standard)',
      () async {
        if (standard) key = SyncWorkspaceKey.standard();
        final event = await sender.addEvent(
          EventDraft(
            title: 'Legacy event',
            startsAt: DateTime(2026, 11, 5, 9),
            endsAt: DateTime(2026, 11, 5, 10),
          ),
        );
        final task = (await sender.tasks()).single;
        await sender.addChecklistItem(task.id, 'Legacy checklist item');
        final codec = SyncBatchCodec();
        var received = <PendingSyncBatch>[];
        while (true) {
          final original = await sender.prepareNextSyncBatch(a, key);
          if (original == null) break;
          final decoded = (await codec.decrypt(
            original.bytes,
            key,
            workspace: a.workspace,
            account: a.account,
            expectedSchema: AppDatabase.currentSchemaVersion,
          )).toJson();
          decoded['schema'] = 26;
          for (final operation in decoded['operations'] as List) {
            final entity = operation['entity'];
            final revision = operation['revision'] as Map;
            final originalValue = revision['value'];
            if (originalValue is Map) {
              final value = Map<String, Object?>.from(originalValue);
              revision['value'] = value;
              if (entity == 'fixed_events') value.remove('project_id');
              if (entity == 'task_checklist') value.remove('group_id');
            }
          }
          final bytes = await codec.encrypt(
            SyncBatch.fromJson(decoded),
            key,
            workspace: a.workspace,
            account: a.account,
          );
          final legacy = PendingSyncBatch(
            id: original.id,
            binding: a,
            bytes: bytes,
            sha256: crypto.sha256.convert(bytes).toString(),
          );
          await receiver.retainIncomingSyncBatch(
            b,
            key,
            remote(legacy),
            legacy.bytes,
          );
          await sender.acknowledgeSyncBatch(original, remote(original));
          received.add(legacy);
        }
        while ((await apply()).state == SyncApplyState.applied) {}
        expect((await receiver.events()).single.id, event.id);
        expect((await receiver.events()).single.projectId, isNull);
        expect((await receiver.checklistItems()).single.groupId, isNull);
        for (final batch in received) {
          expect(
            await receiver.retainIncomingSyncBatch(
              b,
              key,
              remote(batch),
              batch.bytes,
              lease: rightLease,
            ),
            0,
          );
        }
        expect((await apply()).state, SyncApplyState.idle);
      },
    );
  }

  test(
    'authenticated bootstrap applies once without creating a sync echo',
    () async {
      final batches = await exchange();
      final result = await apply();
      expect(result.state, SyncApplyState.applied, reason: result.reason);
      expect(
        (await receiver.tasks()).single.id,
        (await sender.tasks()).single.id,
      );
      expect((await receiver.tasks()).single.title, 'Original synthetic task');
      expect(
        await receiver.pendingSyncChanges(
          workspaceId: b.workspace,
          accountId: b.account,
        ),
        isEmpty,
      );
      expect(
        await receiver.retainIncomingSyncBatch(
          b,
          key,
          remote(batches.single),
          batches.single.bytes,
          lease: rightLease,
        ),
        0,
      );
      expect((await apply()).state, SyncApplyState.idle);
      final context = await right
          .customSelect('SELECT * FROM sync_capture_context')
          .getSingle();
      expect(context.read<int>('applying_remote'), 0);
      expect(context.readNullable<String>('last_success_utc'), isNull);
      expect(jsonDecode(context.read<String>('visible_json'))[a.device], [
        [1, 1],
      ]);
      expect(
        await right
            .customSelect(
              "SELECT name FROM sqlite_schema WHERE type='trigger' AND name NOT GLOB 'sync_*'",
            )
            .get(),
        hasLength(7),
      );
    },
  );

  test('independent fields converge and remote apply invalidates a stale editor CAS', () async {
    await seed();
    await receiver.updateTask(
      (await receiver.tasks()).single,
      const TaskDraft(
        title: 'Original synthetic task',
        notes: 'Offline B notes',
      ),
    );
    final stale = (await receiver.tasks()).single;
    await sender.updateTask(
      (await sender.tasks()).single,
      const TaskDraft(title: 'A title'),
    );
    await exchange();
    final result = await apply();
    expect(result.state, SyncApplyState.applied, reason: result.reason);
    final merged = (await receiver.tasks()).single;
    expect(merged.title, 'A title');
    expect(merged.notes, 'Offline B notes');
    expect(merged.updatedAt.isAfter(stale.updatedAt), isTrue);
    await expectLater(
      receiver.updateTask(stale, const TaskDraft(title: 'Stale overwrite')),
      throwsStateError,
    );
    final heads = jsonDecode(
      (await right
              .customSelect(
                "SELECT visible_heads_json FROM sync_entity_heads WHERE entity='tasks'",
              )
              .getSingle())
          .read<String>('visible_heads_json'),
    ) as List;
    expect(heads, hasLength(2));
    await receiver.updateTask(
      merged,
      const TaskDraft(title: 'A title', notes: 'Offline B notes', priority: 2),
    );
    final batches = await exchange(reverse: true);
    final clear = await SyncBatchCodec().decrypt(
      batches.single.bytes,
      key,
      workspace: b.workspace,
      account: b.account,
      expectedSchema: AppDatabase.currentSchemaVersion,
    );
    expect(clear.operations.last.revision.parents, heads.toSet());
    expect((await apply(reverse: true)).state, SyncApplyState.applied);
    expect((await apply(reverse: true)).state, SyncApplyState.applied);
    final converged = (await sender.tasks()).single;
    expect(converged.title, merged.title);
    expect(converged.notes, merged.notes);
    expect(converged.priority, 2);
    expect(
      await sender.pendingSyncChanges(
        workspaceId: a.workspace,
        accountId: a.account,
      ),
      isEmpty,
    );
  });

  test('portable preference keys merge independently and private policy keys are rejected', () async {
    await seed();
    await sender.savePortablePreference('firstWeekday', 1);
    await receiver.savePortablePreference('theme', 'dark');
    await exchange();
    expect((await apply()).state, SyncApplyState.applied);
    expect(await receiver.portablePreferences(), {
      'firstWeekday': 1,
      'theme': 'dark',
    });
    await exchange(reverse: true);
    expect((await apply(reverse: true)).state, SyncApplyState.applied);
    expect(await sender.portablePreferences(), {
      'firstWeekday': 1,
      'theme': 'dark',
    });
    await expectLater(
      receiver.savePortablePreference('oauthTokens', {'secret': 'synthetic'}),
      throwsFormatException,
    );
    expect(
      (await receiver.portablePreferences()).containsKey('oauthTokens'),
      isFalse,
    );
  });

  test('an imported running timer cannot be heartbeated or closed by another device', () async {
    await seed();
    final task = (await sender.tasks()).single;
    final run = await sender.startTimer(task.id);
    await exchange();
    final result = await apply();
    expect(result.state, SyncApplyState.applied, reason: result.reason);
    final remote = (await receiver.activeTimerRun())!;
    expect(remote.ownerDeviceId, a.device);
    expect(remote.canControl, isFalse);
    await expectLater(receiver.heartbeatTimer(remote), throwsStateError);
    await expectLater(receiver.stopTimer(remote), throwsStateError);
    expect((await receiver.timeEntries()).single.endsAt, isNull);
    await sender.pauseTimer(run);
    await exchange();
    expect((await apply()).state, SyncApplyState.applied);
    expect((await receiver.timeEntries()).single.endsAt, isNotNull);
  });

  test('same-field conflict retains both branches while an independent group applies', () async {
    await seed();
    await receiver.updateTask(
      (await receiver.tasks()).single,
      const TaskDraft(title: 'B title'),
    );
    await sender.updateTask(
      (await sender.tasks()).single,
      const TaskDraft(title: 'A title'),
    );
    await exchange();
    final conflict = await apply();
    expect(conflict.state, SyncApplyState.needsReview);
    expect(conflict.reason, 'recordConflict');
    expect((await receiver.tasks()).single.title, 'B title');
    await sender.addTask(const TaskDraft(title: 'Independent A task'));
    await exchange();
    final independent = await apply();
    expect(
      independent.state,
      SyncApplyState.applied,
      reason: independent.reason,
    );
    expect((await receiver.tasks()).map((task) => task.title).toSet(), {
      'B title',
      'Independent A task',
    });
    final context = await right
        .customSelect('SELECT visible_json FROM sync_capture_context')
        .getSingle();
    expect(jsonDecode(context.read<String>('visible_json'))[a.device], [
      [1, 1],
      [3, 3],
    ]);
    expect(
      await receiver.pendingSyncChanges(
        workspaceId: b.workspace,
        accountId: b.account,
      ),
      hasLength(1),
    );
  });

  test(
    'managed byte history is applied exactly after metadata review',
    () async {
      final task = (await sender.tasks()).single;
      final file = File('${root.path}/synthetic.bin')
        ..writeAsBytesSync([0, 255, 4]);
      await sender.attachManagedFile(task.id, file);
      await exchange();
      expect((await apply()).state, SyncApplyState.applied);
      final result = await apply();
      expect(result.state, SyncApplyState.applied, reason: result.reason);
      final resource = (await receiver.taskResources(task.id)).single;
      expect(await receiver.managedAttachmentBytes(resource), [0, 255, 4]);
      expect(
        await receiver.pendingSyncChanges(
          workspaceId: b.workspace,
          accountId: b.account,
        ),
        isEmpty,
      );
    },
  );

  test('recurrence completion applies original rows without generating another occurrence', () async {
    final first = await sender.addRecurringTask(
      const TaskDraft(
        title: 'Synthetic recurrence',
        scheduledDate: '2026-11-01',
      ),
      RecurrenceRule(
        kind: RecurrenceKind.afterCompletion,
        startDate: '2026-11-01',
        interval: 3,
        maxOccurrences: 2,
      ),
    );
    await exchange();
    expect((await apply()).state, SyncApplyState.applied);
    final initial = await apply();
    expect(initial.state, SyncApplyState.applied, reason: initial.reason);
    await sender.setComplete(first, true);
    await exchange();
    final result = await apply();
    expect(result.state, SyncApplyState.applied, reason: result.reason);
    expect(
      (await receiver.tasks()).map((task) => task.id).toSet(),
      (await sender.tasks()).map((task) => task.id).toSet(),
    );
    expect(
      await right.customSelect('SELECT * FROM recurrence_occurrences').get(),
      hasLength(2),
    );
    expect(
      await receiver.pendingSyncChanges(
        workspaceId: b.workspace,
        accountId: b.account,
      ),
      isEmpty,
    );
    expect((await apply()).state, SyncApplyState.idle);
  });

  test(
    'concurrent parent deletion preserves the locally edited child',
    () async {
      final category = await sender.addCategory('Synthetic category');
      await sender.updateTask(
        (await sender.tasks()).single,
        TaskDraft(title: 'Original synthetic task', categoryId: category.id),
      );
      await exchange();
      for (var i = 0; i < 3; i++) {
        expect((await apply()).state, SyncApplyState.applied);
      }
      await receiver.updateTask(
        (await receiver.tasks()).single,
        TaskDraft(
          title: 'Original synthetic task',
          categoryId: category.id,
          notes: 'Retain child edit',
        ),
      );
      await sender.deleteCategory(category.id);
      await exchange();
      final result = await apply();
      expect(result.state, SyncApplyState.needsReview);
      expect(result.reason, 'relatedDeletion');
      expect((await receiver.tasks()).single.notes, 'Retain child edit');
      expect((await receiver.categories()).single.id, category.id);
      final review = (await receiver.reviewSyncConflicts(
        b,
        lease: rightLease!,
      ))!;
      final child = review.records.singleWhere((r) => r.entity == 'tasks');
      expect(child.consequence, isTrue);
      final cloudChoices = {
        for (final record in review.records)
          record.id: SyncResolutionChoice.revision(record.remoteHeads.single),
      };
      final mixed = await receiver.resolveSyncConflicts(
        b,
        lease: rightLease!,
        reviewedToken: review.token,
        choices: {
          ...cloudChoices,
          child.id: const SyncResolutionChoice.local(),
        },
      );
      expect(mixed.state, SyncApplyState.needsReview);
      expect((await receiver.categories()).single.id, category.id);
      expect((await receiver.tasks()).single.notes, 'Retain child edit');
      final refreshed = (await receiver.reviewSyncConflicts(
        b,
        lease: rightLease!,
      ))!;
      final resolved = await receiver.resolveSyncConflicts(
        b,
        lease: rightLease!,
        reviewedToken: refreshed.token,
        choices: {
          for (final record in refreshed.records)
            record.id: SyncResolutionChoice.revision(record.remoteHeads.single),
        },
      );
      expect(resolved.state, SyncApplyState.applied, reason: resolved.reason);
      expect((await receiver.categories()), isEmpty);
      expect(
        (await right.customSelect('SELECT notes FROM tasks').getSingle())
            .read<String>('notes'),
        'Retain child edit',
      );
    },
  );

  test('purging a task must explicitly review its new managed attachment before cascading it', () async {
    await seed();
    final task = (await receiver.tasks()).single;
    final file = File('${root.path}/new-managed.bin')
      ..writeAsBytesSync([10, 20, 30]);
    await receiver.attachManagedFile(task.id, file);
    final resource = (await receiver.taskResources(task.id)).single;
    await left.customStatement('DELETE FROM tasks WHERE id=?', [task.id]);
    await exchange();
    expect((await apply()).state, SyncApplyState.needsReview);
    final review = (await receiver.reviewSyncConflicts(b, lease: rightLease!))!;
    final dependent = review.records.singleWhere(
      (r) => r.entity == 'task_resources',
    );
    expect(dependent.consequence, isTrue);
    expect(dependent.candidates[dependent.remoteHeads.single], isNull);
    final mixed = {
      for (final record in review.records)
        record.id: SyncResolutionChoice.revision(record.remoteHeads.single),
    };
    mixed[dependent.id] = const SyncResolutionChoice.local();
    expect(
      (await receiver.resolveSyncConflicts(
        b,
        lease: rightLease!,
        reviewedToken: review.token,
        choices: mixed,
      )).state,
      SyncApplyState.needsReview,
    );
    expect(await receiver.managedAttachmentBytes(resource), [10, 20, 30]);
    final refreshed = (await receiver.reviewSyncConflicts(
      b,
      lease: rightLease!,
    ))!;
    final result = await receiver.resolveSyncConflicts(
      b,
      lease: rightLease!,
      reviewedToken: refreshed.token,
      choices: {
        for (final record in refreshed.records)
          record.id: SyncResolutionChoice.revision(record.remoteHeads.single),
      },
    );
    expect(result.state, SyncApplyState.applied, reason: result.reason);
    expect(await receiver.tasks(), isEmpty);
    expect(await receiver.taskResources(task.id), isEmpty);
  });

  test(
    'timer ownership transfer pauses only at the confirmed checkpoint',
    () async {
      await seed();
      final task = (await sender.tasks()).single;
      final original = await sender.startTimer(task.id);
      await exchange();
      expect((await apply()).state, SyncApplyState.applied);
      final imported = (await receiver.activeTimerRun())!;
      await receiver.adoptTimerAtCheckpoint(imported);
      final adopted = (await receiver.activeTimerRun())!;
      expect(adopted.canControl, isTrue);
      expect(adopted.ownerDeviceId, b.device);
      expect((await receiver.timeEntries()).single.endsAt, original.lastSeenAt);
      expect(adopted.state.name, 'paused');
      await receiver.resumeTimer(adopted);
      expect(await receiver.timeEntries(), hasLength(2));
      expect(
        (await receiver.timeEntries()).where((e) => e.endsAt == null),
        hasLength(1),
      );
    },
  );

  test(
    'uniqueness failure rolls back the original group and retains its facts',
    () async {
      await seed();
      await receiver.addCategory('Duplicate category');
      await left.transaction(() async {
        await sender.addCategory('Unique source category');
        await sender.addCategory('Duplicate category');
        await sender.addTask(
          const TaskDraft(title: 'Must not partially appear'),
        );
      });
      await exchange();
      final result = await apply();
      expect(result.state, SyncApplyState.needsReview);
      expect(result.reason, 'recordConstraint');
      expect((await receiver.categories()).map((c) => c.name), [
        'Duplicate category',
      ]);
      expect((await receiver.tasks()).map((task) => task.title), [
        'Original synthetic task',
      ]);
      expect(
        (await right
                .customSelect(
                  'SELECT applying_remote FROM sync_capture_context',
                )
                .getSingle())
            .read<int>('applying_remote'),
        0,
      );
      expect(
        await right
            .customSelect(
              "SELECT name FROM sqlite_schema WHERE type='trigger' AND name NOT GLOB 'sync_*'",
            )
            .get(),
        hasLength(7),
      );
      expect(
        await right.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
  test(
    'concurrent dependency edges cannot commit a cycle or a partial revision',
    () async {
      final second = await sender.addTask(
        const TaskDraft(title: 'Second synthetic task'),
      );
      await exchange();
      expect((await apply()).state, SyncApplyState.applied);
      expect((await apply()).state, SyncApplyState.applied);
      final first = (await receiver.tasks()).singleWhere(
        (task) => task.id != second.id,
      );
      await receiver.setPrerequisites(first, {second.id});
      final secondBefore = (await receiver.tasks()).singleWhere(
        (task) => task.id == second.id,
      );
      await sender.setPrerequisites(
        (await sender.tasks()).singleWhere((task) => task.id == second.id),
        {first.id},
      );
      await exchange();
      final result = await apply();
      expect(result.state, SyncApplyState.needsReview);
      expect(result.reason, 'dependencyCycle');
      final edges = await right
          .customSelect('SELECT task_id,prerequisite_id FROM task_dependencies')
          .get();
      expect(edges, hasLength(1));
      expect(edges.single.read<String>('task_id'), first.id);
      expect(
        (await receiver.tasks())
            .singleWhere((task) => task.id == second.id)
            .updatedAt,
        secondBefore.updatedAt,
      );
    },
  );

  test(
    'remote dependency-only edits advance the task editor concurrency token',
    () async {
      final second = await sender.addTask(
        const TaskDraft(title: 'Prerequisite'),
      );
      await exchange();
      expect((await apply()).state, SyncApplyState.applied);
      expect((await apply()).state, SyncApplyState.applied);
      final original = (await receiver.tasks()).singleWhere(
        (task) => task.id != second.id,
      );
      await receiver.updateTask(
        original,
        const TaskDraft(
          title: 'Original synthetic task',
          notes: 'B notes with future metadata',
        ),
      );
      final stale = (await receiver.tasks()).singleWhere(
        (task) => task.id == original.id,
      );
      await sender.setPrerequisites(
        (await sender.tasks()).singleWhere((task) => task.id == original.id),
        {second.id},
      );
      await exchange();
      final result = await apply();
      expect(result.state, SyncApplyState.applied, reason: result.reason);
      expect(
        (await receiver.tasks())
            .singleWhere((task) => task.id == original.id)
            .updatedAt
            .isAfter(stale.updatedAt),
        isTrue,
      );
      await expectLater(receiver.setPrerequisites(stale, {}), throwsStateError);
      expect(
        await right.customSelect('SELECT * FROM task_dependencies').get(),
        hasLength(1),
      );
    },
  );

  test(
    'concurrent recurrence rule change cannot rewrite a completed branch',
    () async {
      final recurring = await sender.addRecurringTask(
        const TaskDraft(title: 'Rule conflict', scheduledDate: '2026-11-01'),
        RecurrenceRule(
          kind: RecurrenceKind.afterCompletion,
          startDate: '2026-11-01',
          interval: 3,
          maxOccurrences: 2,
        ),
      );
      await exchange();
      expect((await apply()).state, SyncApplyState.applied);
      expect((await apply()).state, SyncApplyState.applied);
      await receiver.setComplete(
        (await receiver.tasks()).singleWhere((task) => task.id == recurring.id),
        true,
      );
      await left.customStatement(
        'UPDATE recurrence_series SET interval=4,updated_at=? WHERE id=?',
        [
          DateTime.now().toUtc().toIso8601String(),
          recurring.recurrenceSeriesId,
        ],
      );
      await exchange();
      final result = await apply();
      expect(result.state, SyncApplyState.needsReview);
      expect(result.reason, 'relatedRecurrence');
      expect(
        (await right
                .customSelect('SELECT interval FROM recurrence_series')
                .getSingle())
            .read<int>('interval'),
        3,
      );
      expect(
        await right.customSelect('SELECT * FROM recurrence_occurrences').get(),
        hasLength(2),
      );
      expect(
        (await receiver.tasks())
            .singleWhere((task) => task.id == recurring.id)
            .status,
        TaskStatus.completed,
      );
    },
  );

  test(
    'remote purge retains this device external resource and its actual file',
    () async {
      await seed();
      final task = (await receiver.tasks()).single;
      final local = File('${root.path}/local-only.txt')
        ..writeAsStringSync('Synthetic local-only content');
      final retained = await receiver.addExternalResource(
        task.id,
        TaskResourceKind.externalFile,
        local.path,
      );
      expect(
        await receiver.pendingSyncChanges(
          workspaceId: b.workspace,
          accountId: b.account,
        ),
        isEmpty,
      );
      await left.customStatement('DELETE FROM tasks WHERE id=?', [task.id]);
      await exchange();
      final result = await apply();
      expect(result.state, SyncApplyState.needsReview);
      expect(result.reason, 'deviceLocalResources');
      expect((await receiver.tasks()).single.id, task.id);
      expect(
        (await receiver.taskResources(task.id)).single.target,
        retained.target,
      );
      expect(await local.readAsString(), 'Synthetic local-only content');
    },
  );

  test(
    'an excluded local record is never overwritten as an empty sync slot',
    () async {
      await seed();
      final task = (await sender.tasks()).single;
      final copied = File('${root.path}/managed.bin')
        ..writeAsBytesSync([1, 2, 3]);
      final incoming = await sender.attachManagedFile(task.id, copied);
      final local = File('${root.path}/local-only.txt')
        ..writeAsStringSync('Private synthetic reference');
      final retained = await receiver.addExternalResource(
        task.id,
        TaskResourceKind.externalFile,
        local.path,
      );
      // A synthetic identity collision represents legacy/cloned data. This row
      // intentionally remains excluded from the portable journal.
      await right.customStatement('UPDATE task_resources SET id=? WHERE id=?', [
        incoming.id,
        retained.id,
      ]);
      await exchange();
      final result = await apply();
      expect(result.state, SyncApplyState.needsReview);
      expect(result.reason, 'unverifiedLocalState');
      expect(
        (await receiver.taskResources(task.id)).single.kind,
        TaskResourceKind.externalFile,
      );
      expect(
        (await receiver.taskResources(task.id)).single.target,
        retained.target,
      );
      expect(await local.readAsString(), 'Private synthetic reference');
    },
  );
  test(
    'a local portable edit between review and lock forces a fresh review',
    () async {
      await seed();
      await sender.updateTask(
        (await sender.tasks()).single,
        const TaskDraft(title: 'A title'),
      );
      await exchange();
      (right as _BeforeApplyDatabase).beforeTransaction = () async {
        await receiver.updateTask(
          (await receiver.tasks()).single,
          const TaskDraft(
            title: 'Original synthetic task',
            notes: 'Saved during review',
          ),
        );
      };
      expect((await apply()).state, SyncApplyState.retry);
      expect((await receiver.tasks()).single.notes, 'Saved during review');
      final result = await apply();
      expect(result.state, SyncApplyState.applied, reason: result.reason);
      expect((await receiver.tasks()).single.title, 'A title');
      expect((await receiver.tasks()).single.notes, 'Saved during review');
    },
  );

  test('reviewed resolution preserves independent fields and converges without echo', () async {
    await seed();
    await receiver.updateTask(
      (await receiver.tasks()).single,
      const TaskDraft(title: 'B title', notes: 'B independent notes'),
    );
    await sender.updateTask(
      (await sender.tasks()).single,
      const TaskDraft(title: 'A title', priority: 2),
    );
    await exchange();
    expect((await apply()).state, SyncApplyState.needsReview);
    final review = (await receiver.reviewSyncConflicts(b, lease: rightLease!))!;
    final record = review.records.single;
    final selected = record.candidates.entries
        .singleWhere((entry) => entry.value?['title'] == 'A title')
        .key;
    final result = await receiver.resolveSyncConflicts(
      b,
      lease: rightLease!,
      reviewedToken: review.token,
      choices: {record.id: SyncResolutionChoice.revision(selected)},
    );
    expect(result.state, SyncApplyState.applied, reason: result.reason);
    expect((await receiver.tasks()).single.title, 'A title');
    expect((await receiver.tasks()).single.notes, 'B independent notes');
    expect((await receiver.tasks()).single.priority, 2);
    await exchange(reverse: true);
    var applied = await apply(reverse: true);
    if (applied.state == SyncApplyState.needsReview) {
      // The retained original branch may be encountered before the resolution
      // which causally supersedes it. The drain must continue past that barrier.
      applied = await apply(reverse: true);
    }
    expect(applied.state, SyncApplyState.applied, reason: applied.reason);
    expect((await sender.tasks()).single.notes, 'B independent notes');
    expect((await sender.tasks()).single.title, 'A title');
    expect((await apply(reverse: true)).state, SyncApplyState.idle);
  });

  test('keeping unchanged local bytes emits a durable resolution after every reviewed head', () async {
    await seed();
    await receiver.updateTask(
      (await receiver.tasks()).single,
      const TaskDraft(title: 'B title'),
    );
    await sender.updateTask(
      (await sender.tasks()).single,
      const TaskDraft(title: 'A title'),
    );
    await exchange();
    await apply();
    final review = (await receiver.reviewSyncConflicts(b, lease: rightLease!))!;
    final result = await receiver.resolveSyncConflicts(
      b,
      lease: rightLease!,
      reviewedToken: review.token,
      choices: {review.records.single.id: const SyncResolutionChoice.local()},
    );
    expect(result.state, SyncApplyState.applied, reason: result.reason);
    await exchange(reverse: true);
    var applied = await apply(reverse: true);
    if (applied.state == SyncApplyState.needsReview) {
      applied = await apply(reverse: true);
    }
    expect(applied.state, SyncApplyState.applied, reason: applied.reason);
    expect((await sender.tasks()).single.title, 'B title');
    expect(await receiver.reviewSyncConflicts(b, lease: rightLease!), isNull);
  });

  test(
    'Resolve Later survives another apply attempt and unrelated edits',
    () async {
      await seed();
      await receiver.updateTask(
        (await receiver.tasks()).single,
        const TaskDraft(title: 'B title'),
      );
      await sender.updateTask(
        (await sender.tasks()).single,
        const TaskDraft(title: 'A title'),
      );
      await exchange();
      await apply();
      final review = (await receiver.reviewSyncConflicts(
        b,
        lease: rightLease!,
      ))!;
      await receiver.dismissSyncConflicts(b, review, lease: rightLease!);
      await receiver.addTask(
        const TaskDraft(title: 'Unrelated synthetic edit'),
      );
      await apply();
      final refreshed = (await receiver.reviewSyncConflicts(
        b,
        lease: rightLease!,
      ))!;
      expect(refreshed.dismissed, isTrue);
      expect(refreshed.attentionToken, review.attentionToken);
      expect((await receiver.tasks()).map((t) => t.title), contains('B title'));
    },
  );

  test('a newly received revision invalidates an open decision without changing data', () async {
    await seed();
    await receiver.updateTask(
      (await receiver.tasks()).single,
      const TaskDraft(title: 'B title'),
    );
    await sender.updateTask(
      (await sender.tasks()).single,
      const TaskDraft(title: 'A title'),
    );
    await exchange();
    await apply();
    final review = (await receiver.reviewSyncConflicts(b, lease: rightLease!))!;
    await sender.updateTask(
      (await sender.tasks()).single,
      const TaskDraft(title: 'A later title'),
    );
    await exchange();
    final result = await receiver.resolveSyncConflicts(
      b,
      lease: rightLease!,
      reviewedToken: review.token,
      choices: {review.records.single.id: const SyncResolutionChoice.local()},
    );
    expect(result.state, SyncApplyState.retry);
    expect(result.reason, 'staleDecision');
    expect((await receiver.tasks()).single.title, 'B title');
  });

  test(
    'a newly added excluded reference is rechecked under the writer lock',
    () async {
      await seed();
      final task = (await receiver.tasks()).single;
      final local = File('${root.path}/late-reference.txt')
        ..writeAsStringSync('Synthetic reference created during review');
      await left.customStatement('DELETE FROM tasks WHERE id=?', [task.id]);
      await exchange();
      (right as _BeforeApplyDatabase).beforeTransaction = () async {
        await receiver.addExternalResource(
          task.id,
          TaskResourceKind.externalFile,
          local.path,
        );
      };
      final result = await apply();
      expect(result.state, SyncApplyState.needsReview);
      expect(result.reason, 'deviceLocalResources');
      expect((await receiver.tasks()).single.id, task.id);
      expect(await receiver.taskResources(task.id), hasLength(1));
      expect(
        await local.readAsString(),
        'Synthetic reference created during review',
      );
      expect(
        (await right
                .customSelect(
                  'SELECT device_sequence FROM sync_capture_context',
                )
                .getSingle())
            .read<int>('device_sequence'),
        0,
      );
    },
  );
}
