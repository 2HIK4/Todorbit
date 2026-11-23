import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import 'app_section_heading.dart';

/// Explains why a task destination is empty after its existing filters run.
class TaskListEmptyState extends StatelessWidget {
  const TaskListEmptyState({
    super.key,
    required this.view,
    required this.filtered,
  });

  final WorkspaceView view;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final title = filtered
        ? 'No matching tasks'
        : switch (view) {
            WorkspaceView.today => 'No tasks planned for today',
            WorkspaceView.inbox => 'Inbox is empty',
            WorkspaceView.upcoming => 'No upcoming tasks',
            WorkspaceView.overdue => 'No overdue deadlines',
            WorkspaceView.waiting => 'No tasks waiting or on hold',
            WorkspaceView.completed => 'No completed tasks',
            _ => 'No tasks here yet',
          };
    return AppEmptyState(
      title: title,
      message: filtered
          ? 'Change or clear the current filters or search.'
          : null,
    );
  }
}

/// Shared names for the two task list sort menus.
String taskSortLabel(TaskSort sort) => switch (sort) {
  TaskSort.schedule => 'Scheduled date',
  TaskSort.priority => 'Priority',
  TaskSort.title => 'Title',
  TaskSort.created => 'Newest first',
};
