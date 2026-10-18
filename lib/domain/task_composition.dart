class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.taskId,
    required this.title,
    required this.done,
    required this.position,
    required this.updatedAt,
  });
  final String id;
  final String taskId;
  final String title;
  final bool done;
  final int position;
  final DateTime updatedAt;
}
