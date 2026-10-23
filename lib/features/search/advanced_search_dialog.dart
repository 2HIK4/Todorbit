import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/saved_views.dart';

class AdvancedSearchDialog extends ConsumerStatefulWidget {
  const AdvancedSearchDialog({
    super.key,
    this.savedView,
    this.creatingSavedView = false,
  });
  final SavedView? savedView;
  final bool creatingSavedView;

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
  late String? categoryId = widget.savedView?.filter.categoryId;
  late String? projectId = widget.savedView?.filter.projectId;
  late int minimumPriority = widget.savedView?.filter.minimumPriority ?? 0;
  late ScheduledFilter scheduled =
      widget.savedView?.filter.scheduled ?? ScheduledFilter.any;
  late DeadlineFilter deadline =
      widget.savedView?.filter.deadline ?? DeadlineFilter.any;
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
    categoryId: categoryId,
    projectId: projectId,
    minimumPriority: minimumPriority,
    scheduled: scheduled,
    deadline: deadline,
    recurringOnly: recurringOnly,
    blockedOnly: blockedOnly,
    sort: sort,
  );

  Future<void> _save() async {
    var chosen = name.text.trim();
    if (!widget.creatingSavedView && widget.savedView == null) {
      final dialogName = await showDialog<String>(
        context: context,
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
    final projects = controller.projects.where(
      (item) => item.categoryId == categoryId,
    );
    final missingCategory =
        categoryId != null &&
        !controller.categories.any((item) => item.id == categoryId);
    final missingProject =
        projectId != null && !projects.any((item) => item.id == projectId);
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
                                ? 'Create saved view'
                                : 'Advanced search'
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 14, 12),
                  children: [
                    if (widget.creatingSavedView ||
                        widget.savedView != null) ...[
                      TextField(
                        controller: name,
                        autofocus: widget.creatingSavedView,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'View name *',
                        ),
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
                    const Text('Status (none selected means any)'),
                    Wrap(
                      spacing: 6,
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
                    DropdownButtonFormField<String?>(
                      key: ValueKey('search-category:$categoryId'),
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Any category'),
                        ),
                        if (missingCategory)
                          DropdownMenuItem(
                            value: categoryId,
                            child: const Text('Deleted category'),
                          ),
                        for (final category in controller.categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        categoryId = value;
                        projectId = null;
                      }),
                    ),
                    if (categoryId != null)
                      DropdownButtonFormField<String?>(
                        key: ValueKey('search-project:$categoryId:$projectId'),
                        initialValue: projectId,
                        decoration: const InputDecoration(labelText: 'Project'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Any project'),
                          ),
                          if (missingProject)
                            DropdownMenuItem(
                              value: projectId,
                              child: const Text('Deleted project'),
                            ),
                          for (final project in projects)
                            DropdownMenuItem(
                              value: project.id,
                              child: Text(project.name),
                            ),
                        ],
                        onChanged: (value) => setState(() => projectId = value),
                      ),
                    DropdownButtonFormField<int>(
                      initialValue: minimumPriority,
                      decoration: const InputDecoration(
                        labelText: 'Minimum priority',
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Any priority')),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Low or higher'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('Medium or higher'),
                        ),
                        DropdownMenuItem(value: 3, child: Text('High only')),
                      ],
                      onChanged: (value) =>
                          setState(() => minimumPriority = value!),
                    ),
                    DropdownButtonFormField<ScheduledFilter>(
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
                    DropdownButtonFormField<DeadlineFilter>(
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
                    DropdownButtonFormField<SavedViewSort>(
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
                        onTap: () {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: busy ? null : _save,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(
                      widget.creatingSavedView
                          ? 'Create view'
                          : widget.savedView == null
                          ? 'Save as view'
                          : 'Update view',
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
