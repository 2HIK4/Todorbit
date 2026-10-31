import 'dart:convert';

import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:test/test.dart';

SyncRevision revision(
  String id,
  List<String> parents,
  Map<String, Object?>? value, {
  String? device,
  int sequence = 1,
}) => SyncRevision(
  id: id,
  device: device ?? id,
  sequence: sequence,
  parents: parents,
  value: value,
);

Iterable<List<T>> permutations<T>(List<T> values) sync* {
  if (values.isEmpty) {
    yield [];
    return;
  }
  for (var i = 0; i < values.length; i++) {
    final rest = [...values]..removeAt(i);
    for (final tail in permutations(rest)) {
      yield [values[i], ...tail];
    }
  }
}

void main() {
  test('late transitive ancestry cannot reverse a device sequence', () {
    final record = CausalRecord()
      ..accept(
        revision('descendant', ['middle'], {}, device: 'phone', sequence: 1),
      )
      ..accept(
        revision('middle', ['ancestor'], {}, device: 'windows', sequence: 1),
      );
    expect(
      () => record.accept(
        revision('ancestor', [], {}, device: 'phone', sequence: 2),
      ),
      throwsFormatException,
    );
    expect(record.pending, {'descendant', 'middle'});
  });

  test('field removal and explicit null remain different conflict choices', () {
    final record = CausalRecord()
      ..accept(revision('base', [], {'notes': 'old'}))
      ..accept(revision('removed', ['base'], {}))
      ..accept(revision('null', ['base'], {'notes': null}));
    final conflict = record.review().conflicts.single;
    expect(conflict.field, 'notes');
    expect(conflict.absentCandidates, {'removed'});
    expect(conflict.candidates.keys, {'removed', 'null'});
  });

  const original = {
    'title': 'Study Chapter 1',
    'notes': 'Keep notes',
    'status': 'notStarted',
  };
  test('all delivery orders converge; duplicate operations are harmless', () {
    final operations = [
      revision('base', [], original),
      revision('windows', ['base'], {...original, 'title': 'Study Chapter 2'}),
      revision(
        'android',
        ['base'],
        {...original, 'notes': 'Independent notes'},
      ),
      revision('later', ['windows'], {...original, 'title': 'Study Chapter 4'}),
    ];
    for (final order in permutations(operations)) {
      final record = CausalRecord();
      for (final op in order) {
        record.accept(op);
        expect(record.accept(op), isFalse);
      }
      final review = record.review();
      expect(review.needsDecision, isFalse);
      expect(review.merged, {
        ...original,
        'title': 'Study Chapter 4',
        'notes': 'Independent notes',
      });
      expect(record.pending, isEmpty);
      expect(record.revisions, hasLength(4));
    }
  });

  test('same-field edits survive serialization and do not use timestamps', () {
    final record = CausalRecord()
      ..accept(revision('base', [], original))
      ..accept(
        revision(
          'windows',
          ['base'],
          {...original, 'title': 'Study Chapter 2'},
        ),
      )
      ..accept(
        revision(
          'android',
          ['base'],
          {...original, 'title': 'Study Chapter 3'},
        ),
      );
    final restarted = CausalRecord();
    final saved = jsonDecode(
      jsonEncode(record.revisions.map((r) => r.toJson()).toList()),
    ) as List;
    for (final json in saved.reversed) {
      restarted.accept(
        SyncRevision.fromJson((json as Map).cast<String, dynamic>()),
      );
    }
    final review = restarted.review();
    expect(review.conflicts.single.field, 'title');
    expect(review.conflicts.single.base, 'Study Chapter 1');
    expect(
      review.conflicts.single.candidates.values,
      containsAll(['Study Chapter 2', 'Study Chapter 3']),
    );
    expect(review.merged!['notes'], 'Keep notes');
    expect(restarted.revisions, hasLength(3));
  });

  test('later edits on one branch preserve unresolved competing branches', () {
    final record = CausalRecord()
      ..accept(revision('base', [], original))
      ..accept(
        revision(
          'windows',
          ['base'],
          {...original, 'title': 'Study Chapter 2'},
        ),
      )
      ..accept(
        revision(
          'android',
          ['base'],
          {...original, 'title': 'Study Chapter 3'},
        ),
      );
    final reviewed = record.review().heads;
    record.accept(
      revision(
        'androidLater',
        ['android'],
        {...original, 'title': 'Study Chapter 5'},
      ),
    );
    expect(
      record.resolve(
        reviewedHeads: reviewed,
        resolution: revision('staleResolution', reviewed.toList(), original),
      ),
      isFalse,
    );
    expect(
      record.review().conflicts.single.candidates.values,
      containsAll(['Study Chapter 2', 'Study Chapter 5']),
    );
    final fresh = record.review().heads;
    expect(
      record.resolve(
        reviewedHeads: fresh,
        resolution: revision('resolved', fresh.toList(), {
          ...original,
          'title': 'Chosen',
        }),
      ),
      isTrue,
    );
    expect(record.review().heads, {'resolved'});
    expect(record.review().merged!['title'], 'Chosen');
    expect(record.revisions, hasLength(5));
  });

  test(
    'edit versus deletion retains both; causal deletion stays a tombstone',
    () {
      final record = CausalRecord()
        ..accept(revision('base', [], original))
        ..accept(revision('deleted', ['base'], null))
        ..accept(
          revision('edited', ['base'], {...original, 'notes': 'Offline work'}),
        );
      expect(record.review().conflicts.single.field, SyncConflict.record);
      expect(record.review().conflicts.single.candidates.keys, {
        'deleted',
        'edited',
      });
      final heads = record.review().heads;
      record.resolve(
        reviewedHeads: heads,
        resolution: revision('confirmDelete', heads.toList(), null),
      );
      expect(record.review().needsDecision, isFalse);
      expect(record.review().merged, isNull);
      // A long-offline branch arriving after resolution reopens a decision.
      record.accept(
        revision(
          'longOffline',
          ['base'],
          {...original, 'notes': 'Unseen work'},
        ),
      );
      expect(record.review().needsDecision, isTrue);
      expect(record.revisions, hasLength(5));
    },
  );

  test('recurrence edits versus completion require a meaningful decision', () {
    const row = {
      'title': 'Recurring',
      'status': 'notStarted',
      'rule': 'weekly',
    };
    final record =
        CausalRecord(
            coupledFields: [
              {'status', 'rule'},
            ],
          )
          ..accept(revision('base', [], row))
          ..accept(
            revision('complete', ['base'], {...row, 'status': 'completed'}),
          )
          ..accept(revision('recurrence', ['base'], {...row, 'rule': 'daily'}));
    expect(
      record.review().conflicts.map((c) => c.field),
      containsAll(['status', 'rule']),
    );
    expect(record.review().merged!['title'], 'Recurring');
  });

  test(
    'same independent field value merges; unrelated initial roots do not',
    () {
      final record = CausalRecord()
        ..accept(revision('base', [], original))
        ..accept(revision('a', ['base'], {...original, 'title': 'Same'}))
        ..accept(revision('b', ['base'], {...original, 'title': 'Same'}));
      expect(record.review().needsDecision, isFalse);
      record.accept(
        revision('imported', [], {
          ...original,
          'title': 'Existing device data',
        }),
      );
      expect(record.review().conflicts.single.field, SyncConflict.record);
    },
  );

  test(
    'missing ancestry is retained and prevents applying stale decisions',
    () {
      final record = CausalRecord()..accept(revision('known', [], original));
      final heads = record.review().heads;
      record.accept(
        revision('delayed', ['missing'], {...original, 'title': 'Pending'}),
      );
      expect(record.pending, {'delayed'});
      expect(
        record.resolve(
          reviewedHeads: heads,
          resolution: revision('blocked', heads.toList(), original),
        ),
        isFalse,
      );
      record.accept(revision('missing', ['known'], original));
      expect(record.pending, isEmpty);
      expect(record.review().merged!['title'], 'Pending');
    },
  );

  test(
    'operation ID collisions, forks and cycles never replace retained data',
    () {
      final record = CausalRecord()
        ..accept(
          revision('first', ['second'], original, device: 'phone', sequence: 2),
        );
      expect(
        () => record.accept(revision('first', [], null)),
        throwsFormatException,
      );
      expect(
        () => record.accept(
          revision('fork', [], null, device: 'phone', sequence: 2),
        ),
        throwsFormatException,
      );
      expect(
        () => record.accept(revision('second', ['first'], null)),
        throwsFormatException,
      );
      expect(record.revisions.single.value, original);
      expect(record.pending, {'first'});
      expect(
        () => record.accept(
          revision('second', [], null, device: 'phone', sequence: 3),
        ),
        throwsFormatException,
      );
      record.accept(
        revision('second', [], original, device: 'phone', sequence: 1),
      );
      expect(record.pending, isEmpty);
    },
  );

  test('caller mutation cannot change retained operation contents', () {
    final nested = <String, Object?>{
      'items': <Object?>['a'],
    };
    final op = revision('immutable', [], nested);
    (nested['items'] as List).add('b');
    expect(op.value!['items'], ['a']);
    expect(() => (op.value!['items'] as List).add('c'), throwsUnsupportedError);
    expect(() => op.parents.add('new'), throwsUnsupportedError);
    expect(
      () => SyncRevision.fromJson({...op.toJson(), 'futureField': 1}),
      throwsFormatException,
    );
  });
}
