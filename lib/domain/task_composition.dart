class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.taskId,
    required this.title,
    required this.done,
    required this.position,
    required this.updatedAt,
    this.groupId,
  });
  final String id;
  final String taskId;
  final String title;
  final bool done;
  final int position;
  final DateTime updatedAt;
  final String? groupId;
}

class TaskChecklistGroup {
  const TaskChecklistGroup({
    required this.id,
    required this.taskId,
    required this.title,
    required this.position,
    required this.updatedAt,
  });
  final String id, taskId, title;
  final int position;
  final DateTime updatedAt;
}

class DraftChecklistGroup {
  DraftChecklistGroup(this.title, this.items, {Object? identity})
    : identity = identity ?? Object();
  final Object identity;
  final String title;
  final List<String> items;
}
