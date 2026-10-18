enum TrashKind { task, project, category, event, session, series }

class ArchivedSeries {
  const ArchivedSeries({
    required this.familyId,
    required this.title,
    required this.archivedAt,
    required this.occurrences,
  });
  final String familyId;
  final String title;
  final DateTime archivedAt;
  final int occurrences;
}

class TrashItem {
  const TrashItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.deletedAt,
    required this.affectedTasks,
  });

  final TrashKind kind;
  final String id;
  final String name;
  final DateTime deletedAt;
  final int affectedTasks;

  DateTime get retentionEndsAt => deletedAt.add(const Duration(days: 30));
}
