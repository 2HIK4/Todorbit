import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../shared/icon_picker.dart';

enum _EventEditScope { occurrence, future, series }

class EventEditor extends ConsumerStatefulWidget {
  const EventEditor({
    super.key,
    this.event,
    required this.initialDay,
    required this.onClose,
  });
  final FixedEvent? event;
  final DateTime initialDay;
  final VoidCallback onClose;

  @override
  ConsumerState<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<EventEditor> {
  late final TextEditingController title;
  late final TextEditingController notes;
  late final TextEditingController location;
  late DateTime start;
  late DateTime end;
  bool allDay = false;
  EventRepeatKind? repeatKind;
  Set<int> weekdays = {};
  DateTime? repeatUntil;
  String? categoryId;
  int? colorValue;
  String? iconName;
  int? reminderMinutes;
  _EventEditScope editScope = _EventEditScope.occurrence;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.event?.title ?? '');
    notes = TextEditingController(text: widget.event?.notes ?? '');
    location = TextEditingController(text: widget.event?.location ?? '');
    allDay = widget.event?.allDay ?? false;
    repeatKind = widget.event?.repeat?.kind;
    weekdays = {...?widget.event?.repeat?.weekdays};
    repeatUntil = widget.event?.repeat?.untilDate == null
        ? null
        : DateTime.parse(widget.event!.repeat!.untilDate!);
    categoryId = widget.event?.categoryId;
    colorValue = widget.event?.colorValue;
    iconName = widget.event?.iconName;
    reminderMinutes = widget.event?.reminderMinutes;
    start =
        widget.event?.startsAt.toLocal() ??
        DateTime(
          widget.initialDay.year,
          widget.initialDay.month,
          widget.initialDay.day,
          9,
        );
    end = widget.event?.endsAt.toLocal() ?? start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    location.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isStart, bool dateOnly) async {
    final current = isStart ? start : end;
    DateTime? next;
    if (dateOnly) {
      final date = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date != null) {
        next = DateTime(
          date.year,
          date.month,
          date.day + (allDay && !isStart ? 1 : 0),
          current.hour,
          current.minute,
        );
      }
    } else {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time != null) {
        next = DateTime(
          current.year,
          current.month,
          current.day,
          time.hour,
          time.minute,
        );
      }
    }
    if (next != null) {
      setState(() {
        if (isStart) {
          start = next!;
          if (allDay) end = DateTime(start.year, start.month, start.day + 1);
        } else {
          end = next!;
        }
      });
    }
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty || !end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a title and an end after the start.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final draft = EventDraft(
        title: title.text,
        notes: notes.text,
        startsAt: start,
        endsAt: end,
        location: location.text,
        allDay: allDay,
        categoryId: categoryId,
        colorValue: colorValue,
        iconName: iconName,
        reminderMinutes: reminderMinutes,
        repeat: repeatKind == null
            ? null
            : EventRepeat(
                kind: repeatKind!,
                weekdays: weekdays,
                untilDate: repeatUntil == null ? null : localDate(repeatUntil!),
              ),
      );
      final controller = ref.read(appControllerProvider);
      if (widget.event == null) {
        await controller.addEvent(draft);
      } else if (widget.event!.nominalDate != null &&
          editScope == _EventEditScope.occurrence) {
        await controller.updateEventOccurrence(widget.event!, draft);
      } else if (widget.event!.nominalDate != null) {
        final occurrence = widget.event!;
        final original = (await controller.repository.events()).firstWhere(
          (event) => event.id == occurrence.id,
        );
        final first =
            original.activeFromDate ?? localDate(original.startsAt.toLocal());
        final today = localDate(DateTime.now());
        final boundary = editScope == _EventEditScope.future
            ? occurrence.nominalDate!
            : (today.compareTo(first) > 0 ? today : first);
        await controller.splitEventSeries(occurrence, boundary, draft);
      } else {
        await controller.updateEvent(widget.event!, draft);
      }
      if (mounted) widget.onClose();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save event: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final event = widget.event;
    if (event == null) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              event.repeat == null
                  ? 'Delete event?'
                  : 'Delete entire event series?',
            ),
            content: Text(
              event.repeat == null
                  ? 'Move "${event.title}" to Trash? It can be restored.'
                  : 'Move every generation of "${event.title}" to Trash? '
                        'Past and future dates will be hidden.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => busy = true);
    try {
      if (event.repeat == null) {
        await ref.read(appControllerProvider).deleteEvent(event.id);
      } else {
        await ref.read(appControllerProvider).deleteEventFamily(event);
      }
      if (mounted) widget.onClose();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete event: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleCancelled() async {
    final occurrence = widget.event;
    if (occurrence?.nominalDate == null) return;
    setState(() => busy = true);
    try {
      await ref
          .read(appControllerProvider)
          .setEventOccurrenceCancelled(occurrence!, !occurrence.cancelled);
      if (mounted) widget.onClose();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change lecture: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _endSeries() async {
    final event = widget.event;
    if (event?.nominalDate == null) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End this event series?'),
            content: Text(
              'End "${event!.title}" before ${event.nominalDate}? '
              'Earlier lectures will remain in the calendar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep series'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('End series'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => busy = true);
    try {
      await ref.read(appControllerProvider).endEventSeries(event!);
      if (mounted) widget.onClose();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not end series: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _duplicate() async {
    final event = widget.event;
    if (event == null) return;
    setState(() => busy = true);
    try {
      await ref
          .read(appControllerProvider)
          .addEvent(
            EventDraft(
              title: '${event.title} (copy)',
              notes: event.notes,
              startsAt: event.startsAt,
              endsAt: event.endsAt,
              location: event.location,
              allDay: event.allDay,
              categoryId: event.categoryId,
              colorValue: event.colorValue,
              iconName: event.iconName,
              reminderMinutes: event.reminderMinutes,
              repeat: event.repeat,
            ),
          );
      if (mounted) widget.onClose();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not duplicate event: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _chooseScope(_EventEditScope value) async {
    if (value != _EventEditScope.series) {
      final occurrence = widget.event!;
      setState(() {
        editScope = value;
        title.text = occurrence.title;
        notes.text = occurrence.notes;
        location.text = occurrence.location;
        start = occurrence.startsAt.toLocal();
        end = occurrence.endsAt.toLocal();
        allDay = occurrence.allDay;
        repeatKind = occurrence.repeat?.kind;
        weekdays = {...?occurrence.repeat?.weekdays};
        repeatUntil = occurrence.repeat?.untilDate == null
            ? null
            : DateTime.parse(occurrence.repeat!.untilDate!);
        categoryId = occurrence.categoryId;
        colorValue = occurrence.colorValue;
        iconName = occurrence.iconName;
        reminderMinutes = occurrence.reminderMinutes;
      });
      return;
    }
    final original = (await ref.read(appControllerProvider).repository.events())
        .firstWhere((event) => event.id == widget.event!.id);
    if (!mounted) return;
    setState(() {
      editScope = value;
      title.text = original.title;
      notes.text = original.notes;
      location.text = original.location;
      start = original.startsAt.toLocal();
      end = original.endsAt.toLocal();
      allDay = original.allDay;
      repeatKind = original.repeat?.kind;
      weekdays = {...?original.repeat?.weekdays};
      repeatUntil = original.repeat?.untilDate == null
          ? null
          : DateTime.parse(original.repeat!.untilDate!);
      categoryId = original.categoryId;
      colorValue = original.colorValue;
      iconName = original.iconName;
      reminderMinutes = original.reminderMinutes;
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.event == null
                    ? 'New calendar event'
                    : 'Edit calendar event',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            children: [
              if (widget.event?.nominalDate != null) ...[
                SegmentedButton<_EventEditScope>(
                  segments: const [
                    ButtonSegment(
                      value: _EventEditScope.occurrence,
                      label: Text('This date'),
                    ),
                    ButtonSegment(
                      value: _EventEditScope.future,
                      label: Text('This + future'),
                    ),
                    ButtonSegment(
                      value: _EventEditScope.series,
                      label: Text('Remaining series'),
                    ),
                  ],
                  selected: {editScope},
                  onSelectionChanged: busy
                      ? null
                      : (value) => _chooseScope(value.first),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: title,
                autofocus: widget.event == null,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: location,
                decoration: const InputDecoration(
                  labelText: 'Location or room',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final category
                      in ref.watch(appControllerProvider).categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => categoryId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: colorValue,
                decoration: const InputDecoration(labelText: 'Color'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Default')),
                  DropdownMenuItem(value: 0xFF5365B5, child: Text('Indigo')),
                  DropdownMenuItem(value: 0xFF7E57C2, child: Text('Purple')),
                  DropdownMenuItem(value: 0xFF00897B, child: Text('Teal')),
                  DropdownMenuItem(value: 0xFFD17A22, child: Text('Amber')),
                ],
                onChanged: (value) => setState(() => colorValue = value),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(iconForKey(iconName, Icons.event_outlined)),
                label: const Text('Choose event icon'),
                onPressed: () async {
                  final choice = await chooseBuiltInIcon(
                    context,
                    current: iconName,
                  );
                  if (choice.$1 && mounted) {
                    setState(() => iconName = choice.$2);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All day'),
                value: allDay,
                onChanged: (value) => setState(() {
                  allDay = value;
                  if (value) {
                    start = DateTime(start.year, start.month, start.day);
                    end = DateTime(start.year, start.month, start.day + 1);
                  }
                }),
              ),
              const SizedBox(height: 14),
              Text('Start', style: Theme.of(context).textTheme.titleSmall),
              _dateTimeRow(start, true),
              const SizedBox(height: 12),
              Text('End', style: Theme.of(context).textTheme.titleSmall),
              _dateTimeRow(end, false),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: reminderMinutes,
                decoration: const InputDecoration(
                  labelText: 'Reminder notifications',
                  helperText: 'Delivery is unavailable in this build.',
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('None')),
                  DropdownMenuItem(value: 0, child: Text('At start')),
                  DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                  DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                  DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                  DropdownMenuItem(value: 60, child: Text('1 hour before')),
                ],
                onChanged: null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EventRepeatKind?>(
                initialValue: repeatKind,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Does not repeat')),
                  DropdownMenuItem(
                    value: EventRepeatKind.daily,
                    child: Text('Daily'),
                  ),
                  DropdownMenuItem(
                    value: EventRepeatKind.weekly,
                    child: Text('Weekly'),
                  ),
                  DropdownMenuItem(
                    value: EventRepeatKind.weekdays,
                    child: Text('Selected weekdays'),
                  ),
                  DropdownMenuItem(
                    value: EventRepeatKind.monthly,
                    child: Text('Monthly'),
                  ),
                  DropdownMenuItem(
                    value: EventRepeatKind.yearly,
                    child: Text('Yearly'),
                  ),
                ],
                onChanged:
                    widget.event?.nominalDate != null &&
                        editScope == _EventEditScope.occurrence
                    ? null
                    : (value) => setState(() {
                        repeatKind = value;
                        if (value == EventRepeatKind.weekdays &&
                            weekdays.isEmpty) {
                          weekdays = {start.weekday};
                        }
                      }),
              ),
              if (repeatKind == EventRepeatKind.weekdays) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      FilterChip(
                        label: Text(
                          const [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ][day - 1],
                        ),
                        selected: weekdays.contains(day),
                        onSelected:
                            widget.event?.nominalDate != null &&
                                editScope == _EventEditScope.occurrence
                            ? null
                            : (selected) => setState(() {
                                if (selected) {
                                  weekdays.add(day);
                                } else {
                                  weekdays.remove(day);
                                }
                              }),
                      ),
                  ],
                ),
              ],
              if (repeatKind != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed:
                      widget.event?.nominalDate != null &&
                          editScope == _EventEditScope.occurrence
                      ? null
                      : () async {
                          final chosen = await showDatePicker(
                            context: context,
                            initialDate: repeatUntil ?? start,
                            firstDate: start,
                            lastDate: DateTime(2100),
                          );
                          if (chosen != null) {
                            setState(() => repeatUntil = chosen);
                          }
                        },
                  child: Text(
                    repeatUntil == null
                        ? 'Recurrence has no end'
                        : 'Repeat through ${localDate(repeatUntil!)}',
                  ),
                ),
                if (repeatUntil != null)
                  TextButton(
                    onPressed: () => setState(() => repeatUntil = null),
                    child: const Text('Clear recurrence end'),
                  ),
              ],
              const SizedBox(height: 10),
              if (widget.event?.cancelled == true)
                const Text('This occurrence is cancelled.'),
            ],
          ),
        ),
        Row(
          children: [
            if (widget.event != null)
              PopupMenuButton<String>(
                tooltip: 'Event actions',
                enabled: !busy,
                onSelected: (action) {
                  if (action == 'cancel') _toggleCancelled();
                  if (action == 'end') _endSeries();
                  if (action == 'duplicate') _duplicate();
                  if (action == 'delete') _delete();
                },
                itemBuilder: (_) => [
                  if (widget.event?.nominalDate != null)
                    PopupMenuItem(
                      value: 'cancel',
                      child: Text(
                        widget.event!.cancelled
                            ? 'Restore this occurrence'
                            : 'Cancel this occurrence',
                      ),
                    ),
                  if (widget.event?.nominalDate != null)
                    const PopupMenuItem(
                      value: 'end',
                      child: Text('End series from this date'),
                    ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate event'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      widget.event!.repeat == null
                          ? 'Move event to Trash'
                          : 'Move entire series to Trash',
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.more_horiz),
                      SizedBox(width: 4),
                      Text('Actions'),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(busy ? 'Saving…' : 'Save event'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _dateTimeRow(DateTime value, bool isStart) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pick(isStart, true),
            child: Text(
              localDate(
                allDay && !isStart
                    ? value.subtract(const Duration(days: 1))
                    : value,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (!allDay)
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pick(isStart, false),
              child: Text(
                '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
              ),
            ),
          ),
      ],
    ),
  );
}
