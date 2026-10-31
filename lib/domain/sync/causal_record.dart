import 'dart:convert';

Object? _canonical(Object? value) => switch (value) {
  Map() => {
    for (final key in value.keys.cast<String>().toList()..sort())
      key: _canonical(value[key]),
  },
  List() => value.map(_canonical).toList(),
  null || String() || bool() || int() => value,
  double() when value.isFinite => value,
  _ => throw const FormatException('Unsupported sync value'),
};

String _encode(Object? value) => jsonEncode(_canonical(value));
bool _same(Object? left, Object? right) => _encode(left) == _encode(right);

Object? _freeze(Object? value) => switch (value) {
  Map() => Map<String, Object?>.unmodifiable(
    value.cast<String, Object?>().map(
      (key, value) => MapEntry(key, _freeze(value)),
    ),
  ),
  List() => List<Object?>.unmodifiable(value.map(_freeze)),
  _ => value,
};

class SyncRevision {
  SyncRevision({
    required this.id,
    required this.device,
    required this.sequence,
    required Iterable<String> parents,
    required Map<String, Object?>? value,
  }) : parents = Set<String>.unmodifiable(parents),
       value = value == null
           ? null
           : _freeze(_canonical(value)) as Map<String, Object?> {
    if (id.isEmpty ||
        id.length > 128 ||
        device.isEmpty ||
        device.length > 128 ||
        sequence < 1 ||
        this.parents.contains(id) ||
        this.parents.length > 256 ||
        this.parents.any((id) => id.isEmpty || id.length > 128) ||
        (this.value?.containsKey(SyncConflict.record) ?? false)) {
      throw const FormatException('Invalid sync revision');
    }
  }
  final String id, device;
  final int sequence;
  final Set<String> parents;
  final Map<String, Object?>? value;

  Map<String, Object?> toJson() => {
    'id': id,
    'device': device,
    'sequence': sequence,
    'parents': parents.toList()..sort(),
    'value': value,
  };

  factory SyncRevision.fromJson(Map<String, dynamic> json) {
    if (json.keys.toSet().difference({
          'id',
          'device',
          'sequence',
          'parents',
          'value',
        }).isNotEmpty ||
        json['id'] is! String ||
        json['device'] is! String ||
        json['sequence'] is! int ||
        json['parents'] is! List ||
        !json.containsKey('value') ||
        (json['parents'] as List).any((value) => value is! String) ||
        (json['value'] != null && json['value'] is! Map)) {
      throw const FormatException('Invalid sync revision payload');
    }
    return SyncRevision(
      id: json['id'] as String,
      device: json['device'] as String,
      sequence: json['sequence'] as int,
      parents: (json['parents'] as List).cast<String>(),
      value: (json['value'] as Map?)?.cast<String, Object?>(),
    );
  }
}

class SyncConflict {
  const SyncConflict(
    this.field,
    this.base,
    this.candidates, {
    this.basePresent = true,
    this.absentCandidates = const {},
  });
  static const record = r'$record';
  final String field;
  final Object? base;
  final bool basePresent;
  final Set<String> absentCandidates;
  // Revision IDs identify every competing value; no wall clock chooses a side.
  final Map<String, Object?> candidates;
}

class SyncRecordReview {
  SyncRecordReview({
    required this.heads,
    required this.merged,
    required this.conflicts,
  });
  final Set<String> heads;
  // A draft only. Consumers must never apply a review with unresolved conflicts.
  final Map<String, Object?>? merged;
  final List<SyncConflict> conflicts;
  bool get needsDecision => conflicts.isNotEmpty;
}

// A lossless revision DAG for one stable entity. The store must persist incoming
// revisions, local mutations and resulting operations transactionally. This
// primitive neither accesses a database nor schedules network work.
class CausalRecord {
  CausalRecord({Iterable<Set<String>> coupledFields = const []})
    : coupledFields = List.unmodifiable(
        coupledFields.map(Set<String>.unmodifiable),
      );
  final List<Set<String>> coupledFields;
  final Map<String, SyncRevision> _revisions = {};
  Iterable<SyncRevision> get revisions => List.unmodifiable(_revisions.values);

  bool accept(SyncRevision revision) {
    final existing = _revisions[revision.id];
    if (existing != null) {
      if (!_same(existing.toJson(), revision.toJson())) {
        throw const FormatException(
          'A sync operation ID was reused with different contents',
        );
      }
      return false;
    }
    if (_revisions.values.any(
      (other) =>
          other.device == revision.device &&
          other.sequence == revision.sequence,
    )) {
      throw const FormatException('A device sequence was reused');
    }
    // Parents may arrive later. Reject cycles, including a cycle closed by a
    // previously missing parent, without disturbing the retained graph.
    bool reaches(String id, Set<String> visited) {
      if (id == revision.id) return true;
      if (!visited.add(id)) return false;
      return _revisions[id]?.parents.any(
            (parent) => reaches(parent, visited),
          ) ??
          false;
    }

    if (revision.parents.any((parent) => reaches(parent, {}))) {
      throw const FormatException('Cyclic sync ancestry');
    }
    for (final parent in {
      for (final id in revision.parents) ..._ancestors(id),
    }) {
      final known = _revisions[parent];
      if (known != null &&
          known.device == revision.device &&
          known.sequence >= revision.sequence) {
        throw const FormatException('Invalid device ancestry');
      }
    }
    // A late parent must satisfy the same monotonic constraint as an early one.
    for (final child in _revisions.values.where(
      (r) =>
          r.device == revision.device && _ancestors(r.id).contains(revision.id),
    )) {
      if (child.device == revision.device &&
          child.sequence <= revision.sequence) {
        throw const FormatException('Invalid late device ancestry');
      }
    }
    _revisions[revision.id] = revision;
    return true;
  }

  Set<String> _ancestors(String id) {
    final result = <String>{};
    final queue = <String>[id];
    while (queue.isNotEmpty) {
      final next = queue.removeLast();
      if (result.add(next)) queue.addAll(_revisions[next]?.parents ?? const {});
    }
    return result;
  }

  Set<String> get ready {
    final result = <String>{};
    bool changed;
    do {
      changed = false;
      for (final revision in _revisions.values) {
        if (!result.contains(revision.id) &&
            revision.parents.every(result.contains)) {
          result.add(revision.id);
          changed = true;
        }
      }
    } while (changed);
    return result;
  }

  Set<String> get pending =>
      Set.unmodifiable(_revisions.keys.toSet().difference(ready));

  SyncRecordReview review() {
    final available = ready;
    final heads = available.difference({
      for (final id in available) ..._revisions[id]!.parents,
    });
    final ordered = heads.toList()..sort();
    SyncRecordReview result(
      Map<String, Object?>? value,
      List<SyncConflict> conflicts,
    ) => SyncRecordReview(
      heads: Set.unmodifiable(heads),
      merged: value == null ? null : Map.unmodifiable(value),
      conflicts: List.unmodifiable(conflicts),
    );
    if (ordered.isEmpty) return result(null, []);
    if (ordered.length == 1) {
      return result(_revisions[ordered.single]!.value, []);
    }
    var common = _ancestors(ordered.first);
    for (final head in ordered.skip(1)) {
      common = common.intersection(_ancestors(head));
    }
    final bases = common
        .where(
          (candidate) => !common.any(
            (other) =>
                other != candidate && _ancestors(other).contains(candidate),
          ),
        )
        .toList();
    final candidates = {
      for (final head in ordered) head: _revisions[head]!.value,
    };
    if (candidates.values.every(
      (value) => _same(value, candidates.values.first),
    )) {
      return result(candidates.values.first, []);
    }
    if (bases.length != 1 ||
        candidates.values.any((value) => value == null) ||
        _revisions[bases.single]!.value == null) {
      return result(null, [
        SyncConflict(
          SyncConflict.record,
          bases.length == 1 ? _revisions[bases.single]!.value : null,
          Map.unmodifiable(candidates),
        ),
      ]);
    }
    final base = _revisions[bases.single]!.value!;
    final fields = {
      ...base.keys,
      for (final value in candidates.values) ...value!.keys,
    };
    final merged = <String, Object?>{};
    final conflicts = <SyncConflict>[];
    final changedByHead = <String, Set<String>>{};
    for (final head in ordered) {
      final value = candidates[head]!;
      changedByHead[head] = fields
          .where(
            (field) =>
                value.containsKey(field) != base.containsKey(field) ||
                !_same(value[field], base[field]),
          )
          .toSet();
    }
    for (final field in fields) {
      final changed = ordered
          .where((head) => changedByHead[head]!.contains(field))
          .toList();
      final distinct = changed
          .map(
            (head) => _encode([
              candidates[head]!.containsKey(field),
              candidates[head]![field],
            ]),
          )
          .toSet();
      if (distinct.length > 1) {
        conflicts.add(
          SyncConflict(
            field,
            base[field],
            Map.unmodifiable({
              for (final head in changed) head: candidates[head]![field],
            }),
            basePresent: base.containsKey(field),
            absentCandidates: Set.unmodifiable(
              changed.where((head) => !candidates[head]!.containsKey(field)),
            ),
          ),
        );
      } else {
        final selected = changed.isEmpty ? base : candidates[changed.first]!;
        if (selected.containsKey(field)) merged[field] = selected[field];
      }
    }
    for (final group in coupledFields) {
      final changes = ordered
          .where((head) => changedByHead[head]!.intersection(group).isNotEmpty)
          .toList();
      if (changes.length < 2) continue;
      final signatures = changes
          .map(
            (head) => _encode({
              for (final field in group)
                field: [
                  candidates[head]!.containsKey(field),
                  candidates[head]![field],
                ],
            }),
          )
          .toSet();
      if (signatures.length > 1) {
        for (final field in group) {
          merged.remove(field);
          if (!conflicts.any((conflict) => conflict.field == field)) {
            conflicts.add(
              SyncConflict(
                field,
                base[field],
                Map.unmodifiable({
                  for (final head in changes) head: candidates[head]![field],
                }),
                basePresent: base.containsKey(field),
                absentCandidates: Set.unmodifiable(
                  changes.where(
                    (head) => !candidates[head]!.containsKey(field),
                  ),
                ),
              ),
            );
          }
        }
      }
    }
    return result(merged, conflicts);
  }

  bool resolve({
    required Set<String> reviewedHeads,
    required SyncRevision resolution,
  }) {
    final current = review().heads;
    if (pending.isNotEmpty ||
        current.length != reviewedHeads.length ||
        !current.containsAll(reviewedHeads)) {
      return false;
    }
    if (resolution.parents.length != current.length ||
        !resolution.parents.containsAll(current)) {
      throw const FormatException(
        'A resolution must acknowledge every reviewed revision',
      );
    }
    return accept(resolution);
  }
}
