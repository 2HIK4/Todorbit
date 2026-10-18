import 'dart:convert';

enum TemplateKind { task, project, routine }

class LifeTemplate {
  const LifeTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required this.payload,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final TemplateKind kind;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;

  int get taskCount =>
      kind == TemplateKind.project ? (payload['tasks'] as List).length : 1;

  String get summary => switch (kind) {
    TemplateKind.task => 'Task',
    TemplateKind.routine => 'Recurring routine',
    TemplateKind.project => 'Project · $taskCount tasks',
  };

  String get payloadJson => jsonEncode(payload);
}
