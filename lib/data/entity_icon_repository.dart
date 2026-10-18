part of 'life_repository.dart';

extension EntityIconRepository on LifeRepository {
  Future<Map<String, String>> entityIcons() async {
    final rows = await db
        .customSelect(
          'SELECT kind,entity_id,icon_key '
          'FROM entity_icons',
        )
        .get();
    return {
      for (final row in rows)
        '${row.read<String>('kind')}:${row.read<String>('entity_id')}': row
            .read<String>('icon_key'),
    };
  }

  Future<void> setEntityIcon(String kind, String id, String? iconKey) async {
    const tables = <String, String>{
      'task': 'tasks',
      'category': 'categories',
      'project': 'projects',
      'series': 'recurrence_series',
    };
    final table = tables[kind];
    if (table == null) throw ArgumentError('Unknown icon target');
    if (iconKey != null &&
        (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(iconKey))) {
      throw ArgumentError('Unknown icon key');
    }
    await db.transaction(() async {
      final exists = await db
          .customSelect(
            'SELECT 1 FROM $table WHERE id=? AND deleted_at IS NULL',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      if (exists == null) throw StateError('Icon target no longer exists');
      if (iconKey == null) {
        await db.customUpdate(
          'DELETE FROM entity_icons WHERE kind=? AND entity_id=?',
          variables: [Variable.withString(kind), Variable.withString(id)],
        );
      } else {
        await db.customStatement(
          '''INSERT INTO entity_icons
          (kind,entity_id,icon_key,updated_at) VALUES(?,?,?,?)
          ON CONFLICT(kind,entity_id) DO UPDATE SET
          icon_key=excluded.icon_key,updated_at=excluded.updated_at''',
          [kind, id, iconKey, DateTime.now().toUtc().toIso8601String()],
        );
      }
    });
  }
}
