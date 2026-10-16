import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../calendar/calendar_view.dart';
import 'task_editor.dart';

class Workspace extends ConsumerStatefulWidget {
  const Workspace({super.key});

  @override
  ConsumerState<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<Workspace> {
  bool creating = false;

  void _newTask() {
    ref.read(appControllerProvider).select(null);
    if (MediaQuery.sizeOf(context).width < 1050) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: SizedBox(
            width: 520,
            height: 620,
            child: TaskEditor(
              onSaved: () => Navigator.pop(dialogContext),
              onCancel: () => Navigator.pop(dialogContext),
            ),
          ),
        ),
      );
      return;
    }
    setState(() => creating = true);
  }

  void _closeEditor() {
    ref.read(appControllerProvider).select(null);
    setState(() => creating = false);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $error')));
      }
    }
  }

  Future<String?> _nameDialog(String title, {String initial = ''}) async {
    final input = TextEditingController(text: initial);
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: input,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      input.dispose();
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newTask,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1050;
              final editor = creating || controller.selectedTask != null;
              return Row(
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 760 ? 190 : 238,
                    child: _sidebar(controller),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(child: _mainPanel(controller, wide)),
                  if (wide && editor) ...[
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    SizedBox(
                      width: 370,
                      child: TaskEditor(
                        key: ValueKey(
                          creating ? 'new' : controller.selectedTask!.id,
                        ),
                        task: creating ? null : controller.selectedTask,
                        onSaved: _closeEditor,
                        onCancel: _closeEditor,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sidebar(AppController controller) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 14),
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Life Manager',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _nav(
                  controller,
                  WorkspaceView.today,
                  'Today',
                  Icons.today_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.all,
                  'All tasks',
                  Icons.checklist_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.inbox,
                  'Inbox',
                  Icons.inbox_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.calendar,
                  'Calendar',
                  Icons.calendar_month_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.upcoming,
                  'Upcoming',
                  Icons.event_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.overdue,
                  'Overdue',
                  Icons.notification_important_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.waiting,
                  'Waiting / On hold',
                  Icons.pause_circle_outline,
                ),
                _nav(
                  controller,
                  WorkspaceView.completed,
                  'Completed',
                  Icons.task_alt_outlined,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'CATEGORIES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add category',
                      icon: const Icon(Icons.add, size: 19),
                      onPressed: () async {
                        final name = await _nameDialog('New category');
                        if (name != null && name.isNotEmpty) {
                          _run(() => controller.addCategory(name));
                        }
                      },
                    ),
                  ],
                ),
                if (controller.categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 2, 8, 10),
                    child: Text(
                      'Organize tasks with categories',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                for (final category in controller.categories) ...[
                  _nav(
                    controller,
                    WorkspaceView.category,
                    category.name,
                    Icons.folder_outlined,
                    id: category.id,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Category actions',
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'project',
                          child: Text('Add project'),
                        ),
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (action) async {
                        if (action == 'project') {
                          final name = await _nameDialog('New project');
                          if (name != null && name.isNotEmpty) {
                            _run(
                              () => controller.addProject(category.id, name),
                            );
                          }
                        } else if (action == 'rename') {
                          final name = await _nameDialog(
                            'Rename category',
                            initial: category.name,
                          );
                          if (name != null && name.isNotEmpty) {
                            _run(
                              () =>
                                  controller.renameCategory(category.id, name),
                            );
                          }
                        } else if (await _confirm(
                          'Delete category?',
                          'A category containing projects or tasks cannot be deleted.',
                        )) {
                          _run(() => controller.deleteCategory(category.id));
                        }
                      },
                    ),
                  ),
                  for (final project in controller.projects.where(
                    (p) => p.categoryId == category.id,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: _nav(
                        controller,
                        WorkspaceView.project,
                        project.name,
                        Icons.segment_outlined,
                        id: project.id,
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Project actions',
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (action) async {
                            if (action == 'rename') {
                              final name = await _nameDialog(
                                'Rename project',
                                initial: project.name,
                              );
                              if (name != null && name.isNotEmpty) {
                                _run(
                                  () => controller.renameProject(
                                    project.id,
                                    name,
                                  ),
                                );
                              }
                            } else if (await _confirm(
                              'Delete project?',
                              'A project containing tasks cannot be deleted.',
                            )) {
                              _run(() => controller.deleteProject(project.id));
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: PopupMenuButton<ThemeModePreference>(
              tooltip: 'Appearance',
              onSelected: controller.setTheme,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: ThemeModePreference.system,
                  child: Text('System theme'),
                ),
                PopupMenuItem(
                  value: ThemeModePreference.light,
                  child: Text('Light theme'),
                ),
                PopupMenuItem(
                  value: ThemeModePreference.dark,
                  child: Text('Dark theme'),
                ),
              ],
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.palette_outlined),
                title: Text('Appearance'),
                trailing: Icon(Icons.expand_more),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav(
    AppController controller,
    WorkspaceView view,
    String title,
    IconData icon, {
    String? id,
    Widget? trailing,
  }) {
    final active = controller.view == view && controller.scopeId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active
            ? Theme.of(context).colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          leading: Icon(icon, size: 19),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: trailing,
          selected: active,
          onTap: () {
            setState(() => creating = false);
            controller.navigate(view, id: id);
          },
        ),
      ),
    );
  }

  Widget _mainPanel(AppController controller, bool wide) {
    if (controller.view == WorkspaceView.calendar) {
      return CalendarView(
        onTaskTap: (task) {
          controller.select(task.id);
          if (!wide) _showNarrowEditor(task);
        },
      );
    }
    final items = controller.visibleTasks;
    final today = localDate(DateTime.now());
    final overdueCount = controller.tasks
        .where(
          (t) =>
              t.isOpen &&
              t.deadlineDate != null &&
              t.deadlineDate!.compareTo(today) < 0,
        )
        .length;
    final title = switch (controller.view) {
      WorkspaceView.today => 'Today',
      WorkspaceView.all => 'All tasks',
      WorkspaceView.inbox => 'Inbox',
      WorkspaceView.upcoming => 'Upcoming',
      WorkspaceView.overdue => 'Overdue',
      WorkspaceView.waiting => 'Waiting / On hold',
      WorkspaceView.completed => 'Completed',
      WorkspaceView.calendar => 'Calendar',
      WorkspaceView.category =>
        controller.categories
                .where((c) => c.id == controller.scopeId)
                .firstOrNull
                ?.name ??
            'Category',
      WorkspaceView.project =>
        controller.projects
                .where((p) => p.id == controller.scopeId)
                .firstOrNull
                ?.name ??
            'Project',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${items.length} ${items.length == 1 ? 'task' : 'tasks'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<TaskSort>(
                tooltip: 'Sort tasks',
                onSelected: controller.setSort,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: TaskSort.schedule,
                    child: Text('Scheduled date'),
                  ),
                  PopupMenuItem(
                    value: TaskSort.priority,
                    child: Text('Priority'),
                  ),
                  PopupMenuItem(value: TaskSort.title, child: Text('Title')),
                  PopupMenuItem(
                    value: TaskSort.created,
                    child: Text('Newest first'),
                  ),
                ],
                icon: const Icon(Icons.sort),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _newTask,
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
            ],
          ),
        ),
        if (controller.view == WorkspaceView.today)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 24, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.today, size: 17),
                  label: Text('$today · ${items.length} planned'),
                ),
                if (overdueCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.warning_amber_rounded, size: 17),
                    label: Text(
                      '$overdueCount overdue deadline${overdueCount == 1 ? '' : 's'}',
                    ),
                    onPressed: () => controller.navigate(WorkspaceView.overdue),
                  ),
              ],
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.task_alt_outlined,
                        size: 42,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nothing here yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      const Text('Create a task or choose another view.'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _taskRow(controller, items[index], wide),
                ),
        ),
      ],
    );
  }

  Widget _taskRow(AppController controller, LifeTask task, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    final done = task.status == TaskStatus.completed;
    final overdue =
        task.isOpen &&
        task.deadlineDate != null &&
        task.deadlineDate!.compareTo(localDate(DateTime.now())) < 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: controller.selectedTaskId == task.id
          ? scheme.secondaryContainer.withValues(alpha: 0.55)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => creating = false);
          controller.select(task.id);
          if (!wide) _showNarrowEditor(task);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Tooltip(
                message: done ? 'Reopen task' : 'Complete task',
                child: Checkbox(
                  value: done,
                  onChanged: (value) =>
                      _run(() => controller.setComplete(task, value ?? false)),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.scheduledDate != null ||
                        task.deadlineDate != null ||
                        task.status == TaskStatus.waiting ||
                        task.status == TaskStatus.onHold)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (task.scheduledDate != null)
                              Text(
                                'Plan ${task.scheduledDate}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            if (task.deadlineDate != null)
                              Text(
                                'Due ${task.deadlineDate}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: overdue
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            if (task.status == TaskStatus.waiting ||
                                task.status == TaskStatus.onHold)
                              Text(
                                task.status == TaskStatus.waiting
                                    ? 'Waiting'
                                    : 'On hold',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (task.priority >= 2)
                Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: task.priority == 3 ? scheme.error : scheme.primary,
                ),
              PopupMenuButton<String>(
                tooltip: 'Task actions',
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: const Text('Edit')),
                  PopupMenuItem(
                    value: 'complete',
                    child: Text(done ? 'Reopen' : 'Complete'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (action) async {
                  if (action == 'edit') {
                    setState(() => creating = false);
                    controller.select(task.id);
                    if (!wide) _showNarrowEditor(task);
                  } else if (action == 'complete') {
                    _run(() => controller.setComplete(task, !done));
                  } else if (await _confirm(
                    'Delete task?',
                    'This permanently deletes “${task.title}”. Trash is not available yet.',
                  )) {
                    _run(() => controller.deleteTask(task.id));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNarrowEditor(LifeTask task) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 520,
          height: 620,
          child: TaskEditor(
            task: task,
            onSaved: () => Navigator.pop(context),
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
    if (mounted) ref.read(appControllerProvider).select(null);
  }
}
