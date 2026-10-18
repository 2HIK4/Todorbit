part of 'life_repository.dart';

extension ReportsRepository on LifeRepository {
  /// Includes archived work for historical reporting, but excludes Trash and
  /// descendants of trashed parents or recurring families.
  Future<List<LifeTask>> reportTasks() async {
    final rows = await db.customSelect('''
      SELECT t.*, o.series_id AS recurrence_series_id,
        o.ordinal AS recurrence_ordinal, o.nominal_date,
        o.disposition AS recurrence_disposition,
        o.is_edited AS recurrence_edited,
        o.is_rescheduled AS recurrence_rescheduled,
        s.kind AS recurrence_kind
      FROM tasks t LEFT JOIN recurrence_occurrences o ON o.task_id=t.id
      LEFT JOIN recurrence_series s ON s.id=o.series_id
      LEFT JOIN categories c ON c.id=t.category_id
      LEFT JOIN projects p ON p.id=t.project_id
      WHERE t.deleted_at IS NULL
        AND (s.id IS NULL OR s.deleted_at IS NULL)
        AND (c.id IS NULL OR c.deleted_at IS NULL)
        AND (p.id IS NULL OR p.deleted_at IS NULL)
      ORDER BY t.created_at,t.id
    ''').get();
    return rows.map(_taskFromRow).toList();
  }
}
