import 'package:life_manager/features/shared/anchored_select_field.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/habits.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import '../shared/weekdays.dart';
import '../shared/dialog_action_bar.dart';

class HabitEditorDialog extends ConsumerStatefulWidget {
  const HabitEditorDialog({super.key, this.habit});
  final Habit? habit;

  @override
  ConsumerState<HabitEditorDialog> createState() => _HabitEditorDialogState();
}

class _HabitEditorDialogState extends ConsumerState<HabitEditorDialog> {
  late final TextEditingController title;
  late final TextEditingController notes;
  late final TextEditingController target;
  late final TextEditingController unit;
  late final TextEditingController interval;
  late HabitKind kind;
  late RecurrenceKind scheduleKind;
  late Set<int> weekdays;
  late String startDate;
  String? endDate;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    title = TextEditingController(text: habit?.title ?? '');
    notes = TextEditingController(text: habit?.notes ?? '');
    target = TextEditingController(text: habit?.target?.toString() ?? '');
    unit = TextEditingController(text: habit?.unit ?? '');
    interval = TextEditingController(text: '${habit?.rule.interval ?? 1}');
    kind = habit?.kind ?? HabitKind.binary;
    scheduleKind = habit?.rule.kind ?? RecurrenceKind.daily;
    startDate = habit?.rule.startDate ?? localDate(DateTime.now());
    endDate = habit?.rule.endDate;
    weekdays = {...?habit?.rule.weekdays};
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    target.dispose();
    unit.dispose();
    interval.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? startDate : endDate;
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
        if (scheduleKind == RecurrenceKind.weekdays) {
          weekdays.add(picked.weekday);
        }
      } else {
        endDate = localDate(picked);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final count = int.tryParse(interval.text.trim());
      if (count == null || count < 1) {
        throw const FormatException('Repeat interval must be positive');
      }
      final numericTarget = kind == HabitKind.binary
          ? null
          : double.tryParse(target.text.trim());
      if (kind != HabitKind.binary &&
          (numericTarget == null ||
              !numericTarget.isFinite ||
              numericTarget <= 0)) {
        throw const FormatException('Enter a positive numeric target');
      }
      final draft = HabitDraft(
        title: title.text,
        notes: notes.text,
        kind: kind,
        target: numericTarget,
        unit: kind == HabitKind.binary ? '' : unit.text,
        rule: RecurrenceRule(
          kind: scheduleKind,
          startDate: startDate,
          interval: count,
          weekdays: scheduleKind == RecurrenceKind.weekdays
              ? weekdays
              : const {},
          endDate: endDate,
        ),
      );
      final controller = ref.read(appControllerProvider);
      if (widget.habit == null) {
        await controller.addHabit(draft);
      } else {
        await controller.updateHabit(widget.habit!, draft);
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
      width: math.min(MediaQuery.sizeOf(context).width - 48, 560),
      height: math.min(
        MediaQuery.sizeOf(context).height - 48,
        widget.habit == null ? 550 : 580,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.habit == null ? 'New habit' : 'Edit habit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.habit != null)
              const Text(
                'Changing the schedule preserves earlier logs and rest days.',
              ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                key: const ValueKey('habit-editor-form-list'),
                padding: const EdgeInsets.fromLTRB(0, 8, 14, 12),
                children: [
                  TextField(
                    key: const ValueKey('habit-editor-title'),
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  AnchoredSelectField<HabitKind>(
                    isExpanded: true,
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Measurement'),
                    items: const [
                      DropdownMenuItem(
                        value: HabitKind.binary,
                        child: Text('Yes / No'),
                      ),
                      DropdownMenuItem(
                        value: HabitKind.minimum,
                        child: Text('At least a target'),
                      ),
                      DropdownMenuItem(
                        value: HabitKind.maximum,
                        child: Text('At most a limit'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value != null) setState(() => kind = value);
                          },
                  ),
                  if (kind != HabitKind.binary) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: target,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Target *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit (optional)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  AnchoredSelectField<RecurrenceKind>(
                    isExpanded: true,
                    key: ValueKey(scheduleKind),
                    initialValue: scheduleKind,
                    decoration: const InputDecoration(labelText: 'Schedule'),
                    items: const [
                      DropdownMenuItem(
                        value: RecurrenceKind.daily,
                        child: Text('Daily'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.weekly,
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.weekdays,
                        child: Text('Selected weekdays'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.monthly,
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceKind.yearly,
                        child: Text('Yearly'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              scheduleKind = value;
                              if (value == RecurrenceKind.weekdays &&
                                  weekdays.isEmpty) {
                                weekdays.add(DateTime.parse(startDate).weekday);
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: interval,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Repeat every N days, weeks, months, or years',
                    ),
                  ),
                  if (scheduleKind == RecurrenceKind.weekdays) ...[
                    const SizedBox(height: 12),
                    WeekdayPickerRow(
                      firstWeekday: ref
                          .watch(appControllerProvider)
                          .firstWeekday,
                      selected: weekdays,
                      onSelected: (day, selected) => setState(() {
                        if (selected) {
                          weekdays.add(day);
                        } else {
                          weekdays.remove(day);
                        }
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: busy ? null : () => _pickDate(start: true),
                    child: Text('First scheduled day: $startDate'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => _pickDate(start: false),
                          child: Text('End day: ${endDate ?? 'None'}'),
                        ),
                      ),
                      if (endDate != null)
                        IconButton(
                          tooltip: 'Clear end day',
                          onPressed: busy
                              ? null
                              : () => setState(() => endDate = null),
                          icon: const Icon(Icons.close),
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
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: busy ? null : _save,
                  child: Text(
                    widget.habit == null ? 'Create habit' : 'Save habit',
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
