import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/goals.dart';
import '../../domain/models.dart';
import '../shared/about_view_button.dart';
import 'goal_dialogs.dart';

class GoalsView extends ConsumerStatefulWidget {
  const GoalsView({super.key});
  @override
  ConsumerState<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends ConsumerState<GoalsView> {
  bool showArchived = false;
  bool busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Goal was not changed: $failure')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit(Goal? goal) => showDialog<bool>(
    context: context,
    builder: (_) => GoalEditorDialog(goal: goal),
  );

  Future<void> _manual(Goal goal) async {
    var amount = '';
    var notes = '';
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust ${goal.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a positive amount for progress or a negative amount to correct an earlier manual entry. Linked work stays separate.',
            ),
            TextField(
              onChanged: (value) => amount = value,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText:
                    'Adjustment ${goal.unit.isEmpty ? '(units)' : goal.unit}',
              ),
            ),
            TextField(
              onChanged: (value) => notes = value,
              decoration: const InputDecoration(labelText: 'Reason or note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(amount.trim());
              if (parsed == null || !parsed.isFinite || parsed == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a nonzero number.')),
                );
                return;
              }
              Navigator.pop(context, (parsed, notes));
            },
            child: const Text('Save adjustment'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _run(
      () => ref
          .read(appControllerProvider)
          .addGoalProgress(goal, result.$1, result.$2),
    );
  }

  Future<void> _milestone(Goal goal, [GoalMilestone? previous]) async {
    var title = previous?.title ?? '';
    var threshold = previous?.threshold.toString() ?? '';
    String? deadline = previous?.deadlineDate;
    final result = await showDialog<(String, double, String?)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            previous == null ? 'Milestone for ${goal.title}' : 'Edit milestone',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: title,
                onChanged: (value) => title = value,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextFormField(
                initialValue: threshold,
                onChanged: (value) => threshold = value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Progress threshold (max ${goal.target})',
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: deadline == null
                        ? DateTime.now()
                        : DateTime.parse(deadline!),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => deadline = localDate(picked));
                  }
                },
                child: Text('Due: ${deadline ?? 'None'}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(threshold.trim());
                if (title.trim().isEmpty ||
                    value == null ||
                    !value.isFinite ||
                    value <= 0 ||
                    value > goal.target) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a title and threshold within the goal target.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, (title, value, deadline));
              },
              child: Text(
                previous == null ? 'Add milestone' : 'Save milestone',
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _run(
      () => previous == null
          ? ref
                .read(appControllerProvider)
                .addGoalMilestone(goal, result.$1, result.$2, result.$3)
          : ref
                .read(appControllerProvider)
                .updateGoalMilestone(
                  goal,
                  previous,
                  result.$1,
                  result.$2,
                  result.$3,
                ),
    );
  }

  Future<void> _history(Goal goal) async {
    final controller = ref.read(appControllerProvider);
    final history = await controller.goalProgressHistory(goal.id);
    final linked = await controller.goalLinkedEvents(goal);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${goal.title} progress'),
        content: SizedBox(
          width: 490,
          height: 380,
          child: ListView(
            children: [
              ListTile(
                title: const Text('Current linked contributions'),
                subtitle: Text(
                  'Tasks: ${goal.progress.tasks} · Habits: ${goal.progress.habits}',
                ),
              ),
              if (linked.isEmpty)
                const ListTile(title: Text('No completed linked work yet.')),
              for (final item in linked)
                ListTile(
                  dense: true,
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.localDate} · +${item.units} ${goal.unit}',
                  ),
                ),
              const Divider(),
              const Text('Manual adjustment history'),
              if (history.isEmpty)
                const ListTile(title: Text('No manual adjustments yet.')),
              for (final item in history)
                ListTile(
                  title: Text(
                    '${item.delta > 0 ? '+' : ''}${item.delta} ${goal.unit}',
                  ),
                  subtitle: Text(
                    '${item.createdAt.toLocal()}${item.notes.isEmpty ? '' : ' · ${item.notes}'}',
                  ),
                ),
            ],
          ),
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

  Future<void> _complete(Goal goal) async {
    if (!goal.completed && goal.progress.total < goal.target) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete below target?'),
          content: Text(
            'Current progress is ${goal.progress.total} of ${goal.target}. Completion is a separate decision.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mark complete'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    await _run(
      () => ref
          .read(appControllerProvider)
          .setGoalCompleted(goal, !goal.completed),
    );
  }

  Future<void> _archive(Goal goal) async {
    if (!goal.archived) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Archive ${goal.title}?'),
          content: const Text(
            'Progress and milestones stay saved. Archived goals can be restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    await _run(
      () =>
          ref.read(appControllerProvider).setGoalArchived(goal, !goal.archived),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final goals = controller.goals
        .where((item) => item.archived == showArchived)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Goals',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const AboutViewButton(
                description: 'Plan longer-term outcomes with milestones and a deadline. Track progress, complete milestones, and archive goals when they are no longer active.',
              ),
              FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('New goal'),
              ),
              FilterChip(
                label: const Text('Archived'),
                selected: showArchived,
                onSelected: (value) => setState(() => showArchived = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: goals.isEmpty
              ? Center(
                  child: Text(
                    showArchived
                        ? 'No archived goals.'
                        : 'No goals yet. Create one to track progress.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: goals.length,
                  itemBuilder: (context, index) =>
                      _card(context, controller, goals[index]),
                ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, AppController controller, Goal goal) {
    final today = localDate(DateTime.now());
    final overdue =
        !goal.completed &&
        goal.deadlineDate != null &&
        goal.deadlineDate!.compareTo(today) < 0;
    final milestones = controller.goalMilestones
        .where((item) => item.goalId == goal.id)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit goal',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: goal.archived ? null : () => _edit(goal),
                ),
                IconButton(
                  tooltip: goal.archived ? 'Restore goal' : 'Archive goal',
                  icon: Icon(
                    goal.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  onPressed: busy ? null : () => _archive(goal),
                ),
              ],
            ),
            if (goal.description.isNotEmpty) Text(goal.description),
            if (goal.deadlineDate != null)
              Text(
                'Deadline: ${goal.deadlineDate}${overdue ? ' · Overdue' : ''}',
              ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: goal.fraction),
            const SizedBox(height: 6),
            Text(
              '${goal.progress.total} / ${goal.target} ${goal.unit} · '
              'Manual ${goal.progress.manual}, tasks ${goal.progress.tasks}, '
              'habits ${goal.progress.habits}${goal.completed ? ' · Completed' : ''}',
            ),
            for (final milestone in milestones)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: IconButton(
                  tooltip: 'Edit milestone',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: busy || goal.archived
                      ? null
                      : () => _milestone(goal, milestone),
                ),
                value: milestone.completedAt != null,
                onChanged: busy || goal.archived
                    ? null
                    : (value) => _run(
                        () => controller.setGoalMilestoneCompleted(
                          milestone,
                          value == true,
                        ),
                      ),
                title: Text(milestone.title),
                subtitle: Text(
                  'Checkpoint at ${milestone.threshold} ${goal.unit}'
                  '${milestone.deadlineDate == null ? '' : ' · due ${milestone.deadlineDate}'}'
                  '${goal.progress.total >= milestone.threshold ? ' · reached' : ''}',
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  onPressed: goal.archived || busy ? null : () => _manual(goal),
                  child: const Text('Adjust progress'),
                ),
                OutlinedButton(
                  onPressed: goal.archived || busy
                      ? null
                      : () => showDialog<bool>(
                          context: context,
                          builder: (_) => GoalLinksDialog(goal: goal),
                        ),
                  child: const Text('Link work'),
                ),
                OutlinedButton(
                  onPressed: goal.archived || busy
                      ? null
                      : () => _milestone(goal),
                  child: const Text('Add milestone'),
                ),
                TextButton(
                  onPressed: () => _history(goal),
                  child: const Text('Progress history'),
                ),
                TextButton(
                  onPressed: goal.archived || busy
                      ? null
                      : () => _complete(goal),
                  child: Text(goal.completed ? 'Reopen goal' : 'Mark complete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
