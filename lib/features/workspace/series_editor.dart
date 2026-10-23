import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../shared/weekdays.dart';
import '../../domain/models.dart';
import '../../domain/recurrence.dart';
import '../../domain/series_edit.dart';

class SeriesEditorDialog extends ConsumerStatefulWidget {
  const SeriesEditorDialog({super.key, required this.selected});
  final LifeTask selected;

  @override
  ConsumerState<SeriesEditorDialog> createState() => _SeriesEditorDialogState();
}

class _SeriesEditorDialogState extends ConsumerState<SeriesEditorDialog> {
  final title = TextEditingController();
  final notes = TextEditingController();
  final interval = TextEditingController(text: '1');
  final count = TextEditingController();
  final deadlineOffset = TextEditingController();
  final plannedMinutes = TextEditingController();
  final remainingMinutes = TextEditingController();
  SeriesEditScope scope = SeriesEditScope.thisAndFuture;
  RecurrenceKind kind = RecurrenceKind.daily;
  Set<int> weekdays = {};
  String? anchorDate;
  String? originalAnchorDate;
  String? endDate;
  String? categoryId;
  String? projectId;
  int priority = 0;
  bool locked = false;
  bool loading = true;
  bool busy = false;
  String? error;
  SeriesEditPreview? preview;
  Map<String, SeriesCollisionChoice> choices = {};

  @override
  void initState() {
    super.initState();
    for (final field in [
      title,
      notes,
      interval,
      count,
      deadlineOffset,
      plannedMinutes,
      remainingMinutes,
    ]) {
      field.addListener(_invalidate);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final definition = await ref
          .read(appControllerProvider)
          .recurrenceDefinition(widget.selected.id);
      if (!mounted) return;
      final template = definition.template;
      setState(() {
        title.text = template.title;
        notes.text = template.notes;
        interval.text = definition.rule.interval.toString();
        count.text = definition.rule.maxOccurrences?.toString() ?? '';
        kind = definition.rule.kind;
        weekdays = {...definition.rule.weekdays};
        originalAnchorDate = definition.rule.startDate;
        anchorDate = widget.selected.nominalDate;
        if (kind == RecurrenceKind.weekdays &&
            !weekdays.contains(DateTime.parse(anchorDate!).weekday)) {
          for (var offset = 1; offset <= 7; offset++) {
            final candidate = RecurrenceRule.shiftDate(anchorDate!, offset);
            if (weekdays.contains(DateTime.parse(candidate).weekday)) {
              anchorDate = candidate;
              break;
            }
          }
        }
        endDate = definition.rule.endDate;
        categoryId = template.categoryId;
        projectId = template.projectId;
        priority = template.priority;
        locked = template.schedulingLocked;
        plannedMinutes.text = template.plannedDurationMinutes?.toString() ?? '';
        remainingMinutes.text = template.remainingWorkMinutes?.toString() ?? '';
        deadlineOffset.text = template.deadlineDate == null
            ? ''
            : RecurrenceRule.daysBetween(
                template.scheduledDate!,
                template.deadlineDate!,
              ).toString();
        loading = false;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$failure';
        });
      }
    }
  }

  void _invalidate() {
    if (!mounted || loading) return;
    setState(() {
      preview = null;
      choices = {};
      error = null;
    });
  }

  @override
  void dispose() {
    for (final field in [
      title,
      notes,
      interval,
      count,
      deadlineOffset,
      plannedMinutes,
      remainingMinutes,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  int _positive(TextEditingController field, String label) {
    final value = int.tryParse(field.text.trim());
    if (value == null || value < 1) {
      throw FormatException('$label must be positive');
    }
    return value;
  }

  int? _optional(
    TextEditingController field,
    String label, {
    bool zero = false,
  }) {
    if (field.text.trim().isEmpty) return null;
    final value = int.tryParse(field.text.trim());
    if (value == null || value < (zero ? 0 : 1)) {
      throw FormatException(
        '$label must be ${zero ? 'zero or positive' : 'positive'}',
      );
    }
    return value;
  }

  RecurrenceRule _rule() => RecurrenceRule(
    kind: kind,
    startDate: anchorDate ?? widget.selected.nominalDate!,
    interval: _positive(interval, 'Repeat interval'),
    weekdays: kind == RecurrenceKind.weekdays ? weekdays : const {},
    endDate: endDate,
    maxOccurrences: _optional(count, 'Occurrence count'),
  );

  TaskDraft _draft(String effective) {
    final offset = deadlineOffset.text.trim().isEmpty
        ? null
        : int.tryParse(deadlineOffset.text.trim());
    if (deadlineOffset.text.trim().isNotEmpty && offset == null) {
      throw const FormatException('Deadline offset must be a whole number');
    }
    return TaskDraft(
      title: title.text,
      notes: notes.text,
      priority: priority,
      categoryId: categoryId,
      projectId: projectId,
      scheduledDate: effective,
      deadlineDate: offset == null
          ? null
          : RecurrenceRule.shiftDate(effective, offset),
      plannedDurationMinutes: _optional(plannedMinutes, 'Planned minutes'),
      remainingWorkMinutes: _optional(
        remainingMinutes,
        'Remaining minutes',
        zero: true,
      ),
      schedulingLocked: locked,
    );
  }

  Future<void> _pickDate({required bool anchor}) async {
    final current = anchor ? anchorDate : endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null ? DateTime.now() : DateTime.parse(current),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (anchor) {
        anchorDate = localDate(picked);
        if (kind == RecurrenceKind.weekdays) weekdays.add(picked.weekday);
      } else {
        endDate = localDate(picked);
      }
    });
    _invalidate();
  }

  Future<void> _generatePreview() async {
    setState(() {
      busy = true;
      error = null;
      preview = null;
      choices = {};
    });
    try {
      final controller = ref.read(appControllerProvider);
      final rule = _rule();
      final preliminary = await controller.previewSeriesEdit(
        selected: widget.selected,
        scope: scope,
        draft: _draft(widget.selected.nominalDate!),
        rule: rule,
      );
      final reviewed = preliminary.effectiveDate == widget.selected.nominalDate
          ? preliminary
          : await controller.previewSeriesEdit(
              selected: widget.selected,
              scope: scope,
              draft: _draft(preliminary.effectiveDate),
              rule: rule,
            );
      if (mounted) setState(() => preview = reviewed);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _apply() async {
    final reviewed = preview;
    if (reviewed == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(appControllerProvider).applySeriesEdit(reviewed, choices);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = '$failure';
          preview = null;
          choices = {};
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final canApply =
        !busy &&
        preview != null &&
        preview!.collisions.every(
          (collision) => choices.containsKey(collision.nominalDate),
        );
    final projectChoices = controller.projects
        .where((item) => item.categoryId == categoryId)
        .toList();
    return Dialog(
      child: SizedBox(
        width: math.min(MediaQuery.sizeOf(context).width - 48, 760),
        height: math.min(MediaQuery.sizeOf(context).height - 48, 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit recurring series',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Completed work, recorded time, individual edits, and linked records '
                'stay with their original occurrences. Review every date collision.',
              ),
              const SizedBox(height: 12),
              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 8, 14, 12),
                    children: [
                      DropdownButtonFormField<SeriesEditScope>(
                        initialValue: scope,
                        decoration: const InputDecoration(
                          labelText: 'Edit scope',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SeriesEditScope.thisAndFuture,
                            child: Text('This and future occurrences'),
                          ),
                          DropdownMenuItem(
                            value: SeriesEditScope.entireSeries,
                            child: Text('Entire series (pending occurrences)'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    scope = value;
                                    anchorDate =
                                        value == SeriesEditScope.thisAndFuture
                                        ? widget.selected.nominalDate
                                        : originalAnchorDate;
                                  });
                                  _invalidate();
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: title,
                        decoration: const InputDecoration(
                          labelText: 'Shared title',
                        ),
                      ),
                      TextField(
                        controller: notes,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Shared notes',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<RecurrenceKind>(
                        key: ValueKey('kind:$kind'),
                        initialValue: kind,
                        decoration: const InputDecoration(
                          labelText: 'Repeat rule',
                        ),
                        items: [
                          for (final value in RecurrenceKind.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(_kindLabel(value)),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    kind = value;
                                    if (kind == RecurrenceKind.weekdays &&
                                        weekdays.isEmpty) {
                                      weekdays = {
                                        DateTime.parse(
                                          anchorDate ??
                                              widget.selected.nominalDate!,
                                        ).weekday,
                                      };
                                    }
                                  });
                                  _invalidate();
                                }
                              },
                      ),
                      TextField(
                        controller: interval,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Repeat interval',
                        ),
                      ),
                      if (kind == RecurrenceKind.weekdays)
                        WeekdayPickerRow(
                          firstWeekday: ref
                              .watch(appControllerProvider)
                              .firstWeekday,
                          selected: weekdays,
                          onSelected: (day, selected) {
                            setState(() {
                              if (selected) {
                                weekdays.add(day);
                              } else {
                                weekdays.remove(day);
                              }
                            });
                            _invalidate();
                          },
                        ),
                      _dateButton(
                        'Rule anchor day',
                        anchorDate,
                        () => _pickDate(anchor: true),
                      ),
                      _dateButton(
                        'Repeat until',
                        endDate,
                        () => _pickDate(anchor: false),
                        clear: () {
                          setState(() => endDate = null);
                          _invalidate();
                        },
                      ),
                      TextField(
                        controller: count,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText:
                              'Stop after this many occurrences (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        key: ValueKey('category:$categoryId'),
                        initialValue: categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Shared category',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          for (final item in controller.categories)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            categoryId = value;
                            projectId = null;
                          });
                          _invalidate();
                        },
                      ),
                      DropdownButtonFormField<String?>(
                        key: ValueKey('project:$categoryId:$projectId'),
                        initialValue: projectId,
                        decoration: const InputDecoration(
                          labelText: 'Shared project',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          for (final item in projectChoices)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                        ],
                        onChanged: categoryId == null
                            ? null
                            : (value) {
                                setState(() => projectId = value);
                                _invalidate();
                              },
                      ),
                      DropdownButtonFormField<int>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'Shared priority',
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('None')),
                          DropdownMenuItem(value: 1, child: Text('Low')),
                          DropdownMenuItem(value: 2, child: Text('Medium')),
                          DropdownMenuItem(value: 3, child: Text('High')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => priority = value);
                            _invalidate();
                          }
                        },
                      ),
                      TextField(
                        controller: deadlineOffset,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText:
                              'Deadline days after each planned day (optional)',
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: plannedMinutes,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Planned minutes',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: remainingMinutes,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Remaining minutes',
                              ),
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Protect schedule'),
                        value: locked,
                        onChanged: (value) {
                          setState(() => locked = value);
                          _invalidate();
                        },
                      ),
                      const SizedBox(height: 12),
                      if (preview != null) ...[
                        Text(
                          'Preview from ${preview!.effectiveDate}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${preview!.impacts.where((i) => i.kind == SeriesImpactKind.preserve).length} preserved, '
                          '${preview!.impacts.where((i) => i.kind == SeriesImpactKind.exclude).length} excluded, '
                          '${preview!.impacts.where((i) => i.kind == SeriesImpactKind.create).length} new; '
                          '${preview!.collisions.length} collisions',
                        ),
                        if (preview!.collisions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => setState(() {
                                  for (final item in preview!.collisions) {
                                    choices[item.nominalDate] =
                                        SeriesCollisionChoice.keepBoth;
                                  }
                                }),
                                child: const Text('Keep both on all'),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  for (final item in preview!.collisions) {
                                    choices[item.nominalDate] =
                                        SeriesCollisionChoice.skipNew;
                                  }
                                }),
                                child: const Text('Skip new on all'),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  for (final item in preview!.collisions.where(
                                    (c) => c.canCombine,
                                  )) {
                                    choices[item.nominalDate] =
                                        SeriesCollisionChoice.combine;
                                  }
                                }),
                                child: const Text('Combine compatible'),
                              ),
                            ],
                          ),
                          for (final collision in preview!.collisions)
                            DropdownButtonFormField<SeriesCollisionChoice>(
                              key: ValueKey(
                                'collision:${collision.nominalDate}:${choices[collision.nominalDate]}',
                              ),
                              initialValue: choices[collision.nominalDate],
                              decoration: InputDecoration(
                                labelText:
                                    '${collision.nominalDate} • ${collision.existingTaskIds.length} existing',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: SeriesCollisionChoice.keepBoth,
                                  child: Text('Keep both'),
                                ),
                                const DropdownMenuItem(
                                  value: SeriesCollisionChoice.skipNew,
                                  child: Text('Skip new occurrence'),
                                ),
                                if (collision.canCombine)
                                  const DropdownMenuItem(
                                    value: SeriesCollisionChoice.combine,
                                    child: Text('Combine into existing'),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(
                                    () =>
                                        choices[collision.nominalDate] = value,
                                  );
                                }
                              },
                            ),
                        ],
                        ExpansionTile(
                          title: const Text('Review affected occurrences'),
                          children: [
                            for (final impact in preview!.impacts)
                              ListTile(
                                dense: true,
                                title: Text(
                                  '${impact.nominalDate} • ${switch (impact.kind) {
                                    SeriesImpactKind.preserve => 'Preserve existing',
                                    SeriesImpactKind.exclude => 'Exclude unmodified',
                                    SeriesImpactKind.create => 'Create new',
                                    SeriesImpactKind.collision => 'Collision: choose outcome',
                                  }}',
                                ),
                                subtitle: Text(impact.reason),
                              ),
                          ],
                        ),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  OutlinedButton(
                    onPressed: busy || loading ? null : _generatePreview,
                    child: const Text('Generate preview'),
                  ),
                  FilledButton(
                    onPressed: canApply ? _apply : null,
                    child: const Text('Apply series edit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateButton(
    String label,
    String? date,
    VoidCallback pick, {
    VoidCallback? clear,
  }) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: pick,
          child: Text('$label: ${date ?? 'None'}'),
        ),
      ),
      if (date != null && clear != null)
        IconButton(
          tooltip: 'Clear $label',
          onPressed: clear,
          icon: const Icon(Icons.close),
        ),
    ],
  );
}

String _kindLabel(RecurrenceKind value) => switch (value) {
  RecurrenceKind.daily => 'Daily',
  RecurrenceKind.weekly => 'Weekly',
  RecurrenceKind.weekdays => 'Selected weekdays',
  RecurrenceKind.monthly => 'Monthly',
  RecurrenceKind.yearly => 'Yearly',
  RecurrenceKind.afterCompletion => 'After completion',
};
