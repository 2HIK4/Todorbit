import '../shared/app_spacing.dart';
import '../shared/app_section_heading.dart';
import '../shared/task_date_label.dart';
import '../shared/scroll_edge_fade.dart';
import '../shared/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import '../shared/about_view_button.dart';
import '../shared/numeric_entry_dialog.dart';
import 'habit_editor.dart';

class HabitsView extends ConsumerStatefulWidget {
  const HabitsView({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  ConsumerState<HabitsView> createState() => _HabitsViewState();
}

class _HabitsViewState extends ConsumerState<HabitsView> {
  String day = localDate(DateTime.now());
  bool showArchived = false;
  bool busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Habit was not changed: $failure')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit(Habit? habit) => showDialog<bool>(
    context: context,
    animationStyle: AppMotion.style(context),
    builder: (_) => HabitEditorDialog(habit: habit),
  );

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => day = localDate(picked));
  }

  Future<void> _numericLog(Habit habit, HabitEntry? previous) =>
      showDialog<void>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (_) => NumericEntryDialog(
          title: '${habit.title} · $day',
          label: 'Actual ${habit.unit.isEmpty ? 'value' : habit.unit}',
          submitLabel: 'Save log',
          initialValue: previous?.value.toString() ?? '',
          initialNotes: previous?.notes ?? '',
          validate: (value) => value == null || !value.isFinite || value < 0
              ? 'Enter a nonnegative number.'
              : null,
          save: (value, notes) => ref
              .read(appControllerProvider)
              .recordHabitDay(
                habit,
                day,
                value,
                notes: notes,
                previous: previous,
              ),
        ),
      );

  Future<void> _clear(HabitEntry entry) async {
    final scheme = Theme.of(context).colorScheme;
    final approved = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (context) => AlertDialog(
        title: const Text('Clear habit log?'),
        content: Text(
          'Clear the recorded value for ${entry.localDate}? The change remains in history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear log'),
          ),
        ],
      ),
    );
    if (approved == true) {
      await _run(() => ref.read(appControllerProvider).clearHabitDay(entry));
    }
  }

  Future<void> _archive(Habit habit) async {
    if (habit.archivedAt == null) {
      final approved = await showDialog<bool>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (context) => AlertDialog(
          title: Text('Archive ${habit.title}?'),
          content: const Text(
            'Logs and rest days stay saved. You can show archived habits and restore it.',
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
      if (approved != true) return;
    }
    await _run(
      () => ref
          .read(appControllerProvider)
          .setHabitArchived(habit, habit.archivedAt == null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final today = localDate(DateTime.now());
    final habits = controller.habits
        .where(
          (habit) => showArchived
              ? habit.archivedAt != null
              : habit.archivedAt == null,
        )
        .toList();
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.taskListMaxWidth),
        child: ScrollEdgeFade(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
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
                                'Habits',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge,
                              ),
                            ),
                          const AboutViewButton(
                            description: 'Track repeated routines by day. Record progress toward a target, use rest days without counting a miss, and archive habits you no longer follow.',
                          ),
                          FilledButton.icon(
                            onPressed: () => _edit(null),
                            icon: const Icon(Icons.add),
                            label: const Text('New habit'),
                          ),
                          FilterChip(
                            label: const Text('Archived'),
                            selected: showArchived,
                            onSelected: (value) =>
                                setState(() => showArchived = value),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayout.pageInsetH,
                        0,
                        AppLayout.pageInsetH,
                        10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Previous day',
                                onPressed: () => setState(
                                  () => day = RecurrenceRule.shiftDate(day, -1),
                                ),
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Flexible(
                                child: OutlinedButton(
                                  onPressed: _pickDay,
                                  child: Text(
                                    taskDateLabel(context, day),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next day',
                                onPressed: day.compareTo(today) >= 0
                                    ? null
                                    : () => setState(
                                        () => day = RecurrenceRule.shiftDate(
                                          day,
                                          1,
                                        ),
                                      ),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.small),
                          Text(
                            'Rest days do not count as misses.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (habits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: AppEmptyState(
                      title: showArchived
                          ? 'No archived habits'
                          : 'No habits yet',
                      message: showArchived
                          ? null
                          : 'Use New habit to get started.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.pageInsetH,
                    0,
                    AppLayout.pageInsetH,
                    AppSpacing.section,
                  ),
                  sliver: SliverList.builder(
                    itemCount: habits.length,
                    itemBuilder: (context, index) =>
                        _card(context, controller, habits[index], today),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    AppController controller,
    Habit habit,
    String today,
  ) {
    final entry = controller.habitEntries
        .where((item) => item.habitId == habit.id && item.localDate == day)
        .firstOrNull;
    final rest = controller.habitRestDays
        .where((item) => item.habitId == habit.id && item.localDate == day)
        .firstOrNull;
    final scheduled = habit.scheduledOn(day);
    final canLog =
        !busy &&
        habit.archivedAt == null &&
        scheduled &&
        rest == null &&
        day.compareTo(today) <= 0;
    final reference = day.compareTo(today) > 0 ? today : day;
    final todayDate = DateTime.parse(reference);
    final weekStart = localDate(
      todayDate.subtract(
        Duration(days: (todayDate.weekday - controller.firstWeekday + 7) % 7),
      ),
    );
    final monthStart = localDate(DateTime(todayDate.year, todayDate.month));
    final yearStart = localDate(DateTime(todayDate.year));
    HabitStatistics stats(String from) => HabitStatistics.calculate(
      habit: habit,
      entries: controller.habitEntries,
      restDays: controller.habitRestDays,
      fromDate: from,
      throughDate: reference,
      today: today,
    );
    final week = stats(weekStart);
    final month = stats(monthStart);
    final year = stats(yearStart);
    final status = !scheduled
        ? 'Not scheduled on $day'
        : rest != null
        ? 'Rest day'
        : entry == null
        ? day.compareTo(today) > 0
              ? 'Future day'
              : 'Not logged'
        : habit.succeeds(entry.value)
        ? 'Target met'
        : 'Target missed';
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      habit.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit habit',
                  onPressed: habit.archivedAt == null
                      ? () => _edit(habit)
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: habit.archivedAt == null
                      ? 'Archive habit'
                      : 'Restore habit',
                  onPressed: busy ? null : () => _archive(habit),
                  icon: Icon(
                    habit.archivedAt == null
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                  ),
                ),
              ],
            ),
            if (habit.notes.isNotEmpty) Text(habit.notes),
            AppSectionHeading(
              status,
              detail: entry == null || habit.kind == HabitKind.binary
                  ? null
                  : '${entry.value}${habit.unit.isEmpty ? '' : ' ${habit.unit}'}',
            ),
            Wrap(
              spacing: AppSpacing.gap,
              runSpacing: AppSpacing.small,
              children: [
                if (habit.kind == HabitKind.binary && scheduled && rest == null)
                  FilledButton.tonal(
                    onPressed: canLog
                        ? () => _run(
                            () => controller.recordHabitDay(
                              habit,
                              day,
                              1,
                              previous: entry,
                              notes: entry?.notes ?? '',
                            ),
                          )
                        : null,
                    child: const Text('Done'),
                  ),
                if (habit.kind == HabitKind.binary && scheduled && rest == null)
                  OutlinedButton(
                    onPressed: canLog
                        ? () => _run(
                            () => controller.recordHabitDay(
                              habit,
                              day,
                              0,
                              previous: entry,
                              notes: entry?.notes ?? '',
                            ),
                          )
                        : null,
                    child: const Text('Not done'),
                  ),
                if (habit.kind != HabitKind.binary && scheduled && rest == null)
                  OutlinedButton(
                    onPressed: canLog ? () => _numericLog(habit, entry) : null,
                    child: Text(entry == null ? 'Log value' : 'Edit value'),
                  ),
                if (entry != null && habit.archivedAt == null)
                  TextButton(
                    onPressed: busy ? null : () => _clear(entry),
                    child: const Text('Clear log'),
                  ),
                if (scheduled && habit.archivedAt == null)
                  TextButton(
                    onPressed: busy || entry != null
                        ? null
                        : () => _run(
                            () => rest == null
                                ? controller.addHabitRestDay(habit, day)
                                : controller.removeHabitRestDay(rest),
                          ),
                    child: Text(
                      rest == null ? 'Mark rest day' : 'Remove rest day',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.gap),
            Wrap(
              spacing: AppSpacing.related,
              runSpacing: AppSpacing.small,
              children: [
                Text(
                  '${year.streak} day streak',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                for (final label in [
                  _progress('Week', week),
                  _progress('Month', month),
                  _progress('Year', year),
                ])
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _progress(String period, HabitStatistics stats) => stats.due == 0
      ? '$period: no due days'
      : '$period ${stats.successful}/${stats.due} · ${(stats.completionRate * 100).round()}%';
}
