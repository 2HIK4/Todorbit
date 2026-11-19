import '../time_tracking/compact_task_timer.dart';
import '../time_tracking/task_timer_intent.dart';
import '../../domain/alarm_plan.dart';
import '../shared/alarm_indicator.dart';
import '../shared/app_motion.dart';
import '../support/support_button.dart';
import '../shared/item_filters.dart';
import '../settings/sidebar_order_dialog.dart';
import '../settings/sync_conflicts_dialog.dart';
import '../settings/sync_settings_page.dart';
import '../../domain/task_list_projection.dart';
import '../shared/task_list_group.dart';
import '../shared/scroll_edge_fade.dart';
import '../shared/status_snackbar.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/mobile_preference_store.dart';
import '../../domain/models.dart';
import '../../data/life_repository.dart';
import '../../platform/android/android_platform.dart';
import '../../platform/android/android_widget_action.dart';
import '../calendar/event_editor.dart';
import '../calendar/session_editor.dart';
import '../contributors/contributors_view.dart';
import '../goals/goals_view.dart';
import '../habits/habits_view.dart';
import '../reports/reports_view.dart';
import '../scheduling/smart_reschedule.dart';
import '../search/advanced_search_dialog.dart';
import '../shared/sidebar_items.dart';
import '../shared/sync_status_button.dart';
import '../shared/text_prompt_dialog.dart';
import '../shared/icon_picker.dart';
import '../shared/event_color_picker.dart';
import '../templates/templates_dialog.dart';
import '../workspace/sequence_dialog.dart';
import '../workspace/task_editor.dart';
import '../workspace/trash_dialog.dart';
import '../workspace/task_details_view.dart';
import '../time_tracking/focus_workspace.dart';
import '../shared_inbox/shared_inbox_screen.dart';
import 'mobile_calendar.dart';
import 'mobile_settings.dart';
import 'mobile_ui.dart';

class MobileWorkspace extends ConsumerStatefulWidget {
  const MobileWorkspace({
    super.key,
    this.preferenceStore,
    this.locked = false,
    this.initialLink,
  });
  final MobilePreferenceStore? preferenceStore;
  final bool locked;
  final String? initialLink;
  @override
  ConsumerState<MobileWorkspace> createState() => _MobileWorkspaceState();
}

class _MobileWorkspaceState extends ConsumerState<MobileWorkspace> {
  MobilePreferences preferences = const MobilePreferences();
  late final store =
      widget.preferenceStore ?? MobilePreferenceStore.forActiveProfile();
  final search = TextEditingController();
  bool searching = false, editing = false, delivering = false;
  bool preferencesReady = false;
  bool supportAvailable = !Platform.isAndroid;
  String? pendingLink;
  DateTime? calendarDay;

  Future<void> loadDistribution() async {
    try {
      final info = await AndroidPlatform.channel
          .invokeMapMethod<String, dynamic>('updateInfo');
      if (mounted) {
        setState(() => supportAvailable = info?['distribution'] == 'github');
      }
    } catch (_) {
      /* Store/unknown distributions retain non-payment support. */
    }
  }

  @override
  void initState() {
    super.initState();
    pendingLink = widget.initialLink;
    unawaited(loadPreferences());
    if (Platform.isAndroid) unawaited(loadDistribution());
    if (Platform.isAndroid) {
      AndroidPlatform.channel.setMethodCallHandler((call) async {
        if (call.method == 'openLink') {
          pendingLink = call.arguments as String;
          await deliverLink();
        } else if (call.method == 'sharedInboxUpdated') {
          if (mounted) message('New file(s) received in Shared Inbox');
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final initial = await AndroidPlatform.channel.invokeMethod<String>(
          'initialLink',
        );
        pendingLink ??= initial;
        await deliverLink();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MobileWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLink != widget.initialLink &&
        widget.initialLink != null) {
      pendingLink = widget.initialLink;
    }
    if (oldWidget.initialLink != widget.initialLink ||
        (oldWidget.locked && !widget.locked)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => deliverLink());
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
    } finally {
      preferencesReady = true;
      if (mounted) await deliverLink();
    }
  }

  @override
  void dispose() {
    search.dispose();
    if (Platform.isAndroid) AndroidPlatform.channel.setMethodCallHandler(null);
    super.dispose();
  }

  void message(String value) => showTransientStatus(context, value);

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
      await showDialog<void>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (_) => child,
      );
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

  Future<void> openEvent(FixedEvent value) async {
    if (editing || widget.locked) return;
    editing = true;
    try {
      await openMobileEditor(
        context,
        (route) => EventEditor(
          event: value,
          initialDay: value.startsAt.toLocal(),
          protectUnsavedEdits: true,
          onClose: () => Navigator.pop(route),
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
        delivering ||
        widget.locked ||
        !preferencesReady ||
        pendingLink == null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final raw = pendingLink!;
    delivering = true;
    setState(() => pendingLink = null);
    try {
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
              'add-event',
              'widget-action',
            ].contains(uri.host)) {
          throw const FormatException('Unsupported link');
        }
        final controller = ref.read(appControllerProvider);
        await controller.refresh();
        if (!mounted) return;
        if (uri.host == 'widget-action') {
          final command = await AndroidPlatform.channel
              .invokeMapMethod<String, dynamic>('claimWidgetAction', raw);
          if (command == null) {
            throw StateError(
              'Widget action expired. Try again from the widget.',
            );
          }
          if (widget.locked) throw StateError('Unlock Todorbit to continue');
          await applyAndroidWidgetAction(controller, command);
          if (mounted) {
            message(
              command['complete'] == true ? 'Task completed' : 'Task reopened',
            );
          }
          return;
        }
        if (uri.host == 'add') {
          await task();
          return;
        }
        if (uri.host == 'tasks') {
          controller.navigate(switch (uri.queryParameters['filter']) {
            'all' => WorkspaceView.all,
            'inbox' => WorkspaceView.inbox,
            _ => WorkspaceView.today,
          });
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
          if (uri.host == 'add-event') {
            editing = true;
            try {
              await openMobileEditor(
                context,
                (route) => EventEditor(
                  protectUnsavedEdits: true,
                  initialDay: day,
                  onClose: () => Navigator.pop(route),
                ),
              );
            } finally {
              editing = false;
            }
          } else if (uri.host == 'event') {
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
            if (value == null) {
              throw StateError('Session is no longer available');
            }
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
    } finally {
      delivering = false;
      if (Platform.isAndroid) {
        await AndroidPlatform.channel.invokeMethod<void>('ackLink', raw);
      }
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
    setState(() {
      searching = false;
      if (view == WorkspaceView.calendar) {
        calendarDay = null;
      }
    });
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
            ? Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(
                      Icons.search,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: search,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search tasks and events',
                          hintStyle: TextStyle(fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (search.text.isNotEmpty)
                      IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Clear search text',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Advanced search & filters',
                      icon: const Icon(Icons.tune_outlined),
                      onPressed: () => dialog(const AdvancedSearchDialog()),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              )
            : Text(title(c)),
        actions: [
          if (!searching) ...[
            SyncStatusButton(
              allowAutomatic: true,
              onOpenSettings: showSyncSettings,
              onOpenConflicts: showSyncConflicts,
            ),
            PopupMenuButton<String>(
              tooltip: 'Library',
              icon: const Icon(Icons.collections_bookmark_outlined),
              onSelected: (value) {
                if (value == 'templates') dialog(const TemplatesDialog());
                if (value == 'sequences') dialog(const SequenceDialog());
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'templates',
                  child: Row(
                    children: [
                      Icon(Icons.copy_all_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Templates and routines'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'sequences',
                  child: Row(
                    children: [
                      Icon(Icons.linear_scale, size: 20),
                      SizedBox(width: 12),
                      Text('Task sequences'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          IconButton(
            tooltip: searching ? 'Close search' : 'Search tasks and events',
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
          if (!searching)
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
            if (c.activeTimer != null)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: CompactTaskTimer(open: openFocus),
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
          : Builder(
              builder: (context) => NavigationBar(
                selectedIndex: selected < 0
                    ? preferences.destinations.length
                    : selected,
                onDestinationSelected: (i) {
                  if (i == preferences.destinations.length) {
                    Scaffold.of(context).openDrawer();
                  } else {
                    navigate(preferences.destinations[i]);
                  }
                },
                destinations: [
                  for (final d in preferences.destinations)
                    NavigationDestination(
                      icon: Icon(sidebarIcon(d)),
                      label: d == WorkspaceView.all ? 'Tasks' : sidebarName(d),
                    ),
                  const NavigationDestination(
                    icon: Icon(Icons.menu),
                    label: 'More',
                  ),
                ],
              ),
            ),
      floatingActionButton: c.view == WorkspaceView.calendar
          ? null
          : FloatingActionButton(
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
    final groups = projectTaskList(
      tasks,
      c.taskParents,
      groupRecurrence: c.view == WorkspaceView.all && search.text.isEmpty,
      relatedOccurrences:
          c.view == WorkspaceView.all &&
              search.text.isEmpty &&
              !c.activeFilter.isActive
          ? c.tasks
          : const [],
    );
    final scopedEvents =
        {
              WorkspaceView.project,
              WorkspaceView.category,
              WorkspaceView.saved,
            }.contains(c.view) ||
            searching && search.text.trim().isNotEmpty
        ? c.filteredEvents
              .where(
                (e) =>
                    !e.cancelled &&
                    (search.text.isEmpty ||
                        '${e.title} ${e.notes} ${c.categories.where((v) => v.id == e.categoryId).firstOrNull?.name ?? ''} ${c.projects.where((v) => v.id == e.projectId).firstOrNull?.name ?? ''}'
                            .toLowerCase()
                            .contains(search.text.toLowerCase())),
              )
              .toList()
        : <FixedEvent>[];
    final overdue = c.filteredTasks
        .where(
          (t) =>
              t.isOpen &&
              t.deadlineDate != null &&
              t.deadlineDate!.compareTo(today) < 0,
        )
        .length;
    final todayTasks = c.filteredTasks
        .where((t) => t.scheduledDate == today)
        .toList();
    final done = todayTasks
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final sessions =
        c.filteredSessions
            .where((s) => localDate(s.startsAt.toLocal()) == today)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final events = c.filteredEvents
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
      child: FadingListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: groups.length + scopedEvents.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ItemFilters(),
                if (c.isStandardView(c.view) && c.hiddenStandardTasksCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${c.hiddenStandardTasksCount} tasks hidden by category or project settings',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if ({
                      WorkspaceView.project,
                      WorkspaceView.category,
                      WorkspaceView.saved,
                    }.contains(c.view) ||
                    searching && search.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Events: ${c.eventWindowLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (c.view == WorkspaceView.today) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      '$done of ${todayTasks.length} planned tasks complete',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                        onTap: () => openEvent(e),
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
                if (c.view != WorkspaceView.today && tasks.isNotEmpty)
                  MobileSectionTitle(
                    '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                    subtitle: searching
                        ? 'Matching your search'
                        : 'Tap a task for details; check it off when finished',
                  ),
                if (tasks.isEmpty && scopedEvents.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          (c.activeFilter.isActive ||
                                  searching && search.text.isNotEmpty)
                              ? 'No matching tasks'
                              : 'No tasks here yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (c.activeFilter.isActive ||
                                  searching && search.text.isNotEmpty)
                              ? 'Change the filters or clear your search.'
                              : 'A little space for what comes next.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => task(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add task'),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }
          if (index <= scopedEvents.length) {
            final event = scopedEvents[index - 1];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                trailing:
                    eventAlarmRule(event, c.alarmRules)?.config.enabled == true
                    ? const AlarmIndicator()
                    : null,
                title: Text(event.title),
                subtitle: Text(localDate(event.startsAt.toLocal())),
                onTap: () => openEvent(event),
              ),
            );
          }
          return TaskListGroupView(
            group: groups[index - 1 - scopedEvents.length],
            items: tasks,
            parents: c.taskParents,
            row: (t) => mobileTaskRow(t, c),
            subtaskRow: (t) => mobileSubtaskRow(t, c),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          );
        },
      ),
    );
  }

  Widget mobileTaskRow(LifeTask t, AppController c) {
    final category = c.categories
        .where((v) => v.id == t.categoryId)
        .firstOrNull
        ?.name;
    final project = c.projects
        .where((v) => v.id == t.projectId)
        .firstOrNull
        ?.name;
    final today = localDate(DateTime.now());
    final isOverdue =
        t.isOpen &&
        t.deadlineDate != null &&
        t.deadlineDate!.compareTo(today) < 0;

    final subtitleParts = <InlineSpan>[];
    void addPart(InlineSpan span) {
      if (subtitleParts.isNotEmpty) {
        subtitleParts.add(const TextSpan(text: ' · '));
      }
      subtitleParts.add(span);
    }

    if (t.priority > 0) {
      addPart(TextSpan(text: 'Priority ${t.priority}'));
    }
    if (t.status != TaskStatus.notStarted) {
      addPart(TextSpan(text: t.status.name));
    }
    if (t.scheduledDate != null) {
      addPart(
        TextSpan(
          text:
              'Planned ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(t.scheduledDate!))}',
        ),
      );
    }
    if (t.deadlineDate != null) {
      final formatted = MaterialLocalizations.of(context)
          .formatMediumDate(DateTime.parse(t.deadlineDate!));
      addPart(
        TextSpan(
          text: isOverdue ? 'Overdue · Due $formatted' : 'Due $formatted',
          style: isOverdue
              ? TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                )
              : null,
        ),
      );
    }
    if (category != null) addPart(TextSpan(text: category));
    if (project != null) addPart(TextSpan(text: project));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsetsDirectional.only(start: 6, end: 8),
          leading: Checkbox(
            value: t.status == TaskStatus.completed,
            semanticLabel:
                '${t.status == TaskStatus.completed ? 'Reopen' : 'Complete'} ${t.title}',
            onChanged: (v) => run(() => c.setComplete(t, v == true)),
          ),
          title: Text(
            t.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.status == TaskStatus.completed
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: subtitleParts.isEmpty
              ? null
              : Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    children: subtitleParts,
                  ),
                ),
          onTap: () => openTaskDetails(t),
          onLongPress: () => actions(t, c),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOverdue)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                    semanticLabel: 'Overdue',
                  ),
                ),
              if (t.isOpen &&
                  taskAlarmRule(t, c.alarmRules)?.config.enabled == true)
                const AlarmIndicator(),
              IconButton(
                tooltip: 'Actions for ${t.title}',
                icon: const Icon(Icons.more_vert),
                onPressed: () => actions(t, c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget mobileSubtaskRow(LifeTask t, AppController c) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = t.status == TaskStatus.completed;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openTaskDetails(t),
        onLongPress: () => actions(t, c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: done,
                semanticLabel: '${done ? 'Reopen' : 'Complete'} ${t.title}',
                onChanged: (v) => run(() => c.setComplete(t, v == true)),
              ),
              Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: 16,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: done
                      ? const TextStyle(
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        )
                      : const TextStyle(fontSize: 14),
                ),
              ),
              IconButton(
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                tooltip: 'Actions for ${t.title}',
                icon: const Icon(Icons.more_vert),
                onPressed: () => actions(t, c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openTaskDetails(LifeTask t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailsView(
          task: t,
          onBack: () => Navigator.pop(context),
          onEdit: () => task(
            ref
                .read(appControllerProvider)
                .tasks
                .firstWhere((current) => current.id == t.id),
          ),
          onStartFocus: () => openTaskTimer(
            context,
            ref.read(appControllerProvider),
            t.id,
            open: (taskId) {
              Navigator.pop(context);
              _showFocus(taskId);
            },
          ),
        ),
      ),
    );
  }

  Future<void> openFocus(String taskId) => openTaskTimer(
    context,
    ref.read(appControllerProvider),
    taskId,
    open: _showFocus,
  );

  void _showFocus(String taskId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusWorkspace(
          taskId: taskId,
          onBack: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> actions(LifeTask t, AppController c) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: AppMotion.style(context),
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FadingListView(
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
        openFocus(t.id);
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
      child: FadingListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Todorbit',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          for (final v in c.sidebarOrder.where(
            (v) => !c.hiddenNavigation.contains(v.name),
          ))
            ListTile(
              leading: Icon(sidebarIcon(v)),
              title: Text(sidebarName(v)),
              selected: c.view == v,
              onTap: () {
                Navigator.pop(context);
                navigate(v);
              },
            ),
          if (!c.hiddenNavigation.contains('reports'))
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
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'CUSTOM VIEWS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final saved in c.orderedSavedViews.where(
            (v) => !c.hiddenNavigation.contains(v.id),
          ))
            ListTile(
              leading: Icon(iconForKey(saved.iconKey, Icons.bookmark_outline)),
              title: Text(saved.name),
              selected: c.view == WorkspaceView.saved && c.scopeId == saved.id,
              onTap: () {
                Navigator.pop(context);
                navigate(WorkspaceView.saved, id: saved.id);
              },
              trailing: PopupMenuButton<String>(
                tooltip: 'View options',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) async {
                  if (value == 'edit') {
                    Navigator.pop(context);
                    dialog(AdvancedSearchDialog(savedView: saved));
                  } else if (value == 'rename') {
                    Navigator.pop(context);
                    final name = await showDialog<String>(
                      context: context,
                      animationStyle: AppMotion.style(context),
                      builder: (_) => TextPromptDialog(
                        title: 'Rename custom view',
                        initial: saved.name,
                      ),
                    );
                    if (name != null && name.trim().isNotEmpty) {
                      await run(() => c.renameSavedView(saved, name.trim()));
                    }
                  } else if (value == 'duplicate') {
                    await run(() => c.duplicateSavedView(saved));
                  } else if (value == 'delete') {
                    await run(() => c.deleteSavedView(saved));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit filters')),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete view')),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add View'),
            onTap: () {
              Navigator.pop(context);
              dialog(const AdvancedSearchDialog());
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Customize navigation'),
            onTap: () {
              Navigator.pop(context);
              dialog(const SidebarOrderDialog());
            },
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
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: const Text('Support Todorbit'),
            onTap: () {
              Navigator.pop(context);
              dialog(
                supportAvailable
                    ? const SupportDialog()
                    : const ProjectSupportDialog(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_shared_outlined),
            title: const Text('Shared Files'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const SharedInboxScreen()),
              );
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
      sheetAnimationStyle: AppMotion.style(context),
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(appControllerProvider);
          return FractionallySizedBox(
            heightFactor: .85,
            child: FadingListView(
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
                      animationStyle: AppMotion.style(context),
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
                      SwitchListTile(
                        title: const Text('Show in standard views'),
                        subtitle: const Text(
                          'When off, tasks appear only in search and custom views',
                        ),
                        value: current.isCategoryShownInStandardViews(
                          category.id,
                        ),
                        onChanged: (_) => run(
                          () => c.toggleCategoryStandardVisibility(category.id),
                        ),
                      ),
                      ListTile(
                        title: const Text('Rename category'),
                        onTap: () async {
                          final name = await showDialog<String>(
                            context: context,
                            animationStyle: AppMotion.style(context),
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
                            animationStyle: AppMotion.style(context),
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
                              animationStyle: AppMotion.style(context),
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
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'icon',
                                child: Text('Project icon'),
                              ),
                              CheckedPopupMenuItem(
                                value: 'standard_views',
                                checked: current.isProjectShownInStandardViews(
                                  p.id,
                                ),
                                child: const Text('Show in standard views'),
                              ),
                              const PopupMenuItem(
                                value: 'template',
                                child: Text('Save project template'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete empty project'),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'standard_views') {
                                await run(
                                  () => c.toggleProjectStandardVisibility(p.id),
                                );
                              }
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
