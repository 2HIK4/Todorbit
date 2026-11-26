import '../shared/app_spacing.dart';
import '../shared/app_section_heading.dart';
import '../shared/task_date_label.dart';
import '../shared/scroll_edge_fade.dart';
import '../shared/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/goals.dart';
import '../../domain/models.dart';
import '../shared/about_view_button.dart';
import '../shared/numeric_entry_dialog.dart';
import 'goal_dialogs.dart';

class GoalsView extends ConsumerStatefulWidget {
  const GoalsView({super.key, this.showTitle = true});

  final bool showTitle;
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
    animationStyle: AppMotion.style(context),
    builder: (_) => GoalEditorDialog(goal: goal),
  );

  Future<void> _manual(Goal goal) => showDialog<void>(
    context: context,
    animationStyle: AppMotion.style(context),
    builder: (_) => NumericEntryDialog(
      title: 'Adjust ${goal.title}',
      label: 'Adjustment ${goal.unit.isEmpty ? '(units)' : goal.unit}',
      submitLabel: 'Save adjustment',
      signed: true,
      help: 'Enter a positive amount for progress or a negative amount to correct an earlier manual entry. Linked work stays separate.',
      validate: (value) => value == null || !value.isFinite || value == 0
          ? 'Enter a nonzero number.'
          : null,
      save: (value, notes) =>
          ref.read(appControllerProvider).addGoalProgress(goal, value, notes),
    ),
  );

  Future<void> _milestone(Goal goal, [GoalMilestone? previous]) =>
      showDialog<void>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (_) => GoalMilestoneDialog(goal: goal, previous: previous),
      );

  Future<void> _history(Goal goal) async {
    final controller = ref.read(appControllerProvider);
    final history = await controller.goalProgressHistory(goal.id);
    final linked = await controller.goalLinkedEvents(goal);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (context) => AlertDialog(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Progress history'),
            const SizedBox(height: AppSpacing.small),
            Text(goal.title, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        content: SizedBox(
          width: 490,
          height: 380,
          child: FadingListView(
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
                    '${taskDateLabel(context, item.localDate)} · +${item.units} ${goal.unit}',
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
                    '${MaterialLocalizations.of(context).formatShortDate(item.createdAt.toLocal())} · '
                    '${TimeOfDay.fromDateTime(item.createdAt.toLocal()).format(context)}'
                    '${item.notes.isEmpty ? '' : ' · ${item.notes}'}',
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
        animationStyle: AppMotion.style(context),
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
        animationStyle: AppMotion.style(context),
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
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.taskListMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppLayout.pageInsets,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.showTitle)
                    Semantics(
                      header: true,
                      child: Text(
                        'Goals',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
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
                      child: AppEmptyState(
                        title: showArchived
                            ? 'No archived goals'
                            : 'No goals yet',
                        message: showArchived
                            ? null
                            : 'Use New goal to get started.',
                      ),
                    )
                  : FadingListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayout.pageInsetH,
                        0,
                        AppLayout.pageInsetH,
                        AppSpacing.section,
                      ),
                      itemCount: goals.length,
                      itemBuilder: (context, index) =>
                          _card(context, controller, goals[index]),
                    ),
            ),
          ],
        ),
      ),
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
    final compact =
        MediaQuery.sizeOf(context).width < AppLayout.breakpointCompact;
    final canEdit = !goal.archived && !busy;
    void linkWork() => showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (_) => GoalLinksDialog(goal: goal),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.content,
          horizontal: AppSpacing.small,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      goal.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
                'Deadline: ${taskDateLabel(context, goal.deadlineDate!)}${overdue ? ' · Overdue' : ''}',
              ),
            AppSectionHeading(
              goal.completed ? 'Completed' : 'Progress',
              detail: '${goal.progress.total} / ${goal.target} ${goal.unit}',
            ),
            LinearProgressIndicator(
              value: goal.fraction,
              semanticsLabel: 'Goal progress',
            ),
            const SizedBox(height: AppSpacing.gap),
            Text(
              'Manual ${goal.progress.manual} · Tasks ${goal.progress.tasks} · Habits ${goal.progress.habits}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (milestones.isNotEmpty) const AppSectionHeading('Milestones'),
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
            const SizedBox(height: AppSpacing.gap),
            Wrap(
              spacing: AppSpacing.gap,
              runSpacing: AppSpacing.small,
              children: [
                OutlinedButton(
                  onPressed: goal.archived || busy ? null : () => _manual(goal),
                  child: const Text('Adjust progress'),
                ),
                if (compact)
                  PopupMenuButton<String>(
                    tooltip: 'More goal actions',
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        enabled: canEdit,
                        onTap: linkWork,
                        child: const Text('Link work'),
                      ),
                      PopupMenuItem(
                        enabled: canEdit,
                        onTap: () => _milestone(goal),
                        child: const Text('Add milestone'),
                      ),
                      PopupMenuItem(
                        onTap: () => _history(goal),
                        child: const Text('Progress history'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.related),
                      child: Text('More actions'),
                    ),
                  )
                else ...[
                  OutlinedButton(
                    onPressed: canEdit ? linkWork : null,
                    child: const Text('Link work'),
                  ),
                  OutlinedButton(
                    onPressed: canEdit ? () => _milestone(goal) : null,
                    child: const Text('Add milestone'),
                  ),
                  TextButton(
                    onPressed: () => _history(goal),
                    child: const Text('Progress history'),
                  ),
                ],
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
