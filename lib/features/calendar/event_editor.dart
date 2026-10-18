import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';

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
  late DateTime start;
  late DateTime end;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.event?.title ?? '');
    notes = TextEditingController(text: widget.event?.notes ?? '');
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
          date.day,
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
      );
      final controller = ref.read(appControllerProvider);
      if (widget.event == null) {
        await controller.addEvent(draft);
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
            title: const Text('Delete event?'),
            content: Text('Move "${event.title}" to Trash? It can be restored.'),
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
      await ref.read(appControllerProvider).deleteEvent(event.id);
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
                widget.event == null ? 'New fixed event' : 'Edit fixed event',
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
              const SizedBox(height: 14),
              Text('Start', style: Theme.of(context).textTheme.titleSmall),
              _dateTimeRow(start, true),
              const SizedBox(height: 12),
              Text('End', style: Theme.of(context).textTheme.titleSmall),
              _dateTimeRow(end, false),
              const SizedBox(height: 10),
              const Text(
                'Fixed events are shown on the calendar and will be protected by future scheduling suggestions.',
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (widget.event != null)
              TextButton.icon(
                onPressed: busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
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
            child: Text(localDate(value)),
          ),
        ),
        const SizedBox(width: 8),
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
