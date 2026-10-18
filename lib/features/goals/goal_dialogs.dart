import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/goals.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';

class GoalEditorDialog extends ConsumerStatefulWidget {
  const GoalEditorDialog({super.key, this.goal});
  final Goal? goal;
  @override
  ConsumerState<GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends ConsumerState<GoalEditorDialog> {
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController target;
  late final TextEditingController unit;
  late String startDate;
  String? deadlineDate;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    title = TextEditingController(text: goal?.title ?? '');
    description = TextEditingController(text: goal?.description ?? '');
    target = TextEditingController(text: goal?.target.toString() ?? '');
    unit = TextEditingController(text: goal?.unit ?? '');
    startDate = goal?.startDate ?? localDate(DateTime.now());
    deadlineDate = goal?.deadlineDate;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    target.dispose();
    unit.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final current = start ? startDate : deadlineDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null ? DateTime.now() : DateTime.parse(current),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        startDate = localDate(picked);
      } else {
        deadlineDate = localDate(picked);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final amount = double.tryParse(target.text.trim());
      if (amount == null || !amount.isFinite || amount <= 0) {
        throw const FormatException('Target must be a positive number');
      }
      final draft = GoalDraft(
        title: title.text,
        description: description.text,
        target: amount,
        unit: unit.text,
        startDate: startDate,
        deadlineDate: deadlineDate,
      );
      final controller = ref.read(appControllerProvider);
      if (widget.goal == null) {
        await controller.addGoal(draft);
      } else {
        await controller.updateGoal(widget.goal!, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: math.min(MediaQuery.sizeOf(context).width - 48, 520),
      height: math.min(MediaQuery.sizeOf(context).height - 48, 520),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.goal == null ? 'New goal' : 'Edit goal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: target,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Target *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => _pick(start: true),
                    child: Text('Start day: $startDate'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => _pick(start: false),
                          child: Text('Deadline: ${deadlineDate ?? 'None'}'),
                        ),
                      ),
                      if (deadlineDate != null)
                        IconButton(
                          tooltip: 'Clear deadline',
                          icon: const Icon(Icons.close),
                          onPressed: busy
                              ? null
                              : () => setState(() => deadlineDate = null),
                        ),
                    ],
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: Text(
                    widget.goal == null ? 'Create goal' : 'Save goal',
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

class GoalLinksDialog extends ConsumerStatefulWidget {
  const GoalLinksDialog({super.key, required this.goal});
  final Goal goal;
  @override
  ConsumerState<GoalLinksDialog> createState() => _GoalLinksDialogState();
}

class _GoalLinksDialogState extends ConsumerState<GoalLinksDialog> {
  Set<String> taskIds = {};
  Set<String> projectIds = {};
  Set<String> habitIds = {};
  String filter = '';
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final links = await ref
          .read(appControllerProvider)
          .goalLinks(widget.goal.id);
      if (!mounted) return;
      setState(() {
        taskIds = {...links.taskIds};
        projectIds = {...links.projectIds};
        habitIds = {...links.habitIds};
        loading = false;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = '$failure';
          loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(appControllerProvider)
          .setGoalLinks(
            widget.goal,
            GoalLinks(
              taskIds: taskIds,
              projectIds: projectIds,
              habitIds: habitIds,
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final options = <(String, String, String, Set<String>)>[
      for (final task in controller.tasks)
        ('Task', task.id, task.title, taskIds),
      for (final project in controller.projects)
        ('Project', project.id, project.name, projectIds),
      for (final habit in controller.habits.where(
        (item) => item.kind == HabitKind.binary,
      ))
        ('Yes/No habit', habit.id, habit.title, habitIds),
    ].where((item) => item.$3.toLowerCase().contains(filter)).toList();
    return Dialog(
      child: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width - 48, 600),
        height: math.min(MediaQuery.sizeOf(context).height - 48, 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Linked progress',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'A completed task counts once, even when linked directly and through a project. Each completed task and successful Yes/No habit day adds one unit.',
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Filter tasks, projects, and habits',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => filter = value.toLowerCase()),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final item = options[index];
                          return CheckboxListTile(
                            dense: true,
                            value: item.$4.contains(item.$2),
                            title: Text(item.$3),
                            subtitle: Text(item.$1),
                            onChanged: busy
                                ? null
                                : (selected) => setState(() {
                                    selected == true
                                        ? item.$4.add(item.$2)
                                        : item.$4.remove(item.$2);
                                  }),
                          );
                        },
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
                    onPressed: busy
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: busy || loading ? null : _save,
                    child: const Text('Save links'),
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
