import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/app_database.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import '../../domain/time_tracking.dart';
import '../../domain/saved_views.dart';
import '../../domain/appearance.dart';
import '../calendar/calendar_view.dart';
import '../habits/habits_view.dart';
import '../goals/goals_view.dart';
import '../reports/reports_view.dart';
import '../contributors/contributors_view.dart';
import '../time_tracking/time_tracking_dialog.dart';
import '../templates/templates_dialog.dart';
import '../search/advanced_search_dialog.dart';
import '../settings/backup_dialog.dart';
import '../settings/notification_dialog.dart';
import '../settings/privacy_dialog.dart';
import '../settings/theme_dialog.dart';
import '../scheduling/smart_reschedule.dart';
import '../shared/icon_picker.dart';
import '../widget/native_widget_service.dart';
import 'task_editor.dart';
import 'sequence_dialog.dart';
import 'quick_search.dart';
import 'trash_dialog.dart';

class Workspace extends ConsumerStatefulWidget {
  const Workspace({super.key, this.openAppearance = false});

  final bool openAppearance;

  @override
  ConsumerState<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<Workspace> {
  bool creating = false;
  DateTime? newTaskInitialDate;
  final nativeWidget = NativeWidgetService();
  Timer? _clock;
  final Set<String> _expandedTaskIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.openAppearance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (_) => const ThemeDialog(),
          );
        }
      });
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(appControllerProvider).activeTimer != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _showDataProfile() async {
    final file = await AppDatabase.defaultFile();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data profile'),
        content: SelectableText(
          'TodoPilot stores this Windows user’s tasks and settings in the '
          'per-user data folder. Updating or reinstalling the app keeps this '
          'profile. A different Windows user starts with an empty profile.\n\n'
          'Database: ${file.path}\n\n'
          'To move data to another computer, use Backups and Export. '
          'This screen does not change any records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _newTask() {
    ref.read(appControllerProvider).select(null);
    newTaskInitialDate = null;
    if (MediaQuery.sizeOf(context).width < 1050) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: SizedBox(
            width: math.min(520, MediaQuery.sizeOf(dialogContext).width - 48),
            height: math.min(620, MediaQuery.sizeOf(dialogContext).height - 64),
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

  void _newTaskOn(DateTime date) {
    ref.read(appControllerProvider).select(null);
    if (MediaQuery.sizeOf(context).width < 1050) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: SizedBox(
            width: math.min(520, MediaQuery.sizeOf(dialogContext).width - 48),
            height: math.min(620, MediaQuery.sizeOf(dialogContext).height - 64),
            child: TaskEditor(
              initialScheduled: date,
              onSaved: () => Navigator.pop(dialogContext),
              onCancel: () => Navigator.pop(dialogContext),
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      newTaskInitialDate = date;
      creating = true;
    });
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
    var name = initial;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Name'),
          onChanged: (value) => name = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = 'Delete',
  }) async {
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
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showSmart({
    List<String>? taskIds,
    List<String>? sessionIds,
    String? scope,
  }) async {
    final controller = ref.read(appControllerProvider);
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SmartRescheduleDialog(
        scope: scope ?? _scheduleScope(controller),
        taskIds:
            taskIds ??
            controller.visibleTasks
                .where((task) => task.isOpen)
                .map((task) => task.id)
                .toList(),
        sessionIds: sessionIds ?? const [],
      ),
    );
  }

  Future<void> _showHistory() => showDialog<void>(
    context: context,
    builder: (_) => const ScheduleHistoryDialog(),
  );

  Future<void> _showSearch() => showDialog<void>(
    context: context,
    builder: (_) => const QuickSearchDialog(),
  );

  Future<void> _showTemplates() => showDialog<void>(
    context: context,
    builder: (_) => const TemplatesDialog(),
  );

  Future<void> _showArchiveTrash() => showDialog<void>(
    context: context,
    builder: (_) => const ArchiveTrashDialog(),
  );

  Future<void> _showAdvancedSearch([SavedView? savedView]) => showDialog<void>(
    context: context,
    builder: (_) => AdvancedSearchDialog(savedView: savedView),
  );

  Future<void> _deleteSavedView(SavedView savedView) async {
    if (await _confirm(
      'Delete saved view?',
      'Delete “${savedView.name}”? Tasks will remain unchanged.',
    )) {
      await _run(
        () => ref.read(appControllerProvider).deleteSavedView(savedView),
      );
    }
  }

  Future<void> _showActiveTimer(String taskId) => showDialog<void>(
    context: context,
    builder: (_) => TimeTrackingDialog(taskId: taskId),
  );

  Future<void> _changeIcon(String kind, String id) async {
    final controller = ref.read(appControllerProvider);
    final current = controller.iconKeys['$kind:$id'];
    final selected = await chooseBuiltInIcon(context, current: current);
    if (selected.$1 && mounted) {
      await _run(() => controller.setIcon(kind, id, selected.$2));
    }
  }

  Future<void> _quickStart(LifeTask task) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          task.status == TaskStatus.inProgress
              ? 'Work on ${task.title}'
              : 'Start ${task.title}',
        ),
        content: const Text(
          'Start Task changes its status only. '
          'Focus Session starts the stopwatch and records actual work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (task.status == TaskStatus.inProgress)
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'end'),
              child: const Text('End work'),
            )
          else
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'start'),
              child: const Text('Start Task'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'focus'),
            child: const Text('Start Focus Session'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final controller = ref.read(appControllerProvider);
    if (choice == 'start') {
      await _run(() => controller.startTask(task));
    } else if (choice == 'end') {
      await _run(() => controller.endTaskWork(task));
    } else {
      await _run(() => controller.startFocusTask(task));
      if (mounted && controller.activeTimer?.taskId == task.id) {
        _showActiveTimer(task.id);
      }
    }
  }

  String _scheduleScope(AppController controller) => switch (controller.view) {
    WorkspaceView.category => 'category:${controller.scopeId}',
    WorkspaceView.project => 'project:${controller.scopeId}',
    _ => 'view:${controller.view.name}',
  };

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newTask,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _showSearch,
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
                    width: constraints.maxWidth < 760
                        ? 190
                        : controller.customization.sidebarWidth.toDouble(),
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
                        initialScheduled: creating ? newTaskInitialDate : null,
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
    final privacy = ref.watch(privacyManagerProvider);
    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.activeTimer case final run?)
            Card(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              color: scheme.surfaceContainer,
              child: ListTile(
                dense: true,
                leading: Icon(
                  run.needsReview(DateTime.now())
                      ? Icons.warning_amber_rounded
                      : Icons.timer_outlined,
                ),
                title: Text(
                  '${formatWorkClock(TimeEntry.distinctDuration(controller.timeEntries.where((entry) => entry.timerRunId == run.id), run.needsReview(DateTime.now()) ? run.lastSeenAt : DateTime.now()))} · ${run.needsReview(DateTime.now())
                      ? 'Review'
                      : run.state == TimerState.running
                      ? 'Running'
                      : 'Paused'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  controller.tasks
                          .where((task) => task.id == run.taskId)
                          .map((task) => task.title)
                          .firstOrNull ??
                      'Deleted task',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: run.taskId == null
                    ? null
                    : () => _showActiveTimer(run.taskId!),
                trailing: run.needsReview(DateTime.now())
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Timer controls',
                        onSelected: (value) => _run(
                          () => value == 'stop'
                              ? controller.stopTimer()
                              : run.state == TimerState.running
                              ? controller.pauseTimer()
                              : controller.resumeTimer(),
                        ),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              run.state == TimerState.running
                                  ? 'Pause'
                                  : 'Resume',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'stop',
                            child: Text('Stop'),
                          ),
                        ],
                      ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 24,
                    height: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'TodoPilot',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const NotificationDialog(),
                  ),
                  icon: const Icon(Icons.notifications_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Archive and Trash',
                  onPressed: _showArchiveTrash,
                  icon: const Icon(Icons.archive_outlined, size: 20),
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
                  WorkspaceView.anytime,
                  'Anytime',
                  Icons.all_inclusive,
                ),
                _nav(
                  controller,
                  WorkspaceView.calendar,
                  'Calendar',
                  Icons.calendar_month_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.habits,
                  'Habits',
                  Icons.insights_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.goals,
                  'Goals',
                  Icons.flag_outlined,
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
                const SizedBox(height: 8),
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
                    iconForKey(
                      controller.iconKeys['category:${category.id}'],
                      Icons.folder_outlined,
                    ),
                    id: category.id,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Category actions',
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'project',
                          child: Text('Add project'),
                        ),
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(
                          value: 'icon',
                          child: Text('Change icon'),
                        ),
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
                        } else if (action == 'icon') {
                          await _changeIcon('category', category.id);
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
                          'Move this category to Trash? Its projects and tasks will be hidden until restored.',
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
                        iconForKey(
                          controller.iconKeys['project:${project.id}'],
                          Icons.segment_outlined,
                        ),
                        id: project.id,
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Project actions',
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'template',
                              child: Text('Save as template'),
                            ),
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'icon',
                              child: Text('Change icon'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (action) async {
                            if (action == 'template') {
                              await showSaveTemplateDialog(
                                context,
                                sourceName: project.name,
                                save: (name) => controller.saveProjectTemplate(
                                  project,
                                  name,
                                ),
                              );
                            } else if (action == 'icon') {
                              await _changeIcon('project', project.id);
                            } else if (action == 'rename') {
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
                              'Move this project to Trash? Its tasks will be hidden until restored.',
                            )) {
                              _run(() => controller.deleteProject(project.id));
                            }
                          },
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'SAVED VIEWS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Create saved view',
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            const AdvancedSearchDialog(creatingSavedView: true),
                      ),
                      icon: const Icon(Icons.add, size: 19),
                    ),
                  ],
                ),
                for (final savedView in controller.savedViews)
                  _nav(
                    controller,
                    WorkspaceView.saved,
                    savedView.name,
                    Icons.bookmark_outline,
                    id: savedView.id,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Saved view actions',
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit filters'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete view'),
                        ),
                      ],
                      onSelected: (action) => action == 'edit'
                          ? _showAdvancedSearch(savedView)
                          : _deleteSavedView(savedView),
                    ),
                  ),
                _nav(
                  controller,
                  WorkspaceView.reports,
                  'Reports',
                  Icons.bar_chart_outlined,
                ),
                _nav(
                  controller,
                  WorkspaceView.contributors,
                  'Contributors',
                  Icons.groups_outlined,
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: 'Quick Search (Ctrl+K)',
                onPressed: _showSearch,
                icon: const Icon(Icons.search_outlined),
              ),
              IconButton(
                tooltip: 'Advanced search',
                onPressed: () => _showAdvancedSearch(),
                icon: const Icon(Icons.manage_search_outlined),
              ),
              IconButton(
                tooltip: 'Task sequences',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const SequenceDialog(),
                ),
                icon: const Icon(Icons.format_list_numbered),
              ),
              IconButton(
                tooltip: 'Templates',
                onPressed: _showTemplates,
                icon: const Icon(Icons.copy_all_outlined),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: PopupMenuButton<String>(
              tooltip: nativeWidget.isAvailable
                  ? 'Native Windows widget'
                  : 'Native widget companion is unavailable in this build',
              enabled: nativeWidget.isAvailable,
              onSelected: (action) => _run(() async {
                switch (action) {
                  case 'show':
                    await nativeWidget.show();
                    return;
                  case 'hide':
                    await nativeWidget.hide();
                    return;
                  case 'quick-add':
                    await nativeWidget.quickAdd();
                    return;
                  case 'today':
                    await nativeWidget.setView('today');
                    return;
                  case 'inbox':
                    await nativeWidget.setView('inbox');
                    return;
                  case 'all':
                    await nativeWidget.setView('all');
                    return;
                  case 'upcoming':
                    await nativeWidget.setView('upcoming');
                    return;
                  case 'close':
                    await nativeWidget.close();
                    return;
                }
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'show', child: Text('Show widget')),
                PopupMenuItem(value: 'hide', child: Text('Hide widget')),
                PopupMenuItem(value: 'quick-add', child: Text('Quick Add')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'today', child: Text('Show Today')),
                PopupMenuItem(value: 'inbox', child: Text('Show Inbox')),
                PopupMenuItem(value: 'all', child: Text('Show All Tasks')),
                PopupMenuItem(value: 'upcoming', child: Text('Show Upcoming')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'close', child: Text('Close widget')),
              ],
              child: ListTile(
                dense: true,
                enabled: nativeWidget.isAvailable,
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('Windows widget'),
                trailing: const Icon(Icons.expand_more),
              ),
            ),
          ),
          if (controller.backupService case final backupService?)
            ListTile(
              dense: true,
              leading: Icon(
                controller.backupError == null
                    ? Icons.backup_outlined
                    : Icons.warning_amber_outlined,
              ),
              title: const Text('Backups'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => BackupDialog(
                  service: backupService,
                  automaticError: controller.backupError,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: PopupMenuButton<String>(
              tooltip: 'Settings',
              onSelected: (value) {
                if (value == 'privacy') {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const PrivacyDialog(),
                  );
                } else if (value == 'appearance') {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const ThemeDialog(),
                  );
                } else if (value == 'lock') {
                  privacy.lock();
                } else if (value == 'profile') {
                  _showDataProfile();
                } else {
                  final theme = ThemeModePreference.values.firstWhere(
                    (item) => item.name == value,
                  );
                  _run(() => controller.setTheme(theme));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'system',
                  child: Text('System theme'),
                ),
                const PopupMenuItem(value: 'light', child: Text('Light theme')),
                const PopupMenuItem(value: 'dark', child: Text('Dark theme')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'appearance',
                  child: Text('Appearance · Customize Theme'),
                ),
                const PopupMenuItem(
                  value: 'privacy',
                  child: Text('Privacy and app lock'),
                ),
                if (Platform.isWindows)
                  const PopupMenuItem(
                    value: 'profile',
                    child: Text('Data profile and location'),
                  ),
                if (privacy.enabled)
                  const PopupMenuItem(value: 'lock', child: Text('Lock now')),
              ],
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.settings_outlined),
                title: Text('Settings'),
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
    if (controller.view == WorkspaceView.habits) {
      return const HabitsView();
    }
    if (controller.view == WorkspaceView.goals) {
      return const GoalsView();
    }
    if (controller.view == WorkspaceView.reports) {
      return const ReportsView();
    }
    if (controller.view == WorkspaceView.contributors) {
      return const ContributorsView();
    }
    if (controller.view == WorkspaceView.calendar) {
      return CalendarView(
        onAddTask: _newTaskOn,
        onTaskTap: (task) {
          controller.select(task.id);
          if (!wide) _showNarrowEditor(task);
        },
        onSmartReschedule: () {
          final sessions = controller.sessions
              .where(
                (session) =>
                    session.outcome == SessionOutcome.upcoming ||
                    session.outcome == SessionOutcome.missed ||
                    session.outcome == SessionOutcome.skipped ||
                    session.outcome == SessionOutcome.partial,
              )
              .map((session) => session.id)
              .toList();
          _showSmart(sessionIds: sessions, scope: 'calendar');
        },
      );
    }
    final activeIds = controller.tasks.map((task) => task.id).toSet();
    final items = controller.visibleTasks.where((task) {
      final parentId = controller.taskParents[task.id];
      return parentId == null || activeIds.contains(parentId);
    }).toList();
    final itemIds = items.map((task) => task.id).toSet();
    final roots = items
        .where((task) => !itemIds.contains(controller.taskParents[task.id]))
        .toList();
    final today = localDate(DateTime.now());
    final todayStart = DateTime.now();
    final dayStart = DateTime(
      todayStart.year,
      todayStart.month,
      todayStart.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final todayEvents = controller.events.where((event) {
      final start = event.startsAt.toLocal();
      final end = event.endsAt.toLocal();
      return !event.cancelled &&
          start.isBefore(dayEnd) &&
          end.isAfter(dayStart);
    }).length;
    final todaySessions = controller.sessions.where((session) {
      final start = session.startsAt.toLocal();
      return start.isBefore(dayEnd) &&
          session.endsAt.toLocal().isAfter(dayStart) &&
          session.outcome != SessionOutcome.skipped;
    }).length;
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
      WorkspaceView.anytime => 'Anytime',
      WorkspaceView.all => 'All tasks',
      WorkspaceView.inbox => 'Inbox',
      WorkspaceView.upcoming => 'Upcoming',
      WorkspaceView.overdue => 'Overdue',
      WorkspaceView.waiting => 'Waiting / On hold',
      WorkspaceView.completed => 'Completed',
      WorkspaceView.calendar => 'Calendar',
      WorkspaceView.habits => 'Habits',
      WorkspaceView.goals => 'Goals',
      WorkspaceView.reports => 'Reports',
      WorkspaceView.contributors => 'Contributors',
      WorkspaceView.saved =>
        controller.savedViews
                .where((item) => item.id == controller.scopeId)
                .firstOrNull
                ?.name ??
            'Saved view',
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
                          ?.copyWith(fontWeight: FontWeight.w600),
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
              IconButton(
                key: const ValueKey('schedule-history-button'),
                tooltip: 'Schedule History',
                onPressed: _showHistory,
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.38);
                    }
                    return Theme.of(context).colorScheme.onSurfaceVariant;
                  }),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.08);
                    }
                    if (states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.pressed)) {
                      return Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.12);
                    }
                    return null;
                  }),
                ),
                icon: const Icon(
                  Icons.restore_rounded,
                  semanticLabel: 'Schedule History',
                ),
              ),
              OutlinedButton.icon(
                onPressed: items.any((task) => task.isOpen)
                    ? () => _showSmart()
                    : null,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Reschedule'),
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
                  label: Text('$today · ${items.length} planned tasks'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.event_outlined, size: 17),
                  label: Text('$todayEvents events'),
                  onPressed: () => controller.navigate(WorkspaceView.calendar),
                ),
                ActionChip(
                  avatar: const Icon(Icons.schedule_outlined, size: 17),
                  label: Text('$todaySessions work sessions'),
                  onPressed: () => controller.navigate(WorkspaceView.calendar),
                ),
                if (overdueCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.warning_amber_rounded, size: 17),
                    label: Text(
                      '$overdueCount overdue deadline${overdueCount == 1 ? '' : 's'}',
                    ),
                    onPressed: () => controller.navigate(WorkspaceView.overdue),
                  ),
                if (controller.goals.any(
                  (goal) =>
                      !goal.archived &&
                      !goal.completed &&
                      goal.deadlineDate != null &&
                      goal.deadlineDate!.compareTo(
                            RecurrenceRule.shiftDate(today, 7),
                          ) <=
                          0,
                ))
                  ActionChip(
                    avatar: const Icon(Icons.flag_outlined, size: 17),
                    label: const Text('Goals due soon'),
                    onPressed: () => controller.navigate(WorkspaceView.goals),
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
                        controller.view == WorkspaceView.today
                            ? 'No tasks planned for today'
                            : 'Nothing here yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        controller.view == WorkspaceView.today
                            ? 'Add a task or review today’s calendar.'
                            : 'Create a task or choose another view.',
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: roots.length,
                  itemBuilder: (context, index) {
                    final task = roots[index];
                    final children = controller.tasks
                        .where(
                          (child) =>
                              controller.taskParents[child.id] == task.id,
                        )
                        .toList();
                    final expanded = _expandedTaskIds.contains(task.id);
                    return Column(
                      children: [
                        _taskRow(
                          controller,
                          task,
                          wide,
                          childCount: children.length,
                          expanded: expanded,
                        ),
                        if (expanded)
                          for (final child in children)
                            Padding(
                              padding: const EdgeInsets.only(left: 26),
                              child: _taskRow(controller, child, wide),
                            ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _taskRow(
    AppController controller,
    LifeTask task,
    bool wide, {
    int childCount = 0,
    bool expanded = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final done = task.status == TaskStatus.completed;
    final focusActive = controller.activeTimer?.taskId == task.id;
    final unmetPrerequisites = controller.unmetPrerequisites(task.id);
    final overdue =
        task.isOpen &&
        task.deadlineDate != null &&
        task.deadlineDate!.compareTo(localDate(DateTime.now())) < 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: focusActive
          ? scheme.primaryContainer.withValues(alpha: 0.7)
          : controller.selectedTaskId == task.id
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
              if (childCount > 0)
                IconButton(
                  tooltip: expanded ? 'Collapse subtasks' : 'Expand subtasks',
                  onPressed: () => setState(() {
                    if (expanded) {
                      _expandedTaskIds.remove(task.id);
                    } else {
                      _expandedTaskIds.add(task.id);
                    }
                  }),
                  icon: Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                  ),
                ),
              Tooltip(
                message: done ? 'Reopen task' : 'Complete task',
                child: Checkbox(
                  value: done,
                  onChanged: (value) =>
                      _run(() => controller.setComplete(task, value ?? false)),
                ),
              ),
              Icon(
                iconForKey(
                  controller.iconForTask(task),
                  Icons.task_alt_outlined,
                ),
                size: 19,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
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
                        task.status == TaskStatus.inProgress ||
                        childCount > 0 ||
                        controller.checklistItems.any(
                          (item) => item.taskId == task.id,
                        ) ||
                        task.status == TaskStatus.waiting ||
                        task.status == TaskStatus.onHold ||
                        unmetPrerequisites.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (childCount > 0)
                              Text(
                                'Subtasks ${controller.tasks.where((child) => controller.taskParents[child.id] == task.id && child.status == TaskStatus.completed).length}/$childCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            if (controller.checklistItems.any(
                              (item) => item.taskId == task.id,
                            ))
                              Text(
                                'Checklist ${controller.checklistItems.where((item) => item.taskId == task.id && item.done).length}/'
                                '${controller.checklistItems.where((item) => item.taskId == task.id).length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            if (focusActive ||
                                task.status == TaskStatus.inProgress)
                              Text(
                                focusActive ? 'Focus running' : 'In progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
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
                            if (unmetPrerequisites.isNotEmpty)
                              Tooltip(
                                message:
                                    'Waiting for ${unmetPrerequisites.map((item) => item.title).join(', ')}',
                                child: Text(
                                  'Blocked by ${unmetPrerequisites.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.error,
                                  ),
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
              if (task.isOpen)
                IconButton(
                  tooltip: task.status == TaskStatus.inProgress
                      ? 'Work or focus actions'
                      : 'Start task or focus',
                  onPressed: () => _quickStart(task),
                  icon: Icon(
                    focusActive ? Icons.timer : Icons.play_circle_outline,
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Task actions',
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: const Text('Edit')),
                  PopupMenuItem(
                    value: 'complete',
                    child: Text(done ? 'Reopen' : 'Complete'),
                  ),
                  if (task.isOpen)
                    const PopupMenuItem(
                      value: 'reschedule',
                      child: Text('Smart Reschedule'),
                    ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      task.recurrenceSeriesId == null
                          ? 'Archive'
                          : 'Archive occurrence',
                    ),
                  ),
                  if (task.recurrenceSeriesId != null)
                    const PopupMenuItem(
                      value: 'archiveSeries',
                      child: Text('Archive entire series'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      task.recurrenceSeriesId == null
                          ? 'Delete'
                          : 'Move occurrence to Trash',
                    ),
                  ),
                  if (task.recurrenceSeriesId != null)
                    const PopupMenuItem(
                      value: 'deleteSeries',
                      child: Text('Move entire series to Trash'),
                    ),
                ],
                onSelected: (action) async {
                  if (action == 'edit') {
                    setState(() => creating = false);
                    controller.select(task.id);
                    if (!wide) _showNarrowEditor(task);
                  } else if (action == 'complete') {
                    _run(() => controller.setComplete(task, !done));
                  } else if (action == 'reschedule') {
                    _showSmart(taskIds: [task.id], scope: 'task:${task.id}');
                  } else if (action == 'archive') {
                    _run(() => controller.archiveTask(task));
                  } else if (action == 'archiveSeries') {
                    if (await _confirm(
                      'Archive entire series?',
                      'Hide every occurrence in this series? History is retained and the series can be restored.',
                      confirmLabel: 'Archive series',
                    )) {
                      _run(() => controller.archiveSeries(task));
                    }
                  } else if (action == 'deleteSeries') {
                    if (await _confirm(
                      'Move entire series to Trash?',
                      'Every occurrence will be hidden. Restoring the series preserves its history.',
                    )) {
                      _run(() => controller.deleteSeries(task));
                    }
                  } else if (await _confirm(
                    'Delete task?',
                    'Move “${task.title}” to Trash? It can be restored with its history.',
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
          width: math.min(520, MediaQuery.sizeOf(context).width - 48),
          height: math.min(620, MediaQuery.sizeOf(context).height - 64),
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
