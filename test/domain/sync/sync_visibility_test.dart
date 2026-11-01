import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/domain/sync/causal_record.dart';
import 'package:life_manager/domain/sync/sync_visibility.dart';

void main() {
  test('later applied facts never fill an unseen conflict hole', () {
    final visible = SyncVisibility({})
        .withRange('remote', 1, 9)
        .withRange('remote', 11, 100);
    expect(visible.contains('remote', 9), isTrue);
    expect(visible.contains('remote', 10), isFalse);
    expect(visible.contains('remote', 100), isTrue);
    expect(visible.contains('remote', 0), isFalse);
    expect(visible.withRange('remote', 10, 10).toJson(), {
      'remote': [
        [1, 100],
      ],
    });
  });

  test('overlap, arrival order and duplicate ranges normalize without losing holes', () {
    final ranges = [
      SyncSequenceRange(5, 8),
      SyncSequenceRange(1, 3),
      SyncSequenceRange(3, 5),
      SyncSequenceRange(10, 12),
    ];
    final expected = {
      'device': [
        [1, 8],
        [10, 12],
      ],
    };
    for (var offset = 0; offset < ranges.length; offset++) {
      final rotated = [...ranges.skip(offset), ...ranges.take(offset)];
      expect(SyncVisibility({'device': rotated}).toJson(), expected);
      expect(SyncVisibility({'device': rotated.reversed}).toJson(), expected);
    }
    final first = SyncVisibility({'device': ranges});
    final other = SyncVisibility({})
        .withRange('device', 9, 9)
        .withRange('second', 2, 3);
    final union = first.union(other);
    expect(union.toJson(), {
      'device': [
        [1, 12],
      ],
      'second': [
        [2, 3],
      ],
    });
    expect(union.covers(first), isTrue);
    expect(first.covers(union), isFalse);
    expect(union.covers(other), isTrue);
  });

  test(
    'retained visibility cannot be mutated by caller or serialized collections',
    () {
      final source = [SyncSequenceRange(1, 4)];
      final visible = SyncVisibility({'device': source});
      source.clear();
      final json = visible.toJson();
      (json['device'] as List).clear();
      expect(visible.contains('device', 4), isTrue);
      expect(() => visible.ranges.clear(), throwsUnsupportedError);
      expect(() => visible.ranges['device']!.clear(), throwsUnsupportedError);
    },
  );

  test('wire rejects malformed or noncanonical ranges', () {
    for (final value in [
      {'device': []},
      {
        'device': [
          [0, 1],
        ],
      },
      {
        'device': [
          [3, 2],
        ],
      },
      {
        'device': [
          [1, 2],
          [2, 3],
        ],
      },
      {
        'device': [
          [1, 2],
          [3, 4],
        ],
      },
      {
        'device': [
          [4, 5],
          [1, 2],
        ],
      },
      {
        'device': [
          [1, '2'],
        ],
      },
      {
        '': [
          [1, 2],
        ],
      },
    ]) {
      expect(() => SyncVisibility.fromJson(value), throwsFormatException);
    }
  });

  test('causal receipt is distinct from exact user-visible observations', () {
    final revision = SyncRevision(
      id: 'local',
      device: 'local',
      sequence: 1,
      parents: [],
      value: {'title': 'Visible local edit'},
      observed: {'remote': 100},
      visible: SyncVisibility({})
          .withRange('remote', 1, 9)
          .withRange('remote', 11, 100),
    );
    final restored = SyncRevision.fromJson(
      jsonDecode(jsonEncode(revision.toJson())) as Map<String, dynamic>,
    );
    final hidden = SyncRevision(
      id: 'conflicted',
      device: 'remote',
      sequence: 10,
      parents: [],
      value: null,
    );
    expect(restored.observes(hidden), isTrue);
    expect(restored.visible!.contains(hidden.device, hidden.sequence), isFalse);
    expect(restored.visible!.contains('remote', 100), isTrue);
  });

  test('visibility cannot invent a future or unobserved fact', () {
    for (final visible in [
      SyncVisibility({}).withRange('local', 1, 1),
      SyncVisibility({}).withRange('unknown', 1, 1),
    ]) {
      expect(
        () => SyncRevision(
          id: 'local',
          device: 'local',
          sequence: 1,
          parents: [],
          value: null,
          visible: visible,
        ),
        throwsFormatException,
      );
    }
  });
}
