import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/saved_views.dart';
import '../shared/anchored_select_field.dart';
import '../shared/app_motion.dart';
import '../shared/dialog_action_bar.dart';
import '../shared/icon_picker.dart';
import '../shared/scroll_edge_fade.dart';

class AdvancedSearchDialog extends ConsumerStatefulWidget {
  const AdvancedSearchDialog({
    super.key,
    this.savedView,
    this.creatingSavedView = false,
    this.beforeNavigate,
    this.onTaskTap,
  });
  final SavedView? savedView;
  final bool creatingSavedView;
  final Future<bool> Function()? beforeNavigate;
  final ValueChanged<LifeTask>? onTaskTap;

  @override
  ConsumerState<AdvancedSearchDialog> createState() =>
      _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends ConsumerState<AdvancedSearchDialog> {
  late final TextEditingController text = TextEditingController(
    text: widget.savedView?.filter.text ?? '',
  );
  late final TextEditingController name = TextEditingController(
    text: widget.savedView?.name ?? '',
  );
  final ScrollController _scrollController = ScrollController();
  late SavedViewSort sort =
      widget.savedView?.filter.sort ?? SavedViewSort.scheduled;
  late Set<TaskStatus> statuses = {...?widget.savedView?.filter.statuses};
  late Set<String> categoryIds = {
    ...?widget.savedView?.filter.categoryIds,
    if (widget.savedView?.filter.categoryId != null)
      widget.savedView!.filter.categoryId!,
  };
  late Set<String> projectIds = {
    ...?widget.savedView?.filter.projectIds,
    if (widget.savedView?.filter.projectId != null)
      widget.savedView!.filter.projectId!,
  };
  late Set<int> priorities = {
    ...?widget.savedView?.filter.priorities,
    if (widget.savedView?.filter.minimumPriority != null &&
        widget.savedView!.filter.minimumPriority > 0)
      for (var i = widget.savedView!.filter.minimumPriority; i <= 3; i++) i,
  };
  late String? iconKey =
      widget.savedView?.iconKey ?? widget.savedView?.filter.iconKey;
  late ScheduledFilter scheduled =
      widget.savedView?.filter.scheduled ?? ScheduledFilter.any;
  late DeadlineFilter deadline =
      widget.savedView?.filter.deadline ?? DeadlineFilter.any;
  late final String? fromDate = widget.savedView?.filter.fromDate;
  late final String? throughDate = widget.savedView?.filter.throughDate;
  late final bool nonRecurringOnly =
      widget.savedView?.filter.nonRecurringOnly ?? false;
  late bool recurringOnly = widget.savedView?.filter.recurringOnly ?? false;
  late bool blockedOnly = widget.savedView?.filter.blockedOnly ?? false;
  bool busy = false;
  String? error;
  bool _matchingTasksExpanded = false;

  @override
  void dispose() {
    text.dispose();
    name.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      text.text.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      categoryIds.isNotEmpty ||
      projectIds.isNotEmpty ||
      priorities.isNotEmpty ||
      scheduled != ScheduledFilter.any ||
      deadline != DeadlineFilter.any ||
      recurringOnly ||
      blockedOnly;

  void _resetFilters() {
    setState(() {
      text.clear();
      statuses.clear();
      categoryIds.clear();
      projectIds.clear();
      priorities.clear();
      scheduled = ScheduledFilter.any;
      deadline = DeadlineFilter.any;
      recurringOnly = false;
      blockedOnly = false;
      sort = SavedViewSort.scheduled;
    });
  }

  TaskFilter get filter => TaskFilter(
    text: text.text,
    statuses: statuses,
    categoryIds: categoryIds,
    projectIds: projectIds,
    priorities: priorities,
    scheduled: scheduled,
    deadline: deadline,
    recurringOnly: recurringOnly,
    nonRecurringOnly: nonRecurringOnly && !recurringOnly,
    fromDate: fromDate,
    throughDate: throughDate,
    blockedOnly: blockedOnly,
    sort: sort,
    iconKey: iconKey,
  );

  Future<void> _save() async {
    var chosen = name.text.trim();
    if (!widget.creatingSavedView && widget.savedView == null) {
      final dialogName = await showDialog<String>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (dialogContext) => AlertDialog(
          title: Text(
            widget.savedView == null ? 'Save view' : 'Update saved view',
          ),
          content: TextFormField(
            initialValue: chosen,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'View name'),
            onChanged: (value) => chosen = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, chosen),
              child: const Text('Save view'),
            ),
          ],
        ),
      );
      if (dialogName == null || !mounted) return;
      chosen = dialogName.trim();
    }
    if (chosen.isEmpty) {
      setState(() => error = 'Enter a view name.');
      return;
    }
    if (widget.beforeNavigate != null && !await widget.beforeNavigate!()) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final controller = ref.read(appControllerProvider);
      if (widget.savedView case final previous?) {
        await controller.updateSavedView(previous, chosen, filter);
      } else {
        await controller.addSavedView(chosen, filter);
      }
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final matches = controller.searchTasks(filter);
    final relevantProjects = categoryIds.isEmpty
        ? controller.projects
        : controller.projects.where((p) => categoryIds.contains(p.categoryId));

    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 600 || Platform.isAndroid;
    final availableHeight =
        media.size.height - media.viewInsets.bottom - (isMobile ? 24 : 48);
    final dialogWidth = isMobile
        ? math.min(660.0, math.max(280.0, media.size.width - 24))
        : math.min(660.0, media.size.width - 48);
    final dialogHeight = availableHeight.clamp(280.0, 720.0);
    final scheme = Theme.of(context).colorScheme;

    final categoriesMap = {
      for (final cat in controller.categories) cat.id: cat.name,
    };
    final projectsMap = {
      for (final proj in controller.projects) proj.id: proj.name,
    };

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.savedView == null
                          ? widget.creatingSavedView
                                ? 'Create Custom View'
                                : 'Advanced Search'
                          : 'Edit ${widget.savedView!.name}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_hasActiveFilters)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: _resetFilters,
                      child: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  IconButton(
                    iconSize: 20,
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable Form with Progressive Disclosure
            Expanded(
              child: FadingListView(
                key: const ValueKey('advanced-search-form-list'),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                children: [
                  // Lightweight One-Time Explanation
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 15,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filters combine with AND; options within each filter combine with OR.',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.creatingSavedView || widget.savedView != null) ...[
                    Row(
                      children: [
                        IconButton.outlined(
                          tooltip: 'Choose view icon',
                          onPressed: () async {
                            final (chosen, key) = await chooseBuiltInIcon(
                              context,
                              current: iconKey,
                            );
                            if (chosen && mounted) {
                              setState(() => iconKey = key);
                            }
                          },
                          icon: Icon(
                            iconForKey(iconKey, Icons.bookmark_outline),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: name,
                            autofocus: widget.creatingSavedView,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'View name *',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Search keywords text input
                  TextField(
                    controller: text,
                    autofocus:
                        !widget.creatingSavedView && widget.savedView == null,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      labelText: 'Words in title, notes, category, or project',
                      suffixIcon: text.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: 'Clear query',
                              onPressed: () {
                                text.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),

                  // Collapsible Group 1: Status
                  _CollapsibleFilterGroup(
                    title: 'Status',
                    icon: Icons.task_alt_outlined,
                    initiallyExpanded: statuses.isNotEmpty,
                    badgeCount: statuses.length,
                    summary: statuses.isEmpty
                        ? 'All statuses'
                        : statuses.map(_statusLabel).join(', '),
                    onClear: statuses.isNotEmpty
                        ? () => setState(() => statuses.clear())
                        : null,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final status in TaskStatus.values)
                          FilterChip(
                            label: Text(_statusLabel(status)),
                            selected: statuses.contains(status),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                statuses.add(status);
                              } else {
                                statuses.remove(status);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),

                  // Collapsible Group 2: Categories
                  if (controller.categories.isNotEmpty)
                    _CollapsibleFilterGroup(
                      title: 'Categories',
                      icon: Icons.folder_outlined,
                      initiallyExpanded: categoryIds.isNotEmpty,
                      badgeCount: categoryIds.length,
                      summary: categoryIds.isEmpty
                          ? 'All categories'
                          : categoryIds.length == 1
                          ? (categoriesMap[categoryIds.first] ?? '1 selected')
                          : '${categoryIds.length} selected',
                      onClear: categoryIds.isNotEmpty
                          ? () => setState(() => categoryIds.clear())
                          : null,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final category in controller.categories)
                            FilterChip(
                              label: Text(category.name),
                              selected: categoryIds.contains(category.id),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  categoryIds.add(category.id);
                                } else {
                                  categoryIds.remove(category.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),

                  // Collapsible Group 3: Projects
                  if (relevantProjects.isNotEmpty)
                    _CollapsibleFilterGroup(
                      title: 'Projects',
                      icon: Icons.folder_open_outlined,
                      initiallyExpanded: projectIds.isNotEmpty,
                      badgeCount: projectIds.length,
                      summary: projectIds.isEmpty
                          ? 'All projects'
                          : projectIds.length == 1
                          ? (projectsMap[projectIds.first] ?? '1 selected')
                          : '${projectIds.length} selected',
                      onClear: projectIds.isNotEmpty
                          ? () => setState(() => projectIds.clear())
                          : null,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final project in relevantProjects)
                            FilterChip(
                              label: Text(project.name),
                              selected: projectIds.contains(project.id),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  projectIds.add(project.id);
                                } else {
                                  projectIds.remove(project.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),

                  // Collapsible Group 4: Priority
                  _CollapsibleFilterGroup(
                    title: 'Priority',
                    icon: Icons.flag_outlined,
                    initiallyExpanded: priorities.isNotEmpty,
                    badgeCount: priorities.length,
                    summary: priorities.isEmpty
                        ? 'All priorities'
                        : priorities.map(_priorityLabel).join(', '),
                    onClear: priorities.isNotEmpty
                        ? () => setState(() => priorities.clear())
                        : null,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final (level, label) in [
                          (0, 'None'),
                          (1, 'Low'),
                          (2, 'Medium'),
                          (3, 'High'),
                        ])
                          FilterChip(
                            label: Text(label),
                            selected: priorities.contains(level),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                priorities.add(level);
                              } else {
                                priorities.remove(level);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),

                  // Collapsible Group 5: Dates & Deadlines
                  _CollapsibleFilterGroup(
                    title: 'Dates & Deadlines',
                    icon: Icons.calendar_today_outlined,
                    initiallyExpanded:
                        scheduled != ScheduledFilter.any ||
                        deadline != DeadlineFilter.any,
                    badgeCount:
                        (scheduled != ScheduledFilter.any ? 1 : 0) +
                        (deadline != DeadlineFilter.any ? 1 : 0),
                    summary:
                        '${_plannedLabel(scheduled)} · ${_deadlineLabel(deadline)}',
                    onClear:
                        (scheduled != ScheduledFilter.any ||
                            deadline != DeadlineFilter.any)
                        ? () => setState(() {
                            scheduled = ScheduledFilter.any;
                            deadline = DeadlineFilter.any;
                          })
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnchoredSelectField<ScheduledFilter>(
                          isExpanded: true,
                          initialValue: scheduled,
                          decoration: const InputDecoration(
                            labelText: 'Planned day',
                            isDense: true,
                          ),
                          items: [
                            for (final value in ScheduledFilter.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(_plannedLabel(value)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => scheduled = value!),
                        ),
                        const SizedBox(height: 10),
                        AnchoredSelectField<DeadlineFilter>(
                          isExpanded: true,
                          initialValue: deadline,
                          decoration: const InputDecoration(
                            labelText: 'Deadline',
                            isDense: true,
                          ),
                          items: [
                            for (final value in DeadlineFilter.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(_deadlineLabel(value)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => deadline = value!),
                        ),
                      ],
                    ),
                  ),

                  // Collapsible Group 6: Properties
                  _CollapsibleFilterGroup(
                    title: 'Properties',
                    icon: Icons.check_circle_outline,
                    initiallyExpanded: recurringOnly || blockedOnly,
                    badgeCount: (recurringOnly ? 1 : 0) + (blockedOnly ? 1 : 0),
                    summary: recurringOnly && blockedOnly
                        ? 'Recurring & Blocked'
                        : recurringOnly
                        ? 'Recurring only'
                        : blockedOnly
                        ? 'Blocked only'
                        : 'All tasks',
                    onClear: (recurringOnly || blockedOnly)
                        ? () => setState(() {
                            recurringOnly = false;
                            blockedOnly = false;
                          })
                        : null,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Recurring tasks only'),
                          value: recurringOnly,
                          onChanged: (value) =>
                              setState(() => recurringOnly = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text(
                            'Blocked by unfinished prerequisites',
                          ),
                          value: blockedOnly,
                          onChanged: (value) =>
                              setState(() => blockedOnly = value),
                        ),
                      ],
                    ),
                  ),

                  // Collapsible Group 7: Sort
                  _CollapsibleFilterGroup(
                    title: 'Sort Results',
                    icon: Icons.sort_outlined,
                    initiallyExpanded: false,
                    summary: _sortLabel(sort),
                    child: AnchoredSelectField<SavedViewSort>(
                      isExpanded: true,
                      initialValue: sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort results by',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: SavedViewSort.scheduled,
                          child: Text('Scheduled day'),
                        ),
                        DropdownMenuItem(
                          value: SavedViewSort.priority,
                          child: Text('Priority'),
                        ),
                        DropdownMenuItem(
                          value: SavedViewSort.title,
                          child: Text('Title'),
                        ),
                        DropdownMenuItem(
                          value: SavedViewSort.created,
                          child: Text('Created'),
                        ),
                      ],
                      onChanged: (value) => setState(() => sort = value!),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Matching Tasks Section
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    color: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () => setState(
                            () => _matchingTasksExpanded =
                                !_matchingTasksExpanded,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.list_alt,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Preview Matching Tasks (${matches.length})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: scheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  _matchingTasksExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 20,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_matchingTasksExpanded) ...[
                          const Divider(height: 1),
                          if (matches.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text('No tasks match current filters.'),
                              ),
                            )
                          else
                            for (final task in matches.take(50))
                              ListTile(
                                dense: true,
                                title: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${_statusLabel(task.status)}${task.scheduledDate == null ? '' : ' · ${task.scheduledDate}'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () async {
                                  if (widget.beforeNavigate != null &&
                                      !await widget.beforeNavigate!()) {
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  if (widget.onTaskTap != null) {
                                    widget.onTaskTap!(task);
                                  } else {
                                    controller.navigate(
                                      task.isOpen
                                          ? WorkspaceView.all
                                          : WorkspaceView.completed,
                                    );
                                    controller.select(task.id);
                                  }
                                  Navigator.pop(context);
                                },
                              ),
                          if (matches.length > 50)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Showing first 50 of ${matches.length}. Save the view to see all matches.',
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            // Compact Sticky Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${matches.length} matching tasks',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DialogActionBar(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        onPressed: busy ? null : _save,
                        icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                        label: Text(
                          widget.creatingSavedView
                              ? 'Create Custom View'
                              : widget.savedView == null
                              ? 'Save as Custom View'
                              : 'Update Custom View',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleFilterGroup extends StatefulWidget {
  const _CollapsibleFilterGroup({
    required this.title,
    required this.icon,
    required this.summary,
    required this.child,
    this.initiallyExpanded = false,
    this.badgeCount,
    this.onClear,
  });

  final String title;
  final IconData icon;
  final String summary;
  final Widget child;
  final bool initiallyExpanded;
  final int? badgeCount;
  final VoidCallback? onClear;

  @override
  State<_CollapsibleFilterGroup> createState() =>
      _CollapsibleFilterGroupState();
}

class _CollapsibleFilterGroupState extends State<_CollapsibleFilterGroup> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasActive = (widget.badgeCount ?? 0) > 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: hasActive
          ? scheme.secondaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: hasActive
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: hasActive ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 3,
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: hasActive ? scheme.primary : scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.badgeCount != null && widget.badgeCount! > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.badgeCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: Text(
                      widget.summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (hasActive && widget.onClear != null)
                    IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      tooltip: 'Clear ${widget.title} filter',
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClear,
                    ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

String _statusLabel(TaskStatus status) => switch (status) {
  TaskStatus.notStarted => 'Not started',
  TaskStatus.inProgress => 'In progress',
  TaskStatus.waiting => 'Waiting',
  TaskStatus.onHold => 'On hold',
  TaskStatus.completed => 'Completed',
  TaskStatus.cancelled => 'Cancelled',
};

String _plannedLabel(ScheduledFilter filter) => switch (filter) {
  ScheduledFilter.any => 'Any planned day',
  ScheduledFilter.today => 'Today',
  ScheduledFilter.nextSevenDays => 'Next seven days',
  ScheduledFilter.future => 'After today',
  ScheduledFilter.unscheduled => 'Unscheduled',
};

String _deadlineLabel(DeadlineFilter filter) => switch (filter) {
  DeadlineFilter.any => 'Any deadline',
  DeadlineFilter.overdue => 'Overdue',
  DeadlineFilter.nextSevenDays => 'Due in next seven days',
  DeadlineFilter.noDeadline => 'No deadline',
};

String _priorityLabel(int priority) => switch (priority) {
  1 => 'Low',
  2 => 'Medium',
  3 => 'High',
  _ => 'None',
};

String _sortLabel(SavedViewSort sort) => switch (sort) {
  SavedViewSort.scheduled => 'Scheduled day',
  SavedViewSort.priority => 'Priority',
  SavedViewSort.title => 'Title',
  SavedViewSort.created => 'Created',
};
