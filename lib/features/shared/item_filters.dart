import 'app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../domain/saved_views.dart';
import 'anchored_select_field.dart';
import 'scroll_edge_fade.dart';

class ItemFilters extends ConsumerWidget {
  const ItemFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final f = c.activeFilter;
    final categories = {for (final item in c.categories) item.id: item.name};
    final projects = {for (final item in c.projects) item.id: item.name};
    final chips = <(String, Map<String, dynamic>)>[
      if (f.categoryId != null)
        (
          categories[f.categoryId] ?? 'Unavailable category',
          {'category_id': null, 'project_id': null},
        ),
      if (f.projectId != null)
        (projects[f.projectId] ?? 'Unavailable project', {'project_id': null}),
      if (f.statuses.isNotEmpty)
        ('${f.statuses.length} statuses', {'statuses': <String>[]}),
      if (f.minimumPriority > 0)
        ('Priority ≥ ${f.minimumPriority}', {'minimum_priority': 0}),
      if (f.recurringOnly || f.nonRecurringOnly)
        (
          f.recurringOnly ? 'Recurring' : 'Non-recurring',
          {'recurring_only': false, 'non_recurring_only': false},
        ),
      if (f.fromDate != null || f.throughDate != null)
        (
          '${f.fromDate ?? 'Any date'} – ${f.throughDate ?? 'Any date'}',
          {'from_date': null, 'through_date': null},
        ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          icon: Icon(f.isActive ? Icons.filter_alt : Icons.filter_alt_outlined),
          label: Text(f.isActive ? 'Filters active' : 'Filters'),
          onPressed: () async {
            final selected = await showDialog<TaskFilter>(
              context: context,
              animationStyle: AppMotion.style(context),
              builder: (_) => _FilterDialog(controller: c, initial: f),
            );
            if (selected != null) c.setFilter(selected);
          },
        ),
        for (final (label, changes) in chips)
          InputChip(
            label: Text(label),
            onDeleted: () => c.setFilter(f.change(changes)),
          ),
        if (f.isActive)
          TextButton(
            onPressed: () => c.setFilter(const TaskFilter()),
            child: const Text('Clear all'),
          ),
      ],
    );
  }
}

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({required this.controller, required this.initial});
  final AppController controller;
  final TaskFilter initial;
  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late TaskFilter filter = widget.initial;
  void change(Map<String, dynamic> values) =>
      setState(() => filter = filter.change(values));
  Future<void> pickDate(bool start) async {
    final first = !start && filter.fromDate != null
        ? DateTime.parse(filter.fromDate!)
        : DateTime(1900);
    final last = start && filter.throughDate != null
        ? DateTime.parse(filter.throughDate!)
        : DateTime(2200);
    final raw = start ? filter.fromDate : filter.throughDate;
    final initial = raw == null ? DateTime.now() : DateTime.parse(raw);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(last)
          ? last
          : initial,
      firstDate: first,
      lastDate: last,
    );
    if (selected != null && mounted) {
      change({start ? 'from_date' : 'through_date': localDate(selected)});
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Filter tasks and events'),
    content: SizedBox(
      width: 440,
      height: MediaQuery.sizeOf(context).height * .55,
      child: FadingScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filters combine. Selected statuses match any selected status. Status and priority apply to tasks.',
            ),
            const SizedBox(height: 16),
            AnchoredSelectField<String>(
              key: ValueKey('category:${filter.categoryId}'),
              initialValue: filter.categoryId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All categories'),
                ),
                if (filter.categoryId != null &&
                    !widget.controller.categories.any(
                      (c) => c.id == filter.categoryId,
                    ))
                  DropdownMenuItem(
                    value: filter.categoryId!,
                    child: const Text('Unavailable category'),
                  ),
                for (final item in widget.controller.categories)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (id) => change({
                'category_id': id == '' ? null : id,
                'project_id': null,
              }),
            ),
            const SizedBox(height: 12),
            AnchoredSelectField<String>(
              key: ValueKey('project:${filter.projectId}:${filter.categoryId}'),
              initialValue: filter.projectId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All projects')),
                if (filter.projectId != null &&
                    !widget.controller.projects.any(
                      (p) => p.id == filter.projectId,
                    ))
                  DropdownMenuItem(
                    value: filter.projectId!,
                    child: const Text('Unavailable project'),
                  ),
                for (final item in widget.controller.projects.where(
                  (p) =>
                      filter.categoryId == null ||
                      p.categoryId == filter.categoryId,
                ))
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: (id) => change({'project_id': id == '' ? null : id}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final status in TaskStatus.values)
                  FilterChip(
                    label: Text(switch (status) {
                      TaskStatus.notStarted => 'Not started',
                      TaskStatus.inProgress => 'In progress',
                      TaskStatus.onHold => 'On hold',
                      TaskStatus.waiting => 'Waiting',
                      TaskStatus.completed => 'Completed',
                      TaskStatus.cancelled => 'Cancelled',
                    }),
                    selected: filter.statuses.contains(status),
                    onSelected: (selected) {
                      final statuses = {...filter.statuses};
                      selected ? statuses.add(status) : statuses.remove(status);
                      change({
                        'statuses': statuses.map((s) => s.name).toList(),
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AnchoredSelectField<int>(
              initialValue: filter.minimumPriority,
              decoration: const InputDecoration(labelText: 'Minimum priority'),
              items: [
                for (final (value, label) in [
                  (0, 'Any priority'),
                  (1, 'Low'),
                  (2, 'Medium'),
                  (3, 'High'),
                ])
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: (v) => change({'minimum_priority': v}),
            ),
            const SizedBox(height: 12),
            AnchoredSelectField<int>(
              initialValue: filter.recurringOnly
                  ? 1
                  : filter.nonRecurringOnly
                  ? 2
                  : 0,
              decoration: const InputDecoration(labelText: 'Recurrence'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('All items')),
                DropdownMenuItem(value: 1, child: Text('Recurring')),
                DropdownMenuItem(value: 2, child: Text('Non-recurring')),
              ],
              onChanged: (v) => change({
                'recurring_only': v == 1,
                'non_recurring_only': v == 2,
              }),
            ),
            const SizedBox(height: 12),
            for (final start in [true, false])
              TextButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(
                  '${start ? 'From' : 'Through'}: ${(start ? filter.fromDate : filter.throughDate) ?? 'Any date'}',
                ),
                onPressed: () => pickDate(start),
              ),
            if (filter.fromDate != null &&
                filter.throughDate != null &&
                filter.fromDate!.compareTo(filter.throughDate!) > 0)
              Text(
                'Through must be on or after From.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            filter.fromDate != null &&
                filter.throughDate != null &&
                filter.fromDate!.compareTo(filter.throughDate!) > 0
            ? null
            : () => Navigator.pop(context, filter),
        child: const Text('Apply'),
      ),
    ],
  );
}
