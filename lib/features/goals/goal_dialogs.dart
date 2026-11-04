import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/dialog_action_bar.dart';
import '../shared/unsaved_editor_guard.dart';

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
  bool saved = false;
  final guard = GlobalKey<UnsavedEditorGuardState>();
  late String baseline;

  String get snapshot => jsonEncode([
    title.text,
    description.text,
    target.text,
    unit.text,
    startDate,
    deadlineDate,
  ]);

  void _changed() => setState(() {});

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
    baseline = snapshot;
    for (final field in [title, description, target, unit]) {
      field.addListener(_changed);
    }
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
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        startDate = localDate(picked);
      } else {
        deadlineDate = localDate(picked);
      }
    });
  }

  Future<void> _save() async {
    if (busy) return;
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
      if (mounted) {
        saved = true;
        await guard.currentState?.close(saved: true);
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedEditorGuard(
    key: guard,
    enabled: true,
    dirty: snapshot != baseline,
    busy: busy,
    onClose: () => Navigator.pop(context, saved),
    child: Dialog(
      child: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width - 48, 520),
        height: math.min(MediaQuery.sizeOf(context).height - 48, 440),
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
                  key: const ValueKey('goal-editor-form-list'),
                  padding: const EdgeInsets.fromLTRB(0, 8, 14, 12),
                  children: [
                    TextField(
                      enabled: !busy,
                      key: const ValueKey('goal-editor-title'),
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      enabled: !busy,
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            enabled: !busy,
                            key: const ValueKey('goal-editor-target'),
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
                            enabled: !busy,
                            controller: unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: busy ? null : () => _pick(start: true),
                      child: Text('Start day: $startDate'),
                    ),
                    const SizedBox(height: 8),
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
              DialogActionBar(
                children: [
                  TextButton(
                    onPressed: busy ? null : () => guard.currentState?.close(),
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
    ),
  );
}

class GoalMilestoneDialog extends ConsumerStatefulWidget {
  const GoalMilestoneDialog({super.key, required this.goal, this.previous});
  final Goal goal;
  final GoalMilestone? previous;

  @override
  ConsumerState<GoalMilestoneDialog> createState() =>
      _GoalMilestoneDialogState();
}

class _GoalMilestoneDialogState extends ConsumerState<GoalMilestoneDialog> {
  final guard = GlobalKey<UnsavedEditorGuardState>();
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.previous?.title ?? '')
    ..addListener(_changed);
  late final threshold = TextEditingController(
    text: widget.previous?.threshold.toString() ?? '',
  )..addListener(_changed);
  late String? deadline = widget.previous?.deadlineDate;
  bool busy = false;
  bool saved = false;
  String? error;

  void _changed() => setState(() {});

  @override
  void dispose() {
    title.dispose();
    threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final controller = ref.read(appControllerProvider);
      final amount = double.parse(threshold.text.trim());
      if (widget.previous == null) {
        await controller.addGoalMilestone(
          widget.goal,
          title.text,
          amount,
          deadline,
        );
      } else {
        await controller.updateGoalMilestone(
          widget.goal,
          widget.previous!,
          title.text,
          amount,
          deadline,
        );
      }
      if (mounted) {
        saved = true;
        await guard.currentState?.close(saved: true);
      }
    } catch (failure) {
      if (mounted) setState(() => error = 'Milestone was not saved: $failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedEditorGuard(
    key: guard,
    enabled: true,
    dirty:
        title.text != (widget.previous?.title ?? '') ||
        threshold.text != (widget.previous?.threshold.toString() ?? '') ||
        deadline != widget.previous?.deadlineDate,
    busy: busy,
    onClose: () => Navigator.pop(context, saved),
    child: AlertDialog(
      title: Text(
        widget.previous == null
            ? 'Milestone for ${widget.goal.title}'
            : 'Edit milestone',
      ),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('milestone-title'),
              autofocus: true,
              controller: title,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a title.'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('milestone-threshold'),
              controller: threshold,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Progress threshold (max ${widget.goal.target})',
              ),
              validator: (text) {
                final value = double.tryParse(text?.trim() ?? '');
                return value == null ||
                        !value.isFinite ||
                        value <= 0 ||
                        value > widget.goal.target
                    ? 'Enter a positive threshold within the goal target.'
                    : null;
              },
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: deadline == null
                            ? DateTime.now()
                            : DateTime.parse(deadline!),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && mounted) {
                        setState(() => deadline = localDate(picked));
                      }
                    },
              child: Text('Due: ${deadline ?? 'None'}'),
            ),
            if (deadline != null)
              TextButton(
                onPressed: busy ? null : () => setState(() => deadline = null),
                child: const Text('Clear deadline'),
              ),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => guard.currentState?.close(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: Text(
            widget.previous == null ? 'Add milestone' : 'Save milestone',
          ),
        ),
      ],
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
  bool saved = false;
  String? error;
  bool loaded = false;
  final guard = GlobalKey<UnsavedEditorGuardState>();
  String baseline = '';
  String get snapshot => jsonEncode([
    taskIds.toList()..sort(),
    projectIds.toList()..sort(),
    habitIds.toList()..sort(),
  ]);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final links = await ref
          .read(appControllerProvider)
          .goalLinks(widget.goal.id);
      if (!mounted) return;
      setState(() {
        taskIds = {...links.taskIds};
        projectIds = {...links.projectIds};
        habitIds = {...links.habitIds};
        baseline = snapshot;
        loaded = true;
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
    if (busy || loading || !loaded) return;
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
      if (mounted) {
        saved = true;
        await guard.currentState?.close(saved: true);
      }
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
    return UnsavedEditorGuard(
      key: guard,
      enabled: true,
      dirty: loaded && snapshot != baseline,
      busy: busy,
      onClose: () => Navigator.pop(context, saved),
      child: Dialog(
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
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          children: [
                            const Text(
                              'Each completed task and successful Yes/No habit day adds one unit. Tasks linked through a project count only once.',
                            ),
                            if (!loaded) ...[
                              Text(
                                error ?? 'Links could not be loaded.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ] else ...[
                              TextField(
                                enabled: !busy,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Filter tasks, projects, and habits',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (value) => setState(
                                  () => filter = value.toLowerCase(),
                                ),
                              ),
                              if (options.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text('No matching work.'),
                                ),
                              for (final item in options)
                                CheckboxListTile(
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
                                ),
                              if (error != null)
                                Text(
                                  error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                            ],
                          ],
                        ),
                ),
                DialogActionBar(
                  children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => guard.currentState?.close(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: busy || loading || !loaded ? null : _save,
                      child: const Text('Save links'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
