import '../time_tracking/compact_task_timer.dart';
import '../../domain/time_tracking.dart';
import '../time_tracking/task_timer_intent.dart';
import '../../domain/alarm_plan.dart';
import '../shared/alarm_indicator.dart';
import '../shared/app_motion.dart';
import '../shared/item_filters.dart';
import '../shared/scroll_edge_fade.dart';
import '../../domain/task_list_projection.dart';
import '../shared/task_list_group.dart';

import 'dart:io';

import '../../data/private_test_environment.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../data/app_database.dart';
import '../../data/life_repository.dart';
import '../../domain/models.dart';
import '../../domain/navigation_request.dart';
import '../calendar/event_editor.dart';
import '../calendar/session_editor.dart';
import '../../domain/widget_configuration.dart';
import '../../domain/recurrence.dart';
import '../../domain/saved_views.dart';
import '../../domain/hotkeys.dart';
import '../branding/brand_mark.dart';
import '../calendar/calendar_view.dart';
import '../habits/habits_view.dart';
import '../goals/goals_view.dart';
import '../reports/reports_view.dart';
import '../shared/about_view_button.dart';
import '../shared/app_modal_shell.dart';
import '../shared/app_spacing.dart';
import '../shared/app_task_row.dart';
import '../shared/sync_status_button.dart';
import '../contributors/contributors_view.dart';
import '../templates/templates_dialog.dart';
import 'quick_search.dart';
import '../search/advanced_search_dialog.dart';
import '../settings/backup_dialog.dart';
import '../support/support_button.dart';
import '../settings/theme_dialog.dart';
import '../settings/settings_hub_dialog.dart';
import '../settings/widget_settings_page.dart';
import '../settings/sync_conflicts_dialog.dart';
import '../settings/sync_settings_page.dart';
import '../scheduling/smart_reschedule.dart';
import '../shared/icon_picker.dart';
import '../shared/event_color_picker.dart';
import '../shared/sidebar_items.dart';
import '../widget/native_widget_service.dart';
import 'task_editor.dart';
import 'sequence_dialog.dart';
import 'trash_dialog.dart';
import 'task_details_view.dart';
import '../time_tracking/focus_workspace.dart';

class Workspace extends ConsumerStatefulWidget {
  const Workspace({
    super.key,
    this.openAppearance = false,
    this.initialNavigation,
    this.editWidget,
    this.legacyImportFile,
  });

  final bool openAppearance;
  final String? initialNavigation;
  final DesktopWidgetKind? editWidget;
  final File? legacyImportFile;

  @override
  ConsumerState<Workspace> createState() => _WorkspaceState();
}

String _viewDescription(WorkspaceView view) => switch (view) {
  WorkspaceView.today => 'Tasks planned for today. Deadlines and scheduled work are tracked separately.',
  WorkspaceView.all => 'Tasks across your categories and projects. Completed tasks may remain visible if enabled in Task Preferences.',
  WorkspaceView.inbox => 'Tasks without a category or project.',
  WorkspaceView.anytime => 'Tasks without a planned day or deadline, ready to schedule whenever you choose.',
  WorkspaceView.upcoming =>
    'Tasks planned for a future day, regardless of deadline.',
  WorkspaceView.overdue =>
    'Tasks with a deadline before today, regardless of planned day.',
  WorkspaceView.waiting => 'Tasks marked Waiting or On hold.',
  WorkspaceView.completed =>
    'Completed and cancelled tasks remain here with their history.',
  WorkspaceView.category => 'Tasks assigned to this category.',
  WorkspaceView.project => 'Tasks assigned to this project.',
  WorkspaceView.saved => 'Tasks matching this saved search and its filters.',
  _ => 'Tasks in the current view.',
};

class _WorkspaceState extends ConsumerState<Workspace> {
  final categoryDisclosure = ExpansibleController();
  final _sidebarSearchQuery = TextEditingController();
  final _sidebarSearchFocus = FocusNode();
  Future<void> _chooseCategoryEventColor(Category category) async {
    final selected = await showDialog<int>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (context) => SimpleDialog(
        title: Text('Default event color for ${category.name}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('App default'),
          ),
          for (final color in eventColors)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, color.$2),
              child: Row(
                children: [
                  Icon(Icons.circle, color: Color(color.$2)),
                  const SizedBox(width: 8),
                  Text(color.$1),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, -1),
            child: const Text('Custom Color'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final color = selected == -1
        ? await chooseEventColor(context, category.eventColor ?? 0xFF5365B5)
        : selected == 0
        ? null
        : selected;
    if (selected == -1 && color == null) return;
    await ref
        .read(appControllerProvider)
        .setCategoryEventColor(category.id, color);
  }

  static const _activationChannel = MethodChannel('life_manager/activation');
  bool _appearanceDialogOpen = false;
  bool _widgetSettingsOpen = false;
  final _widgetSettingsController = WidgetSettingsController();
  NavigationRequest? pendingNavigation;
  DateTime? navigationDay;
  DateTime? _lastCalendarDate;
  bool navigating = false;
  void receiveNavigation(String payload) {
    try {
      final request = NavigationRequest.decode(payload);
      final current = ref.read(appControllerProvider).selectedTask;
      if (request.kind == 'task' && current?.id == request.id) return;
      setState(() => pendingNavigation = request);
      unawaited(deliverNavigation());
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cannot open widget item: $e')));
    }
  }

  bool get canOpenNavigation =>
      !creating &&
      !changingEditor &&
      _selectedEvent == null &&
      ref.read(appControllerProvider).selectedTask == null &&
      ModalRoute.of(context)?.isCurrent == true;
  bool deferIfEditing(NavigationRequest request) {
    if (canOpenNavigation) return false;
    setState(() => pendingNavigation ??= request);
    return true;
  }

  Future<void> deliverNavigation() async {
    final request = pendingNavigation;
    final controller = ref.read(appControllerProvider);
    if (request == null || navigating || !canOpenNavigation) {
      return;
    }
    navigating = true;
    setState(() => pendingNavigation = null);
    try {
      await controller.refresh();
      if (!mounted || deferIfEditing(request)) return;
      if (request.kind == 'task') {
        if (!controller.tasks.any((t) => t.id == request.id)) {
          throw StateError('Task is no longer available');
        }
        controller.navigate(WorkspaceView.all);
        controller.select(request.id);
      } else {
        final day = DateTime.parse(request.day ?? localDate(DateTime.now()));
        Widget editor;
        if (request.kind == 'event') {
          final events = await controller.repository.eventOccurrences(
            localDate(day),
            localDate(day.add(const Duration(days: 1))),
          );
          final event = events
              .where(
                (e) =>
                    e.id == request.id &&
                    (request.nominalDate == null ||
                        e.nominalDate == request.nominalDate),
              )
              .firstOrNull;
          if (event == null) {
            throw StateError('Event occurrence is no longer available');
          }
          if (!mounted) return;
          editor = EventEditor(
            key: ValueKey((event.id, event.nominalDate ?? '', editorRevision)),
            protectUnsavedEdits: true,
            event: event,
            initialDay: day,
            onClose: () => Navigator.of(context, rootNavigator: true).pop(),
          );
        } else {
          final session = controller.sessions
              .where((s) => s.id == request.id)
              .firstOrNull;
          if (session == null) {
            throw StateError('Session is no longer available');
          }
          editor = SessionEditor(
            protectUnsavedEdits: true,
            session: session,
            initialDay: day,
            onClose: () => Navigator.of(context, rootNavigator: true).pop(),
          );
        }
        if (!mounted || deferIfEditing(request)) return;
        setState(() {
          navigationDay = DateUtils.isSameDay(day, _lastCalendarDate)
              ? null
              : day;
        });
        controller.navigate(WorkspaceView.calendar);
        await showDialog<void>(
          context: context,
          animationStyle: AppMotion.style(context),
          builder: (_) => Dialog(
            child: SizedBox(
              width: 520,
              height: (MediaQuery.sizeOf(context).height - 64).clamp(240, 650),
              child: editor,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot open widget item: $e')));
      }
    } finally {
      navigating = false;
    }
  }

  bool creating = false;
  bool changingEditor = false;
  int editorRevision = 0;
  final editorNavigation = TaskEditorController();
  String? _focusWorkspaceTaskId;
  bool _viewingTaskDetails = false;
  bool _viewingEventDetails = false;
  FixedEvent? _selectedEvent;

  void _openFocusWorkspace(String taskId) {
    ref.read(appControllerProvider).select(null);
    setState(() {
      _focusWorkspaceTaskId = taskId;
      _viewingTaskDetails = false;
      _viewingEventDetails = false;
      _selectedEvent = null;
      creating = false;
    });
  }

  Future<void> _editTaskDialog(LifeTask task) async {
    await showAppModal<void>(
      context: context,
      maxWidth: AppLayout.dialogWideWidth,
      maxHeight: AppLayout.dialogMaxHeight,
      builder: (dialogContext) => TaskEditor(
        protectUnsavedEdits: true,
        task: task,
        onSaved: () => Navigator.pop(dialogContext),
        onCancel: () => Navigator.pop(dialogContext),
      ),
    );
  }

  Future<bool> _withEditorNavigation(FutureOr<void> Function() navigate) async {
    if (changingEditor) return false;
    changingEditor = true;
    try {
      if (!await editorNavigation.confirmLeave() || !mounted) return false;
      await navigate();
      return mounted;
    } finally {
      changingEditor = false;
    }
  }

  Future<bool> _prepareEditorChange() => _withEditorNavigation(() {
    setState(() {
      creating = false;
      _viewingTaskDetails = false;
      _viewingEventDetails = false;
      _selectedEvent = null;
      _focusWorkspaceTaskId = null;
      editorRevision++;
    });
  });

  Future<void> _requestCloseEditor() async {
    await _withEditorNavigation(_closeEditor);
  }

  Future<void> _navigate(WorkspaceView view, {String? id}) async {
    if (await _prepareEditorChange()) {
      ref.read(appControllerProvider).navigate(view, id: id);
    }
  }

  Future<void> _openTask(
    LifeTask task,
    bool wide, {
    bool navigate = false,
    bool skipConfirm = false,
  }) async {
    final controller = ref.read(appControllerProvider);
    if (!skipConfirm) {
      if (!await _prepareEditorChange() || !mounted) return;
    }
    if (navigate) {
      controller.navigate(
        task.isOpen ? WorkspaceView.all : WorkspaceView.completed,
      );
    }
    final useFullPage = controller.isFullPageDetails;
    controller.select(task.id);
    setState(() {
      _selectedEvent = null;
      _viewingEventDetails = false;
      _focusWorkspaceTaskId = null;
      creating = false;
      _viewingTaskDetails = useFullPage;
    });
  }

  DateTime? newTaskInitialDate;
  final nativeWidget = NativeWidgetService();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHotkey);
    if (Platform.isWindows) {
      _activationChannel.setMethodCallHandler((call) async {
        if (call.method != 'activate' || !mounted) return;
        final command = call.arguments;
        if (command is String && command.startsWith('navigate:')) {
          receiveNavigation(command.substring(9));
        } else if (command == 'appearance') {
          _openAppearanceDialog();
        } else if (command is String && command.startsWith('widget:')) {
          _openWidgetSettings(
            command.endsWith('calendar')
                ? DesktopWidgetKind.calendar
                : DesktopWidgetKind.tasks,
          );
        } else if (command is String && command.startsWith('task:')) {
          receiveNavigation(
            NavigationRequest(kind: 'task', id: command.substring(5)).encode(),
          );
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _activationChannel.invokeMethod<void>('ready');
      });
    }
    if (widget.initialNavigation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) receiveNavigation(widget.initialNavigation!);
      });
    }
    if (widget.editWidget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openWidgetSettings(widget.editWidget!);
      });
    }
    if (widget.openAppearance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAppearanceDialog();
      });
    }
    if (PrivateTestEnvironment.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (_) => SettingsHubDialog(
            nativeWidget: nativeWidget,
            showDataProfile: _showDataProfile,
            openBackups: true,
          ),
        );
      });
    }
    if (widget.legacyImportFile case final legacyFile?) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final review = await showDialog<bool>(
          context: context,
          animationStyle: AppMotion.style(context),
          builder: (dialogContext) => AlertDialog(
            title: const Text('Older Life Manager data found'),
            content: const Text(
              'Todorbit has started with an empty profile. Your older Life Manager data has not been opened or changed. You can review a verified import before choosing whether to replace this empty profile.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep empty profile'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Review import'),
              ),
            ],
          ),
        );
        if (review == true && mounted) {
          final service = ref.read(appControllerProvider).backupService;
          if (service != null) {
            await showDialog<void>(
              context: context,
              animationStyle: AppMotion.style(context),
              builder: (_) => BackupDialog(
                service: service,
                chooseImport: () async => legacyFile,
              ),
            );
          }
        }
      });
    }
  }

  Future<void> _openWidgetSettings(DesktopWidgetKind kind) async {
    if (!mounted) return;
    _widgetSettingsController.open(kind);
    if (_widgetSettingsOpen) return;
    _widgetSettingsOpen = true;
    try {
      await showDialog<void>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (_) => SettingsHubDialog(
          nativeWidget: nativeWidget,
          showDataProfile: _showDataProfile,
          editWidget: kind,
          widgetController: _widgetSettingsController,
        ),
      );
    } finally {
      _widgetSettingsOpen = false;
    }
  }

  Future<void> _openAppearanceDialog() async {
    if (!mounted || _appearanceDialogOpen) return;
    _appearanceDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (_) => const ThemeDialog(),
      );
    } finally {
      _appearanceDialogOpen = false;
    }
  }

  @override
  void dispose() {
    _sidebarSearchQuery.dispose();
    _sidebarSearchFocus.dispose();
    categoryDisclosure.dispose();
    _widgetSettingsController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleHotkey);
    if (Platform.isWindows) _activationChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _showDataProfile() async {
    final file = await AppDatabase.defaultFile();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (context) => AlertDialog(
        title: const Text('Data profile'),
        content: SelectableText(
          'Todorbit stores this Windows user’s tasks and settings in the '
          'per-user data folder. Updating or reinstalling the app keeps this '
          'profile. A different Windows user starts with an empty profile.\n\n'
          'Database: ${file.path}\n\n'
          'To move data to another computer, use Settings > Backups & Cloud and Export. '
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

  Future<void> _newTask() async {
    if (!await _prepareEditorChange() || !mounted) return;
    ref.read(appControllerProvider).select(null);
    newTaskInitialDate = null;
    if (MediaQuery.sizeOf(context).width < AppLayout.breakpointMedium) {
      showAppModal<void>(
        context: context,
        builder: (dialogContext) => TaskEditor(
          protectUnsavedEdits: true,
          onSaved: () => Navigator.pop(dialogContext),
          onCancel: () => Navigator.pop(dialogContext),
        ),
      );
      return;
    }
    setState(() => creating = true);
  }

  Future<void> _newTaskOn(DateTime date) async {
    if (!await _prepareEditorChange() || !mounted) return;
    ref.read(appControllerProvider).select(null);
    if (MediaQuery.sizeOf(context).width < AppLayout.breakpointMedium) {
      showAppModal<void>(
        context: context,
        builder: (dialogContext) => TaskEditor(
          protectUnsavedEdits: true,
          initialScheduled: date,
          onSaved: () => Navigator.pop(dialogContext),
          onCancel: () => Navigator.pop(dialogContext),
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
    setState(() {
      creating = false;
      newTaskInitialDate = null;
      _viewingTaskDetails = false;
      _viewingEventDetails = false;
      _selectedEvent = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(deliverNavigation());
    });
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
      animationStyle: AppMotion.style(context),
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
    bool isDestructive = true,
  }) async {
    return await showDialog<bool>(
          context: context,
          animationStyle: AppMotion.style(context),
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: isDestructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      )
                    : null,
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
      animationStyle: AppMotion.style(context),
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
    animationStyle: AppMotion.style(context),
    builder: (_) => const ScheduleHistoryDialog(),
  );

  Future<void> _openEventDetails(
    FixedEvent event, {
    bool skipConfirm = false,
  }) async {
    if (!skipConfirm) {
      if (!await _prepareEditorChange() || !mounted) return;
    }
    _lastCalendarDate = event.startsAt.toLocal();
    final controller = ref.read(appControllerProvider);
    final useFullPage = controller.isFullPageDetails;
    controller.select(null);
    setState(() {
      creating = false;
      _focusWorkspaceTaskId = null;
      _viewingTaskDetails = false;
      _selectedEvent = event;
      _viewingEventDetails = useFullPage;
    });
  }

  Future<void> _showSearch([bool wide = true]) async {
    if (changingEditor) return;
    await showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (_) => QuickSearchDialog(
        beforeNavigate: _prepareEditorChange,
        onEventTap: (event) => _openEventDetails(event, skipConfirm: true),
        onTaskTap: (task) =>
            _openTask(task, wide, navigate: true, skipConfirm: true),
      ),
    );
  }

  Future<void> _showSequences() => showDialog<void>(
    context: context,
    animationStyle: AppMotion.style(context),
    builder: (_) => const SequenceDialog(),
  );

  Future<void> _renameSavedView(SavedView savedView) async {
    final name = await _nameDialog(
      'Rename Custom View',
      initial: savedView.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      await _run(
        () => ref
            .read(appControllerProvider)
            .renameSavedView(savedView, name.trim()),
      );
    }
  }

  Future<void> _duplicateSavedView(SavedView savedView) async {
    final name = await _nameDialog(
      'Duplicate Custom View',
      initial: '${savedView.name} (copy)',
    );
    if (name != null && name.trim().isNotEmpty) {
      await _run(
        () => ref
            .read(appControllerProvider)
            .duplicateSavedView(savedView, name.trim()),
      );
    }
  }

  Future<void> _moveSavedView(String viewId, int direction) async {
    await _run(
      () => ref.read(appControllerProvider).moveSavedView(viewId, direction),
    );
  }

  Future<void> _showTemplates() => showDialog<void>(
    context: context,
    animationStyle: AppMotion.style(context),
    builder: (_) => TemplatesDialog(beforeNavigate: _prepareEditorChange),
  );

  Future<void> _showArchiveTrash() => showDialog<void>(
    context: context,
    animationStyle: AppMotion.style(context),
    builder: (_) => const ArchiveTrashDialog(),
  );

  Future<void> _showAdvancedSearch([
    SavedView? savedView,
    bool wide = true,
  ]) async {
    if (changingEditor) return;
    await showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (_) => AdvancedSearchDialog(
        savedView: savedView,
        beforeNavigate: _prepareEditorChange,
        onTaskTap: (task) =>
            _openTask(task, wide, navigate: true, skipConfirm: true),
      ),
    );
  }

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

  Future<void> _showActiveTimer(String taskId) async {
    await _withEditorNavigation(() => _openFocusWorkspace(taskId));
  }

  Future<void> _changeIcon(String kind, String id) async {
    final controller = ref.read(appControllerProvider);
    final current = controller.iconKeys['$kind:$id'];
    final selected = await chooseBuiltInIcon(context, current: current);
    if (selected.$1 && mounted) {
      await _run(() => controller.setIcon(kind, id, selected.$2));
    }
  }

  Future<void> _quickStart(LifeTask task) async {
    await _withEditorNavigation(
      () => openTaskTimer(
        context,
        ref.read(appControllerProvider),
        task.id,
        open: _openFocusWorkspace,
      ),
    );
  }

  String _scheduleScope(AppController controller) => switch (controller.view) {
    WorkspaceView.category => 'category:${controller.scopeId}',
    WorkspaceView.project => 'project:${controller.scopeId}',
    _ => 'view:${controller.view.name}',
  };

  void _runHotkey(HotkeyAction action, AppController controller) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    switch (action) {
      case HotkeyAction.newTask:
        _newTask();
      case HotkeyAction.quickSearch:
        _showSearch();
      case HotkeyAction.advancedSearch:
        _showAdvancedSearch();
      case HotkeyAction.today:
        _navigate(WorkspaceView.today);
      case HotkeyAction.allTasks:
        _navigate(WorkspaceView.all);
      case HotkeyAction.calendar:
        _navigate(WorkspaceView.calendar);
      case HotkeyAction.anytime:
        _navigate(WorkspaceView.anytime);
      case HotkeyAction.settings:
        showDialog<void>(
          context: context,
          animationStyle: AppMotion.style(context),
          builder: (_) => SettingsHubDialog(
            nativeWidget: nativeWidget,
            showDataProfile: _showDataProfile,
          ),
        );
      case HotkeyAction.focus:
        if (controller.activeTimer != null) {
          _run(() => controller.stopTimer());
        } else if (controller.selectedTask case final selected?) {
          if (selected.isOpen) _run(() => controller.startFocusTask(selected));
        }
      case HotkeyAction.refresh:
        _run(() => controller.refresh());
    }
  }

  bool _handleHotkey(KeyEvent event) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return false;
    final binding = HotkeyBinding.fromKeyEvent(event);
    if (binding == null) return false;
    final controller = ref.read(appControllerProvider);
    for (final entry in controller.hotkeys.bindings.entries) {
      if (entry.value == binding) {
        _runHotkey(entry.key, controller);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return CallbackShortcuts(
      bindings: {
        for (final entry in controller.hotkeys.bindings.entries)
          entry.value.activator: () => _runHotkey(entry.key, controller),
        const SingleActivator(LogicalKeyboardKey.escape): () async {
          if (_viewingTaskDetails ||
              _viewingEventDetails ||
              _selectedEvent != null ||
              controller.selectedTask != null ||
              creating) {
            await _requestCloseEditor();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          bottomNavigationBar: pendingNavigation == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Widget item waiting. Finish the current editor or dialog to open it.',
                          ),
                        ),
                        TextButton(
                          onPressed: () => deliverNavigation(),
                          child: const Text('Open requested item'),
                        ),
                        IconButton(
                          tooltip: 'Dismiss navigation request',
                          onPressed: () =>
                              setState(() => pendingNavigation = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1050;
              final useFullPage = controller.isFullPageDetails;
              final hasTaskSelected =
                  (controller.selectedTask != null || creating) &&
                  !_viewingTaskDetails;
              final hasEventSelected =
                  _selectedEvent != null && !_viewingEventDetails;
              final editor =
                  !useFullPage &&
                  (hasTaskSelected || hasEventSelected) &&
                  _focusWorkspaceTaskId == null;
              final inlineEditor = editor;
              final sidebarWidth = constraints.maxWidth < 760
                  ? 190.0
                  : controller.customization.sidebarWidth.toDouble();
              return Row(
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: _sidebar(controller, wide: wide),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  if (wide || !inlineEditor)
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                PopupMenuButton<String>(
                                  tooltip: 'Library',
                                  icon: const Icon(
                                    Icons.collections_bookmark_outlined,
                                    size: 19,
                                  ),
                                  onSelected: (action) {
                                    if (action == 'templates') _showTemplates();
                                    if (action == 'sequences') _showSequences();
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'templates',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.copy_all_outlined,
                                            size: 18,
                                          ),
                                          SizedBox(width: 10),
                                          Text('Templates'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'sequences',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.format_list_numbered,
                                            size: 18,
                                          ),
                                          SizedBox(width: 10),
                                          Text('Sequences'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                SyncStatusButton(
                                  allowAutomatic: !editor,
                                  onOpenSettings: showSyncSettings,
                                  onOpenConflicts: showSyncConflicts,
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: _mainPanel(controller, wide)),
                        ],
                      ),
                    ),
                  if (inlineEditor) ...[
                    VerticalDivider(
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    SizedBox(
                      key: const ValueKey('desktop-task-editor-panel'),
                      width: wide
                          ? constraints.maxWidth >= AppLayout.breakpointWide
                                ? AppLayout.panelWideWidth
                                : AppLayout.panelDefaultWidth
                          : math.max(
                              0,
                              constraints.maxWidth - sidebarWidth - 2,
                            ),
                      child: _selectedEvent != null
                          ? EventEditor(
                              key: ValueKey((
                                _selectedEvent!.id,
                                _selectedEvent!.nominalDate ?? '',
                                editorRevision,
                              )),
                              event: _selectedEvent!,
                              initialDay: _selectedEvent!.startsAt.toLocal(),
                              protectUnsavedEdits: true,
                              navigationController: editorNavigation,
                              onClose: _closeEditor,
                            )
                          : TaskEditor(
                              protectUnsavedEdits: true,
                              key: ValueKey((
                                creating ? 'new' : controller.selectedTask!.id,
                                editorRevision,
                              )),
                              navigationController: editorNavigation,
                              task: creating ? null : controller.selectedTask,
                              initialScheduled: creating
                                  ? newTaskInitialDate
                                  : null,
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

  Widget _buildSidebarSearchResults(
    AppController controller,
    String query,
    bool wide,
  ) {
    final needle = query.trim().toLowerCase();
    final categories = {
      for (final item in controller.categories) item.id: item,
    };
    final projects = {for (final item in controller.projects) item.id: item};

    final matchingCategories = controller.categories
        .where((c) => c.name.toLowerCase().contains(needle))
        .toList();
    final matchingProjects = controller.projects
        .where((p) => p.name.toLowerCase().contains(needle))
        .toList();
    final matchingTasks = controller.tasks.where((t) {
      final title = t.title.toLowerCase();
      final cat = categories[t.categoryId]?.name.toLowerCase() ?? '';
      final proj = projects[t.projectId]?.name.toLowerCase() ?? '';
      final notes = t.notes.toLowerCase();
      return title.contains(needle) ||
          cat.contains(needle) ||
          proj.contains(needle) ||
          notes.contains(needle);
    }).toList();

    if (matchingCategories.isEmpty &&
        matchingProjects.isEmpty &&
        matchingTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No results for "$query"',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showAdvancedSearch(),
                child: const Text('Open Advanced Search'),
              ),
            ],
          ),
        ),
      );
    }

    return FadingListView(
      topFadeColor: Theme.of(context).colorScheme.surfaceContainerLow,
      bottomFadeColor: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        if (matchingCategories.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          for (final cat in matchingCategories)
            _nav(
              controller,
              WorkspaceView.category,
              cat.name,
              Icons.folder_outlined,
              id: cat.id,
            ),
        ],
        if (matchingProjects.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'PROJECTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          for (final proj in matchingProjects)
            _nav(
              controller,
              WorkspaceView.project,
              proj.name,
              Icons.segment_outlined,
              id: proj.id,
            ),
        ],
        if (matchingTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              'TASKS (${matchingTasks.length})',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          for (final task in matchingTasks.take(30))
            ListTile(
              dense: true,
              leading: Icon(
                task.isOpen ? Icons.check_box_outline_blank : Icons.task_alt,
                size: 18,
              ),
              title: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                task.scheduledDate != null
                    ? 'Plan ${task.scheduledDate}'
                    : (task.isOpen ? 'Active' : 'Completed'),
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () => _openTask(task, wide, navigate: true),
            ),
        ],
      ],
    );
  }

  Widget _sidebar(AppController controller, {bool wide = true}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceActiveTimerBadge(open: _showActiveTimer),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
            child: Row(
              children: [
                const BrandMark(),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Todorbit',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                SupportButton(
                  reducedMotion: controller.customization.reducedMotion,
                  claimIntroduction: controller.appearanceStore == null
                      ? null
                      : () => controller.repository.claimSupportIntroduction(
                          File.fromUri(
                            controller.appearanceStore!.file.parent.uri.resolve(
                              'support-introduction.json',
                            ),
                          ),
                        ),
                ),
                IconButton(
                  tooltip: 'Archive and Trash',
                  onPressed: _showArchiveTrash,
                  icon: const Icon(Icons.archive_outlined, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _sidebarSearchFocus.hasFocus
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.6),
                  width: _sidebarSearchFocus.hasFocus ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    tooltip: 'Quick Search (Ctrl+K)',
                    icon: Icon(
                      Icons.search,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: _showSearch,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _sidebarSearchQuery,
                      focusNode: _sidebarSearchFocus,
                      style: const TextStyle(fontSize: 13, height: 1.2),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: controller.customization.sidebarWidth < 220
                            ? 'Search...'
                            : 'Search tasks & events...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_sidebarSearchQuery.text.isNotEmpty)
                    IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _sidebarSearchQuery.clear();
                        setState(() {});
                      },
                    ),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    tooltip: 'Advanced search & filters',
                    icon: const Icon(Icons.tune_outlined),
                    onPressed: () => _showAdvancedSearch(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          Expanded(
            child: _sidebarSearchQuery.text.trim().isNotEmpty
                ? _buildSidebarSearchResults(
                    controller,
                    _sidebarSearchQuery.text,
                    wide,
                  )
                : FadingListView(
                    topFadeColor: scheme.surfaceContainerLow,
                    bottomFadeColor: scheme.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final view in controller.sidebarOrder.where(
                        (v) => !controller.hiddenNavigation.contains(v.name),
                      ))
                        _nav(
                          controller,
                          view,
                          sidebarName(view),
                          sidebarIcon(view),
                        ),
                      const SizedBox(height: 8),
                      ExpansionTile(
                        key: const PageStorageKey('sidebar-categories'),
                        controller: categoryDisclosure,
                        tilePadding: EdgeInsets.zero,
                        initiallyExpanded: controller.categoriesExpanded,
                        onExpansionChanged: (expanded) {
                          if (expanded != controller.categoriesExpanded) {
                            _run(
                              () => controller.setNavigationState(
                                expanded: expanded,
                              ),
                            );
                          }
                        },
                        title: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    'Categories (${controller.categories.length})',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
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
                                  await _run(() async {
                                    await controller.addCategory(name);
                                    await controller.setNavigationState(
                                      expanded: true,
                                    );
                                    if (mounted) categoryDisclosure.expand();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        children: [
                          if (controller.categories.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 2, 8, 10),
                              child: Text(
                                'Organize tasks with categories',
                                style: Theme.of(context).textTheme.bodySmall,
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
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'project',
                                    child: Text('Add project'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'event-color',
                                    child: Text('Default event color'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'icon',
                                    child: Text('Change icon'),
                                  ),
                                  PopupMenuItem(
                                    value: 'show-in-standard',
                                    child: Row(
                                      children: [
                                        Icon(
                                          controller
                                                  .isCategoryShownInStandardViews(
                                                    category.id,
                                                  )
                                              ? Icons.check_box_outlined
                                              : Icons.check_box_outline_blank,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text('Show in standard views'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                onSelected: (action) async {
                                  if (action == 'project') {
                                    final name = await _nameDialog(
                                      'New project',
                                    );
                                    if (name != null && name.isNotEmpty) {
                                      _run(
                                        () => controller.addProject(
                                          category.id,
                                          name,
                                        ),
                                      );
                                    }
                                  } else if (action == 'icon') {
                                    await _changeIcon('category', category.id);
                                  } else if (action == 'event-color') {
                                    await _chooseCategoryEventColor(category);
                                  } else if (action == 'show-in-standard') {
                                    await _run(
                                      () => controller
                                          .toggleCategoryStandardVisibility(
                                            category.id,
                                          ),
                                    );
                                  } else if (action == 'rename') {
                                    final name = await _nameDialog(
                                      'Rename category',
                                      initial: category.name,
                                    );
                                    if (name != null && name.isNotEmpty) {
                                      _run(
                                        () => controller.renameCategory(
                                          category.id,
                                          name,
                                        ),
                                      );
                                    }
                                  } else if (await _confirm(
                                        'Delete category?',
                                        'Move this category to Trash? Its projects and tasks will be hidden until restored.',
                                      ) &&
                                      await _prepareEditorChange()) {
                                    _run(
                                      () => controller.deleteCategory(
                                        category.id,
                                      ),
                                    );
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
                                    controller
                                        .iconKeys['project:${project.id}'],
                                    Icons.segment_outlined,
                                  ),
                                  id: project.id,
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Project actions',
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'template',
                                        child: Text('Save as template'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'rename',
                                        child: Text('Rename'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'icon',
                                        child: Text('Change icon'),
                                      ),
                                      PopupMenuItem(
                                        value: 'show-in-standard',
                                        child: Row(
                                          children: [
                                            Icon(
                                              controller
                                                      .isProjectShownInStandardViews(
                                                        project.id,
                                                      )
                                                  ? Icons.check_box_outlined
                                                  : Icons
                                                        .check_box_outline_blank,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'Show in standard views',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                    onSelected: (action) async {
                                      if (action == 'template') {
                                        await showSaveTemplateDialog(
                                          context,
                                          sourceName: project.name,
                                          save: (name) =>
                                              controller.saveProjectTemplate(
                                                project,
                                                name,
                                              ),
                                        );
                                      } else if (action == 'icon') {
                                        await _changeIcon(
                                          'project',
                                          project.id,
                                        );
                                      } else if (action == 'show-in-standard') {
                                        await _run(
                                          () => controller
                                              .toggleProjectStandardVisibility(
                                                project.id,
                                              ),
                                        );
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
                                          ) &&
                                          await _prepareEditorChange()) {
                                        _run(
                                          () => controller.deleteProject(
                                            project.id,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text(
                                'CUSTOM VIEWS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add Custom View',
                            onPressed: () => showDialog<void>(
                              context: context,
                              animationStyle: AppMotion.style(context),
                              builder: (_) => AdvancedSearchDialog(
                                creatingSavedView: true,
                                beforeNavigate: _prepareEditorChange,
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 19),
                          ),
                        ],
                      ),
                      for (final (index, savedView)
                          in controller.orderedSavedViews
                              .where(
                                (v) =>
                                    !controller.hiddenNavigation.contains(v.id),
                              )
                              .indexed)
                        _nav(
                          controller,
                          WorkspaceView.saved,
                          savedView.name,
                          iconForKey(
                            savedView.iconKey ?? savedView.filter.iconKey,
                            Icons.bookmark_outline,
                          ),
                          id: savedView.id,
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Custom view actions',
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit filters'),
                              ),
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicate'),
                              ),
                              if (index > 0)
                                const PopupMenuItem(
                                  value: 'move_up',
                                  child: Text('Move up'),
                                ),
                              if (index <
                                  controller.orderedSavedViews.length - 1)
                                const PopupMenuItem(
                                  value: 'move_down',
                                  child: Text('Move down'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete view'),
                              ),
                            ],
                            onSelected: (action) {
                              if (action == 'rename') {
                                _renameSavedView(savedView);
                              }
                              if (action == 'edit') {
                                _showAdvancedSearch(savedView);
                              }
                              if (action == 'duplicate') {
                                _duplicateSavedView(savedView);
                              }
                              if (action == 'move_up') {
                                _moveSavedView(savedView.id, -1);
                              }
                              if (action == 'move_down') {
                                _moveSavedView(savedView.id, 1);
                              }
                              if (action == 'delete') {
                                _deleteSavedView(savedView);
                              }
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 4,
                        ),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add View'),
                          onPressed: () => showDialog<void>(
                            context: context,
                            animationStyle: AppMotion.style(context),
                            builder: (_) => AdvancedSearchDialog(
                              creatingSavedView: true,
                              beforeNavigate: _prepareEditorChange,
                            ),
                          ),
                        ),
                      ),
                      if (!controller.hiddenNavigation.contains('reports'))
                        _nav(
                          controller,
                          WorkspaceView.reports,
                          'Reports',
                          Icons.bar_chart_outlined,
                        ),
                      if (!controller.hiddenNavigation.contains('contributors'))
                        _nav(
                          controller,
                          WorkspaceView.contributors,
                          'Contributors',
                          Icons.groups_outlined,
                        ),
                    ],
                  ),
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                context: context,
                animationStyle: AppMotion.style(context),
                builder: (_) => SettingsHubDialog(
                  nativeWidget: nativeWidget,
                  showDataProfile: _showDataProfile,
                ),
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
          onTap: () => _navigate(view, id: id),
        ),
      ),
    );
  }

  Widget _mainPanel(AppController controller, bool wide) {
    if (_focusWorkspaceTaskId != null) {
      return FocusWorkspace(
        taskId: _focusWorkspaceTaskId!,
        onBack: () => setState(() => _focusWorkspaceTaskId = null),
      );
    }
    if (_viewingTaskDetails && controller.selectedTask != null) {
      return TaskDetailsView(
        task: controller.selectedTask!,
        onBack: _closeEditor,
        onEdit: () => _editTaskDialog(controller.selectedTask!),
        onStartFocus: () => _quickStart(controller.selectedTask!),
      );
    }
    if (_viewingEventDetails && _selectedEvent != null) {
      return EventEditor(
        key: ValueKey((
          _selectedEvent!.id,
          _selectedEvent!.nominalDate ?? '',
          editorRevision,
        )),
        event: _selectedEvent!,
        initialDay: _selectedEvent!.startsAt.toLocal(),
        protectUnsavedEdits: true,
        navigationController: editorNavigation,
        onClose: _closeEditor,
      );
    }
    if (controller.isFullPageDetails && creating) {
      return TaskEditor(
        protectUnsavedEdits: true,
        key: ValueKey(('new', editorRevision)),
        navigationController: editorNavigation,
        task: null,
        initialScheduled: newTaskInitialDate,
        onSaved: _closeEditor,
        onCancel: _closeEditor,
      );
    }
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
        key: const ValueKey('workspace-calendar-view'),
        initialDate: navigationDay ?? _lastCalendarDate,
        onDateSelected: (date) {
          _lastCalendarDate = date;
          if (DateUtils.isSameDay(date, navigationDay)) navigationDay = null;
        },
        onAddTask: _newTaskOn,
        onTaskTap: (task) => _openTask(task, wide),
        onEventTap: (event) => _openEventDetails(event),
        onEscape: _requestCloseEditor,
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
    final items = controller.visibleTasks;
    final roots = projectTaskList(
      items,
      controller.taskParents,
      groupRecurrence: controller.view == WorkspaceView.all,
      relatedOccurrences:
          controller.view == WorkspaceView.all &&
              !controller.activeFilter.isActive
          ? controller.tasks
          : const [],
    );
    final scopedEvents =
        {
          WorkspaceView.project,
          WorkspaceView.category,
          WorkspaceView.saved,
        }.contains(controller.view)
        ? controller.filteredEvents.where((event) => !event.cancelled).toList()
        : <FixedEvent>[];
    final today = localDate(DateTime.now());
    final todayStart = DateTime.now();
    final dayStart = DateTime(
      todayStart.year,
      todayStart.month,
      todayStart.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final todayEvents = controller.filteredEvents.where((event) {
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
    return ScrollEdgeFade(
      child: CustomScrollView(
        key: PageStorageKey(
          'task-list:${controller.view.name}:${controller.scopeId}',
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 26, 24, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 6,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth < 700
                              ? constraints.maxWidth
                              : math.max(180, constraints.maxWidth - 430),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${items.length} ${items.length == 1 ? 'task' : 'tasks'}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AboutViewButton(
                          description: _viewDescription(controller.view),
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
                            PopupMenuItem(
                              value: TaskSort.title,
                              child: Text('Title'),
                            ),
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
                            foregroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.disabled)) {
                                return Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.38);
                              }
                              return Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant;
                            }),
                            overlayColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
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
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: ItemFilters(),
                ),
                if (controller.hiddenStandardTasksCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 24, 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 15,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${controller.hiddenStandardTasksCount} task${controller.hiddenStandardTasksCount == 1 ? '' : 's'} hidden by category or project settings',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                if ({
                  WorkspaceView.project,
                  WorkspaceView.category,
                  WorkspaceView.saved,
                }.contains(controller.view))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 24, 12),
                    child: Text(
                      'Events: ${controller.eventWindowLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
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
                          onPressed: () => _navigate(WorkspaceView.calendar),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.schedule_outlined, size: 17),
                          label: Text('$todaySessions work sessions'),
                          onPressed: () => _navigate(WorkspaceView.calendar),
                        ),
                        if (overdueCount > 0)
                          ActionChip(
                            avatar: const Icon(
                              Icons.warning_amber_rounded,
                              size: 17,
                            ),
                            label: Text(
                              '$overdueCount overdue deadline${overdueCount == 1 ? '' : 's'}',
                            ),
                            onPressed: () => _navigate(WorkspaceView.overdue),
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
                            onPressed: () => _navigate(WorkspaceView.goals),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (items.isEmpty && scopedEvents.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
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
                      controller.activeFilter.isActive
                          ? 'No matching items'
                          : controller.view == WorkspaceView.today
                          ? 'No tasks planned for today'
                          : 'Nothing here yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      controller.activeFilter.isActive
                          ? 'Change filters or clear them to see more items.'
                          : controller.view == WorkspaceView.today
                          ? 'Add a task or review today’s calendar.'
                          : 'Create a task or choose another view.',
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList.builder(
                itemCount: roots.length + scopedEvents.length,
                itemBuilder: (context, index) {
                  if (index < scopedEvents.length) {
                    final event = scopedEvents[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_outlined),
                        trailing:
                            eventAlarmRule(
                                  event,
                                  controller.alarmRules,
                                )?.config.enabled ==
                                true
                            ? const AlarmIndicator()
                            : null,
                        title: Text(event.title),
                        subtitle: Text(localDate(event.startsAt.toLocal())),
                        onTap: () => _openEventDetails(event),
                      ),
                    );
                  }
                  return TaskListGroupView(
                    group: roots[index - scopedEvents.length],
                    items: items,
                    parents: controller.taskParents,
                    row: (task) => _taskRow(controller, task, wide),
                    subtaskRow: (task) => _subtaskRow(controller, task, wide),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _taskRow(AppController controller, LifeTask task, bool wide) {
    final childCount = controller.taskParents.values
        .where((id) => id == task.id)
        .length;
    final done = task.status == TaskStatus.completed;
    final focusActive = controller.activeTimer?.taskId == task.id;
    final unmetPrerequisites = controller.unmetPrerequisites(task.id);
    final hasAlarm = task.isOpen &&
        taskAlarmRule(task, controller.alarmRules)?.config.enabled == true;

    final subtasks = childCount > 0
        ? TaskProgress(
            completed: controller.tasks
                .where((child) =>
                    controller.taskParents[child.id] == task.id &&
                    child.status == TaskStatus.completed)
                .length,
            total: childCount,
          )
        : null;

    final checklistTotal = controller.checklistItems
        .where((item) => item.taskId == task.id)
        .length;
    final checklist = checklistTotal > 0
        ? TaskProgress(
            completed: controller.checklistItems
                .where((item) => item.taskId == task.id && item.done)
                .length,
            total: checklistTotal,
          )
        : null;

    return AppTaskRow(
      task: task,
      variant: AppTaskRowVariant.desktop,
      isSelected: controller.selectedTaskId == task.id,
      isFocusActive: focusActive,
      hasAlarm: hasAlarm,
      iconKey: controller.iconForTask(task),
      subtaskProgress: subtasks,
      checklistProgress: checklist,
      unmetPrerequisitesCount: unmetPrerequisites.length,
      unmetPrerequisitesSummary: unmetPrerequisites.isNotEmpty
          ? 'Waiting for ${unmetPrerequisites.map((item) => item.title).join(', ')}'
          : null,
      onTap: () => _openTask(task, wide),
      onToggleComplete: (value) =>
          _run(() => controller.setComplete(task, value)),
      quickStartAction: task.isOpen
          ? IconButton(
              tooltip: task.status == TaskStatus.inProgress
                  ? 'Work or focus actions'
                  : 'Start task or focus',
              onPressed: () => _quickStart(task),
              icon: Icon(
                focusActive ? Icons.timer : Icons.play_circle_outline,
              ),
            )
          : null,
      trailingActions: PopupMenuButton<String>(
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
            await _openTask(task, wide);
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
    );
  }

  Widget _subtaskRow(AppController controller, LifeTask task, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    final done = task.status == TaskStatus.completed;
    final focusActive = controller.activeTimer?.taskId == task.id;
    final overdue =
        task.isOpen &&
        task.deadlineDate != null &&
        task.deadlineDate!.compareTo(localDate(DateTime.now())) < 0;
    final isSelected = controller.selectedTaskId == task.id;

    return Material(
      color: focusActive
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : isSelected
          ? scheme.secondaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openTask(task, wide),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              children: [
                Tooltip(
                  message: done ? 'Reopen subtask' : 'Complete subtask',
                  child: Checkbox(
                    value: done,
                    semanticLabel:
                        '${done ? 'Reopen' : 'Complete'} ${task.title}',
                    onChanged: (value) => _run(
                      () => controller.setComplete(task, value ?? false),
                    ),
                  ),
                ),
                Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done
                              ? scheme.onSurface.withValues(alpha: 0.55)
                              : null,
                        ),
                      ),
                      if (task.scheduledDate != null ||
                          task.deadlineDate != null ||
                          focusActive ||
                          task.status == TaskStatus.inProgress)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            children: [
                              if (focusActive ||
                                  task.status == TaskStatus.inProgress)
                                Text(
                                  focusActive
                                      ? (controller.activeTimer!.state ==
                                                TimerState.paused
                                            ? 'Timer paused'
                                            : 'Timer running')
                                      : 'In progress',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              if (task.scheduledDate != null)
                                Text(
                                  'Plan ${task.scheduledDate}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              if (task.deadlineDate != null)
                                Text(
                                  'Due ${task.deadlineDate}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: overdue
                                        ? scheme.error
                                        : scheme.onSurfaceVariant,
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
                    size: 16,
                    color: task.priority == 3 ? scheme.error : scheme.primary,
                  ),
                if (task.isOpen)
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: task.status == TaskStatus.inProgress
                        ? 'Open task timer'
                        : 'Start Subtask',
                    onPressed: () => _quickStart(task),
                    icon: Icon(
                      focusActive ? Icons.timer : Icons.play_arrow_outlined,
                      color: focusActive ? scheme.primary : null,
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Subtask actions',
                  iconSize: 18,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: const Text('Edit')),
                    PopupMenuItem(
                      value: 'complete',
                      child: Text(done ? 'Reopen' : 'Complete'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Text('Move to Trash'),
                    ),
                  ],
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _openTask(task, wide);
                    } else if (action == 'complete') {
                      _run(() => controller.setComplete(task, !done));
                    } else if (action == 'delete') {
                      if (await _confirm(
                        'Delete subtask?',
                        'Move “${task.title}” to Trash? It can be restored with its history.',
                      )) {
                        _run(() => controller.deleteTask(task.id));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceActiveTimerBadge extends ConsumerWidget {
  const WorkspaceActiveTimerBadge({super.key, required this.open});

  final ValueChanged<String> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActiveTimer = ref.watch(
      appControllerProvider.select((c) => c.activeTimer != null),
    );
    if (!hasActiveTimer) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: CompactTaskTimer(open: open),
    );
  }
}
