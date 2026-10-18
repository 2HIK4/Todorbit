part of 'life_repository.dart';

extension SavedViewRepository on LifeRepository {
  Future<List<SavedView>> savedViews() async {
    final rows = await db
        .customSelect('SELECT * FROM saved_views ORDER BY name COLLATE NOCASE')
        .get();
    return rows
        .map(
          (row) => SavedView(
            id: row.read<String>('id'),
            name: row.read<String>('name'),
            filter: TaskFilter.fromJson(
              (jsonDecode(row.read<String>('filter_json')) as Map)
                  .cast<String, dynamic>(),
            ),
            updatedAt: DateTime.parse(row.read<String>('updated_at')),
          ),
        )
        .toList();
  }

  void _validateTaskFilter(TaskFilter filter) {
    if (filter.minimumPriority < 0 || filter.minimumPriority > 3) {
      throw ArgumentError('Invalid minimum priority');
    }
  }

  Future<SavedView> addSavedView(String name, TaskFilter filter) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('View name is required');
    _validateTaskFilter(filter);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      'INSERT INTO saved_views(id,name,filter_json,created_at,updated_at) VALUES(?,?,?,?,?)',
      variables: [
        Variable.withString(id),
        Variable.withString(cleaned),
        Variable.withString(jsonEncode(filter.toJson())),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await savedViews()).singleWhere((item) => item.id == id);
  }

  Future<void> updateSavedView(
    SavedView previous,
    String name,
    TaskFilter filter,
  ) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('View name is required');
    _validateTaskFilter(filter);
    final count = await db.customUpdate(
      'UPDATE saved_views SET name=?,filter_json=?,updated_at=? WHERE id=? AND updated_at=?',
      variables: [
        Variable.withString(cleaned),
        Variable.withString(jsonEncode(filter.toJson())),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) throw StateError('Saved view changed. Refresh first.');
  }

  Future<void> deleteSavedView(SavedView previous) async {
    final count = await db.customUpdate(
      'DELETE FROM saved_views WHERE id=? AND updated_at=?',
      variables: [
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) throw StateError('Saved view changed. Refresh first.');
  }
}
