import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/domain/sync/portable_record_merge.dart';

void main() {
  SyncRevision base(Map<String, Object?> value) => SyncRevision(
    id: 'base',
    device: 'initial',
    sequence: 1,
    parents: [],
    value: {...value, 'updated_at': '2026-01-01T00:00:00Z'},
  );
  SyncRevision branch(String device, Map<String, Object?> value) =>
      SyncRevision(
        id: device,
        device: device,
        sequence: 1,
        parents: ['base'],
        value: value,
      );
  test(
    'different portable fields merge despite different modification clocks',
    () {
      final original = base({
        'title': 'Original',
        'notes': 'Before',
        'status': 'notStarted',
        'scheduled_date': null,
        'completed_at': null,
        'remaining_work_minutes': 10,
      });
      final left = branch('left', {
        ...original.value!,
        'title': 'New title',
        'updated_at': '2036-01-01T00:00:00Z',
      });
      final right = branch('right', {
        ...original.value!,
        'notes': 'New notes',
        'updated_at': '2026-02-01T00:00:00Z',
      });
      final review = reviewPortableRecord('tasks', [right, original, left]);
      expect(review.needsDecision, isFalse);
      expect(review.heads, {'left', 'right'});
      expect(review.merged!['title'], 'New title');
      expect(review.merged!['notes'], 'New notes');
      expect(review.merged!['updated_at'], '2036-01-01T00:00:00.000Z');
    },
  );
  test('clock skew never chooses a divergent user value', () {
    final original = base({'title': 'Original'});
    final left = branch('left', {
      ...original.value!,
      'title': 'Left',
      'updated_at': '2036-01-01T00:00:00Z',
    });
    final right = branch('right', {
      ...original.value!,
      'title': 'Right',
      'updated_at': '2025-01-01T00:00:00Z',
    });
    final review = reviewPortableRecord('tasks', [original, left, right]);
    expect(review.needsDecision, isTrue);
    expect(review.conflicts.map((c) => c.field), ['title']);
    expect(review.merged!.containsKey('title'), isFalse);
  });
  test(
    'completion versus planned-date edit stays a meaningful coupled conflict',
    () {
      final original = base({
        'status': 'notStarted',
        'scheduled_date': '2026-01-01',
        'completed_at': null,
        'title': 'Task',
      });
      final complete = branch('left', {
        ...original.value!,
        'status': 'completed',
        'completed_at': '2026-01-03T00:00:00Z',
      });
      final move = branch('right', {
        ...original.value!,
        'scheduled_date': '2026-01-05',
      });
      final review = reviewPortableRecord('tasks', [original, complete, move]);
      expect(review.needsDecision, isTrue);
      expect(review.conflicts.map((c) => c.field).toSet(), {
        'status',
        'completed_at',
        'scheduled_date',
      });
      expect(
        review.conflicts.map((c) => c.field),
        isNot(contains('remaining_work_minutes')),
      );
    },
  );
  test(
    'managed resource payload cannot be assembled from incompatible branches',
    () {
      final original = base({
        'kind': 'managed',
        'content': 'original',
        'sha256': 'old',
        'byte_size': 1,
        'original_name': 'original.bin',
        'target': null,
      });
      final replace = branch('left', {
        ...original.value!,
        'content': 'new',
        'sha256': 'new',
      });
      final rename = branch('right', {
        ...original.value!,
        'original_name': 'renamed.bin',
      });
      expect(
        reviewPortableRecord('task_resources', [
          original,
          replace,
          rename,
        ]).needsDecision,
        isTrue,
      );
    },
  );
  test('deletion versus edit retains the complete competing user records', () {
    final original = base({'title': 'Original'});
    final deleted = SyncRevision(
      id: 'left',
      device: 'left',
      sequence: 1,
      parents: ['base'],
      value: null,
    );
    final edit = branch('right', {...original.value!, 'title': 'Edited'});
    final review = reviewPortableRecord('tasks', [original, deleted, edit]);
    expect(review.needsDecision, isTrue);
    expect(review.conflicts.single.field, SyncConflict.record);
    expect(review.conflicts.single.candidates['left'], isNull);
    expect(
      (review.conflicts.single.candidates['right'] as Map)['title'],
      'Edited',
    );
  });
  test(
    'invalid modification metadata does not fabricate a successful merge',
    () {
      final bad = SyncRevision(
        id: 'bad',
        device: 'bad',
        sequence: 1,
        parents: [],
        value: {'title': 'Task', 'updated_at': 'not a UTC time'},
      );
      expect(() => reviewPortableRecord('tasks', [bad]), throwsFormatException);
    },
  );
  test('recurrence end date and interval are one meaningful rule decision', () {
    final original = base({
      'kind': 'daily',
      'interval': 1,
      'start_date': '2026-01-01',
      'end_date': null,
    });
    final ending = branch('left', {
      ...original.value!,
      'end_date': '2026-01-31',
    });
    final frequency = branch('right', {...original.value!, 'interval': 3});
    expect(
      reviewPortableRecord('recurrence_series', [
        original,
        ending,
        frequency,
      ]).needsDecision,
      isTrue,
    );
  });
}
