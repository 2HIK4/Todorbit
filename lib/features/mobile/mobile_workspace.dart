import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/mobile_preference_store.dart';
import '../../domain/models.dart';
import '../../data/life_repository.dart';
import '../../platform/android/android_platform.dart';
import '../calendar/event_editor.dart';
import '../calendar/session_editor.dart';
import '../contributors/contributors_view.dart';
import '../goals/goals_view.dart';
import '../habits/habits_view.dart';
import '../reports/reports_view.dart';
import '../scheduling/smart_reschedule.dart';
import '../search/advanced_search_dialog.dart';
import '../shared/sidebar_items.dart';
import '../shared/text_prompt_dialog.dart';
import '../shared/icon_picker.dart';
import '../shared/event_color_picker.dart';
import '../templates/templates_dialog.dart';
import '../time_tracking/time_tracking_dialog.dart';
import '../workspace/sequence_dialog.dart';
import '../workspace/task_editor.dart';
import '../workspace/trash_dialog.dart';
import 'mobile_calendar.dart';
import 'mobile_settings.dart';

class MobileWorkspace extends ConsumerStatefulWidget {
  const MobileWorkspace({super.key, this.preferenceStore});
  final MobilePreferenceStore? preferenceStore;
  @override
  ConsumerState<MobileWorkspace> createState() => _MobileWorkspaceState();
}

class _MobileWorkspaceState extends ConsumerState<MobileWorkspace> {
  MobilePreferences preferences = const MobilePreferences();
  late final store =
      widget.preferenceStore ?? MobilePreferenceStore.forActiveProfile();
  final search = TextEditingController();
  bool searching = false, editing = false;
  String? pendingLink;
  DateTime? calendarDay;

  @override
  void initState() {
    super.initState();
    unawaited(loadPreferences());
    if (Platform.isAndroid) {
      AndroidPlatform.channel.setMethodCallHandler((call) async {
        if (call.method == 'openLink') {
          pendingLink = call.arguments as String;
          await deliverLink();
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        pendingLink = await AndroidPlatform.channel.invokeMethod<String>(
          'initialLink',
        );
        await deliverLink();
      });
    }
  }

  Future<void> loadPreferences() async {
    try {
      final loaded = await store.load();
      if (!mounted) return;
      setState(() => preferences = loaded);
      ref.read(appControllerProvider).navigate(loaded.start);
    } catch (error) {
      if (mounted) message('Mobile preferences could not be read: $error');
    }
  }

  @override
  void dispose() {
    search.dispose();
    if (Platform.isAndroid) AndroidPlatform.channel.setMethodCallHandler(null);
    super.dispose();
  }

  void message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) message('Could not finish: $error');
    }
  }

  Future<void> dialog(Widget child) async {
    editing = true;
    try {
      await showDialog<void>(context: context, builder: (_) => child);
    } finally {
      editing = false;
      if (mounted) await deliverSelection();
    }
  }

  Future<void> task([LifeTask? value, DateTime? day]) async {
    if (editing) return;
    editing = true;
    ref.read(appControllerProvider).select(null);
    try {
      await openMobileEditor(
        context,
        (route) => TaskEditor(
          task: value,
          initialScheduled: day,
          protectUnsavedEdits: true,
          onSaved: () => Navigator.pop(route),
          onCancel: () => Navigator.pop(route),
        ),
      );
    } finally {
      editing = false;
      if (mounted) await deliverLink();
    }
  }

  Future<void> deliverSelection() async {
    final controller = ref.read(appControllerProvider);
    final selected = controller.selectedTask;
    if (selected != null && !editing) await task(selected);
    if (mounted) await deliverLink();
  }

  Future<void> deliverLink() async {
    if (!mounted ||
        editing ||
        pendingLink == null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final raw = pendingLink!;
    pendingLink = null;
    await run(() async {
      final uri = Uri.parse(raw);
      if (raw.length > 4096 ||
          uri.scheme != 'todorbit' ||
          ![
            'add',
            'task',
            'tasks',
            'calendar',
            'event',
            'session',
          ].contains(uri.host)) {
        throw const FormatException('Unsupported link');
      }
      final controller = ref.read(appControllerProvider);
      await controller.refresh();
      if (!mounted) return;
      if (uri.host == 'add') {
        await task();
        return;
      }
      if (uri.host == 'tasks') {
        controller.navigate(WorkspaceView.today);
        return;
      }
      if (uri.host == 'task') {
        final value = controller.tasks
            .where((t) => t.id == uri.queryParameters['id'])
            .firstOrNull;
        if (value == null) throw StateError('Task is no longer available');
        await task(value);
      } else {
        final day = DateUtils.dateOnly(
          DateTime.parse(
            uri.queryParameters['day'] ?? localDate(DateTime.now()),
          ),
        );
        setState(() => calendarDay = day);
        controller.navigate(WorkspaceView.calendar);
        if (uri.host == 'event') {
          final events = await controller.repository.eventOccurrences(
            localDate(day),
            localDate(DateTime(day.year, day.month, day.day + 1)),
          );
          final value = events
              .where(
                (e) =>
                    e.id == uri.queryParameters['id'] &&
                    e.nominalDate == uri.queryParameters['nominal'],
              )
              .firstOrNull;
          if (value == null) {
            throw StateError('Event occurrence is no longer available');
          }
          if (!mounted) return;
          editing = true;
          try {
            await openMobileEditor(
              context,
              (route) => EventEditor(
                protectUnsavedEdits: true,
                event: value,
                initialDay: day,
                onClose: () => Navigator.pop(route),
              ),
            );
          } finally {
            editing = false;
          }
        } else if (uri.host == 'session') {
          final value = controller.sessions
              .where((s) => s.id == uri.queryParameters['id'])
              .firstOrNull;
          if (value == null) throw StateError('Session is no longer available');
          if (!mounted) return;
          editing = true;
          try {
            await openMobileEditor(
              context,
              (route) => SessionEditor(
                protectUnsavedEdits: true,
                session: value,
                initialDay: day,
                onClose: () => Navigator.pop(route),
              ),
            );
          } finally {
            editing = false;
          }
        }
      }
    });
    if (Platform.isAndroid) {
      await AndroidPlatform.channel.invokeMethod<void>('ackLink', raw);
    }
    if (mounted && pendingLink != null) await deliverLink();
  }

  String title(AppController c) => switch (c.view) {
    WorkspaceView.category =>
      c.categories.where((v) => v.id == c.scopeId).firstOrNull?.name ??
          'Category',
    WorkspaceView.project =>
      c.projects.where((v) => v.id == c.scopeId).firstOrNull?.name ?? 'Project',
    WorkspaceView.saved =>
      c.savedViews.where((v) => v.id == c.scopeId).firstOrNull?.name ??
          'Saved view',
    WorkspaceView.reports => 'Statistics',
    WorkspaceView.contributors => 'Contributors',
    _ => sidebarName(c.view),
  };

  void navigate(WorkspaceView view, {String? id}) {
    search.clear();
    setState(() => searching = false);
    ref.read(appControllerProvider).navigate(view, id: id);
    if (view == WorkspaceView.today) {
      unawaited(
        run(
          () => ref
              .read(appControllerProvider)
              .ensureRecurringMonth(DateTime.now()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final selected = preferences.destinations.indexOf(c.view);
    final tablet = MediaQuery.sizeOf(context).width >= 720;
    Widget content = switch (c.view) {
      WorkspaceView.calendar => MobileCalendar(
        key: ValueKey(calendarDay),
        initialDay: calendarDay,
        openTask: (t) => task(t),
        addTask: (d) => task(null, d),
        onEditorClosed: deliverLink,
      ),
      WorkspaceView.habits => const HabitsView(),
      WorkspaceView.goals => const GoalsView(),
      WorkspaceView.reports => const ReportsView(),
      WorkspaceView.contributors => const ContributorsView(),
      _ => taskList(c),
    };
    if (tablet) {
      content = Row(
        children: [
          NavigationRail(
            selectedIndex: selected < 0 ? null : selected,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => navigate(preferences.destinations[i]),
            destinations: [
              for (final d in preferences.destinations)
                NavigationRailDestination(
                  icon: Icon(sidebarIcon(d)),
                  label: Text(
                    d == WorkspaceView.all ? 'Tasks' : sidebarName(d),
                  ),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: searching
            ? TextField(
                controller: search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tasks',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(title(c)),
        actions: [
          IconButton(
            tooltip: searching ? 'Close search' : 'Search tasks',
            onPressed: () => setState(() {
              searching = !searching;
              if (!searching) {
                search.clear();
              } else {
                c.navigate(WorkspaceView.all);
              }
            }),
            icon: Icon(searching ? Icons.close : Icons.search),
          ),
          PopupMenuButton<String>(
            tooltip: 'Workspace actions',
            onSelected: (value) {
              if (value == 'filters') dialog(const AdvancedSearchDialog());
              if (value == 'reschedule') {
                dialog(
                  SmartRescheduleDialog(
                    scope: title(c),
                    taskIds: c.visibleTasks
                        .where((t) => t.isOpen)
                        .map((t) => t.id)
                        .toList(),
                  ),
                );
              }
              if (value.startsWith('sort:')) {
                c.setSort(TaskSort.values.byName(value.substring(5)));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'filters',
                child: Text('Filters and saved views'),
              ),
              const PopupMenuItem(
                value: 'reschedule',
                child: Text('Smart Reschedule'),
              ),
              for (final sort in TaskSort.values)
                CheckedPopupMenuItem(
                  value: 'sort:${sort.name}',
                  checked: sort == c.sort,
                  child: Text('Sort by ${sort.name}'),
                ),
            ],
          ),
        ],
      ),
      drawer: drawer(c),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (c.activeTimer case final timer?)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(
                    c.tasks
                            .where((t) => t.id == timer.taskId)
                            .firstOrNull
                            ?.title ??
                        'Active timer',
                  ),
                  subtitle: Text(
                    timer.needsReview(DateTime.now())
                        ? 'Interrupted timer needs review'
                        : 'Timer ${timer.state.name}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: timer.taskId == null
                      ? null
                      : () => dialog(TimeTrackingDialog(taskId: timer.taskId!)),
                ),
              ),
            if (pendingLink != null)
              ListTile(
                title: const Text('Requested item waiting'),
                trailing: TextButton(
                  onPressed: deliverLink,
                  child: const Text('Open'),
                ),
              ),
            Expanded(child: content),
          ],
        ),
      ),
      bottomNavigationBar: tablet
          ? null
          : NavigationBar(
              selectedIndex: selected < 0 ? 0 : selected,
              onDestinationSelected: (i) =>
                  navigate(preferences.destinations[i]),
              destinations: [
                for (final d in preferences.destinations)
                  NavigationDestination(
                    icon: Icon(sidebarIcon(d)),
                    label: d == WorkspaceView.all ? 'Tasks' : sidebarName(d),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New task',
        onPressed: () => task(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget taskList(AppController c) {
    final today = localDate(DateTime.now());
    final tasks = c.visibleTasks
        .where(
          (t) =>
              search.text.isEmpty ||
              '${t.title} ${t.notes}'.toLowerCase().contains(
                search.text.toLowerCase(),
              ),
        )
        .toList();
    final overdue = c.tasks
        .where(
          (t) =>
              t.isOpen &&
              t.deadlineDate != null &&
              t.deadlineDate!.compareTo(today) < 0,
        )
        .length;
    final todayTasks = c.tasks.where((t) => t.scheduledDate == today).toList();
    final done = todayTasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final sessions =
        c.sessions
            .where((s) => localDate(s.startsAt.toLocal()) == today)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final events = c.events
        .where(
          (e) =>
              !e.cancelled &&
              e.startsAt.toLocal().isBefore(
                DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day + 1,
                ),
              ) &&
              e.endsAt.toLocal().isAfter(DateUtils.dateOnly(DateTime.now())),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: () => c.refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: tasks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (c.view == WorkspaceView.today) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MaterialLocalizations.of(context)
                                .formatFullDate(DateTime.now()),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Make room for what matters',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$done of ${todayTasks.length} planned tasks complete',
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: todayTasks.isEmpty
                                ? 0
                                : done / todayTasks.length,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (overdue > 0)
                    ListTile(
                      leading: const Icon(
                        Icons.notification_important_outlined,
                      ),
                      title: Text(
                        '$overdue overdue ${overdue == 1 ? 'task' : 'tasks'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => navigate(WorkspaceView.overdue),
                    ),
                  if (events.isNotEmpty || sessions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'On your calendar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final e in events)
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(e.title),
                        subtitle: Text(
                          e.allDay
                              ? 'All day'
                              : TimeOfDay.fromDateTime(e.startsAt.toLocal())
                                    .format(context),
                        ),
                        onTap: () {
                          pendingLink = Uri(
                            scheme: 'todorbit',
                            host: 'event',
                            queryParameters: {
                              'id': e.id,
                              'day': today,
                              if (e.nominalDate != null)
                                'nominal': e.nominalDate!,
                            },
                          ).toString();
                          deliverLink();
                        },
                      ),
                    for (final s in sessions)
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(
                          c.tasks
                                  .where((t) => t.id == s.taskId)
                                  .firstOrNull
                                  ?.title ??
                              'Work session',
                        ),
                        subtitle: Text(
                          '${TimeOfDay.fromDateTime(s.startsAt.toLocal()).format(context)} · ${s.outcome.name}',
                        ),
                        onTap: () {
                          pendingLink = Uri(
                            scheme: 'todorbit',
                            host: 'session',
                            queryParameters: {'id': s.id, 'day': today},
                          ).toString();
                          deliverLink();
                        },
                      ),
                  ],
                ],
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 40),
                        SizedBox(height: 12),
                        Text('No tasks here yet'),
                        SizedBox(height: 8),
                        Text('Use + to add a task.'),
                      ],
                    ),
                  ),
              ],
            );
          }
          final t = tasks[index - 1];
          final category = c.categories
              .where((v) => v.id == t.categoryId)
              .firstOrNull
              ?.name;
          final project = c.projects
              .where((v) => v.id == t.projectId)
              .firstOrNull
              ?.name;
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 4,
                end: 4,
              ),
              leading: Checkbox(
                value: t.status == TaskStatus.completed,
                semanticLabel: 'Complete ${t.title}',
                onChanged: (v) => run(() => c.setComplete(t, v == true)),
              ),
              title: Text(
                t.title,
                style: t.status == TaskStatus.completed
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              subtitle: Text(
                [
                  if (t.priority > 0) 'Priority ${t.priority}',
                  if (t.status != TaskStatus.notStarted) t.status.name,
                  if (t.scheduledDate != null)
                    'Planned ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(t.scheduledDate!))}',
                  if (t.deadlineDate != null)
                    'Due ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(t.deadlineDate!))}',
                  ?category,
                  ?project,
                ].join(' · '),
              ),
              onTap: () => task(t),
              onLongPress: () => actions(t, c),
              trailing: IconButton(
                tooltip: 'Actions for ${t.title}',
                icon: const Icon(Icons.more_vert),
                onPressed: () => actions(t, c),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> actions(LifeTask t, AppController c) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              t.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final entry in const {
            'edit': 'Edit task',
            'reschedule': 'Reschedule',
            'timer': 'Actual work and timer',
            'duplicate': 'Duplicate',
            'archive': 'Archive',
            'delete': 'Move to Trash',
          }.entries)
            ListTile(
              title: Text(entry.value),
              onTap: () => Navigator.pop(context, entry.key),
            ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'edit':
        await task(t);
      case 'reschedule':
        await dialog(SmartRescheduleDialog(scope: t.title, taskIds: [t.id]));
      case 'timer':
        await dialog(TimeTrackingDialog(taskId: t.id));
      case 'archive':
        await run(() => c.archiveTask(t));
      case 'delete':
        await run(() => c.deleteTask(t.id));
      case 'duplicate':
        await run(
          () => c.addTask(
            TaskDraft(
              title: '${t.title} (copy)',
              notes: t.notes,
              priority: t.priority,
              categoryId: t.categoryId,
              projectId: t.projectId,
              scheduledDate: t.scheduledDate,
              deadlineDate: t.deadlineDate,
              plannedDurationMinutes: t.plannedDurationMinutes,
              remainingWorkMinutes: t.remainingWorkMinutes,
            ),
          ),
        );
    }
  }

  Widget drawer(AppController c) => Drawer(
    child: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Todorbit',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          for (final v in AppController.defaultSidebarOrder)
            ListTile(
              leading: Icon(sidebarIcon(v)),
              title: Text(sidebarName(v)),
              selected: c.view == v,
              onTap: () {
                Navigator.pop(context);
                navigate(v);
              },
            ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Statistics'),
            onTap: () {
              Navigator.pop(context);
              navigate(WorkspaceView.reports);
            },
          ),
          const Divider(),
          for (final category in c.categories)
            ExpansionTile(
              title: Text(category.name),
              leading: Icon(
                iconForKey(
                  c.iconKeys['category:${category.id}'],
                  Icons.folder_outlined,
                ),
              ),
              children: [
                ListTile(
                  title: const Text('All category tasks'),
                  onTap: () {
                    Navigator.pop(context);
                    navigate(WorkspaceView.category, id: category.id);
                  },
                ),
                for (final project in c.projects.where(
                  (p) => p.categoryId == category.id,
                ))
                  ListTile(
                    leading: const Icon(Icons.folder_open_outlined),
                    title: Text(project.name),
                    onTap: () {
                      Navigator.pop(context);
                      navigate(WorkspaceView.project, id: project.id);
                    },
                  ),
              ],
            ),
          for (final saved in c.savedViews)
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text(saved.name),
              onTap: () {
                Navigator.pop(context);
                navigate(WorkspaceView.saved, id: saved.id);
              },
              trailing: IconButton(
                tooltip: 'Edit saved view',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.pop(context);
                  dialog(AdvancedSearchDialog(savedView: saved));
                },
              ),
            ),
          ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: const Text('Manage projects and categories'),
            onTap: () {
              Navigator.pop(context);
              organization(c);
            },
          ),
          ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('Search and saved views'),
            onTap: () {
              Navigator.pop(context);
              dialog(const AdvancedSearchDialog());
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Templates and routines'),
            onTap: () {
              Navigator.pop(context);
              dialog(const TemplatesDialog());
            },
          ),
          ListTile(
            leading: const Icon(Icons.linear_scale),
            title: const Text('Task sequences'),
            onTap: () {
              Navigator.pop(context);
              dialog(const SequenceDialog());
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Availability'),
            onTap: () {
              Navigator.pop(context);
              dialog(const AvailabilityDialog());
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Scheduling history'),
            onTap: () {
              Navigator.pop(context);
              dialog(const ScheduleHistoryDialog());
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Archive and Trash'),
            onTap: () {
              Navigator.pop(context);
              dialog(const ArchiveTrashDialog());
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () async {
              Navigator.pop(context);
              editing = true;
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileSettings(
                    store: store,
                    preferences: preferences,
                    onChanged: (p) => setState(() => preferences = p),
                  ),
                ),
              );
              editing = false;
              if (mounted) await deliverLink();
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Contributors'),
            onTap: () {
              Navigator.pop(context);
              navigate(WorkspaceView.contributors);
            },
          ),
        ],
      ),
    ),
  );

  Future<void> organization(AppController c) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(appControllerProvider);
          return FractionallySizedBox(
            heightFactor: .85,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Projects and categories',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('New category'),
                  onTap: () async {
                    final name = await showDialog<String>(
                      context: context,
                      builder: (_) => const TextPromptDialog(
                        title: 'New category',
                        label: 'Name',
                      ),
                    );
                    if (name != null && name.trim().isNotEmpty) {
                      await run(() => c.addCategory(name));
                    }
                  },
                ),
                for (final category in current.categories)
                  ExpansionTile(
                    title: Text(category.name),
                    children: [
                      ListTile(
                        title: const Text('Category icon'),
                        leading: const Icon(Icons.interests_outlined),
                        onTap: () async {
                          final selected = await chooseBuiltInIcon(
                            context,
                            current:
                                current.iconKeys['category:${category.id}'],
                          );
                          if (selected.$1) {
                            await run(
                              () => c.setIcon(
                                'category',
                                category.id,
                                selected.$2,
                              ),
                            );
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('Category event color'),
                        subtitle: Text(eventColorLabel(category.eventColor)),
                        leading: const Icon(Icons.palette_outlined),
                        onTap: () async {
                          final color = await chooseEventColor(
                            context,
                            category.eventColor ??
                                Theme.of(context).colorScheme.primary
                                    .toARGB32(),
                          );
                          if (color != null) {
                            await run(
                              () => c.setCategoryEventColor(category.id, color),
                            );
                          }
                        },
                      ),
                      if (category.eventColor != null)
                        ListTile(
                          title: const Text('Use default event color'),
                          onTap: () => run(
                            () => c.setCategoryEventColor(category.id, null),
                          ),
                        ),
                      ListTile(
                        title: const Text('Rename category'),
                        onTap: () async {
                          final name = await showDialog<String>(
                            context: context,
                            builder: (_) => TextPromptDialog(
                              title: 'Rename category',
                              initial: category.name,
                            ),
                          );
                          if (name != null && name.trim().isNotEmpty) {
                            await run(
                              () => c.renameCategory(category.id, name),
                            );
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('New project'),
                        leading: const Icon(Icons.add),
                        onTap: () async {
                          final name = await showDialog<String>(
                            context: context,
                            builder: (_) => const TextPromptDialog(
                              title: 'New project',
                              label: 'Name',
                            ),
                          );
                          if (name != null && name.trim().isNotEmpty) {
                            await run(() => c.addProject(category.id, name));
                          }
                        },
                      ),
                      for (final p in current.projects.where(
                        (p) => p.categoryId == category.id,
                      ))
                        ListTile(
                          title: Text(p.name),
                          subtitle: const Text('Tap to rename'),
                          onTap: () async {
                            final name = await showDialog<String>(
                              context: context,
                              builder: (_) => TextPromptDialog(
                                title: 'Rename project',
                                initial: p.name,
                              ),
                            );
                            if (name != null && name.trim().isNotEmpty) {
                              await run(() => c.renameProject(p.id, name));
                            }
                          },
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Project actions',
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'icon',
                                child: Text('Project icon'),
                              ),
                              PopupMenuItem(
                                value: 'template',
                                child: Text('Save project template'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete empty project'),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'delete') {
                                await run(() => c.deleteProject(p.id));
                              }
                              if (value == 'template') {
                                if (context.mounted) {
                                  await showSaveTemplateDialog(
                                    context,
                                    sourceName: p.name,
                                    save: (name) =>
                                        c.saveProjectTemplate(p, name),
                                  );
                                }
                              }
                              if (value == 'icon') {
                                if (!context.mounted) return;
                                final selected = await chooseBuiltInIcon(
                                  context,
                                  current: current.iconKeys['project:${p.id}'],
                                );
                                if (selected.$1) {
                                  await run(
                                    () =>
                                        c.setIcon('project', p.id, selected.$2),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ListTile(
                        title: const Text('Delete empty category'),
                        onTap: () => run(() => c.deleteCategory(category.id)),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
