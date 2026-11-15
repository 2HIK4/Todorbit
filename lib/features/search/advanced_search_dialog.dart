import '../shared/scroll_edge_fade.dart';
import '../shared/app_motion.dart';
import '../shared/icon_picker.dart';

import 'package:life_manager/features/shared/anchored_select_field.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/saved_views.dart';
import '../shared/dialog_action_bar.dart';

class AdvancedSearchDialog extends ConsumerStatefulWidget {
  const AdvancedSearchDialog({
    super.key,
    this.savedView,
    this.creatingSavedView = false,
    this.beforeNavigate,
  });
  final SavedView? savedView;
  final bool creatingSavedView;
  final Future<bool> Function()? beforeNavigate;

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

  @override
  void dispose() {
    text.dispose();
    name.dispose();
    super.dispose();
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

    return Dialog(
      child: SizedBox(
        width: math.min(680, MediaQuery.sizeOf(context).width - 48),
        height: math.min(700, MediaQuery.sizeOf(context).height - 64),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.savedView == null
                          ? widget.creatingSavedView
                                ? 'Create Custom View'
                                : 'Advanced Search'
                          : 'Edit ${widget.savedView!.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: FadingListView(
                  key: const ValueKey('advanced-search-form-list'),
                  padding: const EdgeInsets.fromLTRB(0, 4, 14, 12),
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Multiple values in the same filter use OR (any match). Different filter types use AND (all must match).',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.creatingSavedView ||
                        widget.savedView != null) ...[
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
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: text,
                      autofocus:
                          !widget.creatingSavedView && widget.savedView == null,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText:
                            'Words in title, notes, category, or project',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Status (OR among selected · none selected means any)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final status in TaskStatus.values)
                          FilterChip(
                            label: Text(_statusLabel(status)),
                            selected: statuses.contains(status),
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
                    const SizedBox(height: 12),
                    const Text(
                      'Categories (OR among selected · none selected means any)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final category in controller.categories)
                          FilterChip(
                            label: Text(category.name),
                            selected: categoryIds.contains(category.id),
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
                    const SizedBox(height: 12),
                    const Text(
                      'Projects (OR among selected · none selected means any)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final project in relevantProjects)
                          FilterChip(
                            label: Text(project.name),
                            selected: projectIds.contains(project.id),
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
                    const SizedBox(height: 12),
                    const Text(
                      'Priority (OR among selected · none selected means any)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
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
                    const SizedBox(height: 12),
                    AnchoredSelectField<ScheduledFilter>(
                      isExpanded: true,
                      initialValue: scheduled,
                      decoration: const InputDecoration(
                        labelText: 'Planned day',
                      ),
                      items: [
                        for (final value in ScheduledFilter.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_plannedLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => scheduled = value!),
                    ),
                    const SizedBox(height: 12),
                    AnchoredSelectField<DeadlineFilter>(
                      isExpanded: true,
                      initialValue: deadline,
                      decoration: const InputDecoration(labelText: 'Deadline'),
                      items: [
                        for (final value in DeadlineFilter.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_deadlineLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(() => deadline = value!),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Recurring tasks only'),
                      value: recurringOnly,
                      onChanged: (value) =>
                          setState(() => recurringOnly = value),
                    ),
                    SwitchListTile(
                      title: const Text('Blocked by unfinished prerequisites'),
                      value: blockedOnly,
                      onChanged: (value) => setState(() => blockedOnly = value),
                    ),
                    const SizedBox(height: 12),
                    AnchoredSelectField<SavedViewSort>(
                      isExpanded: true,
                      initialValue: sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort results by',
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
                    const Divider(),
                    for (final task in matches.take(50))
                      ListTile(
                        dense: true,
                        title: Text(task.title),
                        subtitle: Text(
                          '${_statusLabel(task.status)}${task.scheduledDate == null ? '' : ' · ${task.scheduledDate}'}',
                        ),
                        onTap: () async {
                          if (widget.beforeNavigate != null &&
                              !await widget.beforeNavigate!()) {
                            return;
                          }
                          if (!context.mounted) return;
                          controller.navigate(
                            task.isOpen
                                ? WorkspaceView.all
                                : WorkspaceView.completed,
                          );
                          controller.select(task.id);
                          Navigator.pop(context);
                        },
                      ),
                    if (matches.length > 50)
                      Text(
                        'Showing first 50 of ${matches.length}. Save the view to see all matches.',
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${matches.length} matching tasks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              DialogActionBar(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : _save,
                    icon: const Icon(Icons.bookmark_add_outlined),
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
