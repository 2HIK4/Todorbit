enum TaskResourceKind { managed, externalFile, externalFolder, url }

class TaskResource {
  const TaskResource({
    required this.id,
    required this.taskId,
    required this.kind,
    required this.label,
    required this.createdAt,
    required this.updatedAt,
    this.target,
    this.originalName,
    this.byteSize,
    this.sha256,
  });

  final String id;
  final String taskId;
  final TaskResourceKind kind;
  final String label;
  final String? target;
  final String? originalName;
  final int? byteSize;
  final String? sha256;
  final DateTime createdAt;
  final DateTime updatedAt;
}
