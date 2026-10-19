import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import 'habit_editor.dart';

class HabitsView extends ConsumerStatefulWidget {
  const HabitsView({super.key});

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

  Future<void> _numericLog(Habit habit, HabitEntry? previous) async {
    var value = previous?.value.toString() ?? '';
    var notes = previous?.notes ?? '';
    final result = await showDialog<(double, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${habit.title} · $day'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: value,
              onChanged: (text) => value = text,
              key: ValueKey('habit-value:${habit.id}:$day'),
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText:
                    'Actual ${habit.unit.isEmpty ? 'value' : habit.unit}',
              ),
            ),
            TextFormField(
              initialValue: notes,
              onChanged: (text) => notes = text,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
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
              final parsed = double.tryParse(value.trim());
              if (parsed == null || !parsed.isFinite || parsed < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a nonnegative number.')),
                );
                return;
              }
              Navigator.pop(context, (parsed, notes));
            },
            child: const Text('Save log'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _run(
      () => ref
          .read(appControllerProvider)
          .recordHabitDay(
            habit,
            day,
            result.$1,
            notes: result.$2,
            previous: previous,
          ),
    );
  }

  Future<void> _clear(HabitEntry entry) async {
    final approved = await showDialog<bool>(
      context: context,
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
                'Habits',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('New habit'),
              ),
              FilterChip(
                label: const Text('Archived'),
                selected: showArchived,
                onSelected: (value) => setState(() => showArchived = value),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous day',
                onPressed: () =>
                    setState(() => day = RecurrenceRule.shiftDate(day, -1)),
                icon: const Icon(Icons.chevron_left),
              ),
              OutlinedButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(day),
              ),
              IconButton(
                tooltip: 'Next day',
                onPressed: day.compareTo(today) >= 0
                    ? null
                    : () => setState(
                        () => day = RecurrenceRule.shiftDate(day, 1),
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
              Text(
                'Rest days do not count as misses.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: habits.isEmpty
              ? Center(
                  child: Text(
                    showArchived
                        ? 'No archived habits.'
                        : 'No habits yet. Create one to track daily progress.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: habits.length,
                  itemBuilder: (context, index) =>
                      _card(context, controller, habits[index], today),
                ),
        ),
      ],
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
      todayDate.subtract(Duration(days: todayDate.weekday - 1)),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    habit.title,
                    style: Theme.of(context).textTheme.titleMedium,
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
            Text(
              '$day · $status${entry == null ? '' : ' · ${entry.value}${habit.unit.isEmpty ? '' : ' ${habit.unit}'}'}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text('${year.streak} day streak')),
                Chip(label: Text(_progress('Week', week))),
                Chip(label: Text(_progress('Month', month))),
                Chip(label: Text(_progress('Year', year))),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                if (habit.kind == HabitKind.binary && scheduled && rest == null)
                  OutlinedButton(
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
          ],
        ),
      ),
    );
  }

  String _progress(String period, HabitStatistics stats) => stats.due == 0
      ? '$period: no due days'
      : '$period ${stats.successful}/${stats.due} · ${(stats.completionRate * 100).round()}%';
}
