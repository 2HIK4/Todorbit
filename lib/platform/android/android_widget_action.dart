import '../../app/app_controller.dart';
import '../../domain/models.dart';

/// Applies a native, one-use widget command through the shared repository rules.
Future<void> applyAndroidWidgetAction(
  AppController controller,
  Map<String, dynamic> command,
) async {
  final id = command['id'];
  final revision = command['revision'];
  final complete = command['complete'];
  if (id is! String || revision is! String || complete is! bool) {
    throw const FormatException('Invalid widget action');
  }
  await controller.refresh();
  final task = controller.tasks.where((task) => task.id == id).firstOrNull;
  if (task == null || task.status == TaskStatus.cancelled) {
    throw StateError('Task is no longer available');
  }
  // A repeated delivery must never toggle a task back or advance a series twice.
  if ((task.status == TaskStatus.completed) == complete) return;
  if (task.updatedAt.toUtc().toIso8601String() != revision) {
    throw StateError('Task changed. Open it before changing completion.');
  }
  await controller.setComplete(task, complete);
}
