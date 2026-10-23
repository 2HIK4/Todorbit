import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

String sidebarName(WorkspaceView view) => switch (view) {
  WorkspaceView.today => 'Today',
  WorkspaceView.all => 'All tasks',
  WorkspaceView.inbox => 'Inbox',
  WorkspaceView.anytime => 'Anytime',
  WorkspaceView.calendar => 'Calendar',
  WorkspaceView.habits => 'Habits',
  WorkspaceView.goals => 'Goals',
  WorkspaceView.upcoming => 'Upcoming',
  WorkspaceView.overdue => 'Overdue',
  WorkspaceView.waiting => 'Waiting / On hold',
  WorkspaceView.completed => 'Completed',
  _ => view.name,
};

IconData sidebarIcon(WorkspaceView view) => switch (view) {
  WorkspaceView.today => Icons.today_outlined,
  WorkspaceView.all => Icons.checklist_outlined,
  WorkspaceView.inbox => Icons.inbox_outlined,
  WorkspaceView.anytime => Icons.all_inclusive,
  WorkspaceView.calendar => Icons.calendar_month_outlined,
  WorkspaceView.habits => Icons.insights_outlined,
  WorkspaceView.goals => Icons.flag_outlined,
  WorkspaceView.upcoming => Icons.event_outlined,
  WorkspaceView.overdue => Icons.notification_important_outlined,
  WorkspaceView.waiting => Icons.pause_circle_outline,
  WorkspaceView.completed => Icons.task_alt_outlined,
  _ => Icons.circle_outlined,
};
