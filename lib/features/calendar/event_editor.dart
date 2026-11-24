import 'calendar_presentation.dart';
import '../shared/app_section_heading.dart';
import '../shared/text_prompt_dialog.dart';
import '../../data/alarm_device_store.dart';
import '../../domain/alarms.dart';
import '../../domain/alarm_plan.dart';
import '../shared/alarm_field.dart';
import '../shared/app_motion.dart';
import '../shared/settings_section.dart';
import '../shared/scroll_edge_fade.dart';

import 'package:life_manager/features/shared/anchored_select_field.dart';

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../domain/models.dart';
import '../../platform/android/android_platform.dart';
import '../shared/icon_picker.dart';
import '../shared/event_color_picker.dart';
import '../shared/weekdays.dart';
import '../shared/unsaved_editor_guard.dart';
import '../shared/dialog_action_bar.dart';
import '../shared/app_spacing.dart';
import '../shared/draft_interval.dart';
import '../shared/date_time_button_row.dart';
import '../widget/native_widget_service.dart';

enum _EventEditScope { occurrence, future, series }

String eventDurationLabel(DateTime start, DateTime end, {bool allDay = false}) {
  if (!end.isAfter(start)) return 'End must follow Start';
  if (allDay) {
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    return days == 1 ? '1 day' : '$days days';
  }
  final minutes = end.difference(start).inMinutes;
  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final rest = minutes % 60;
  final parts = <String>[];
  if (days > 0) parts.add('$days ${days == 1 ? 'day' : 'days'}');
  if (hours > 0) parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
  if (rest > 0) parts.add('$rest ${rest == 1 ? 'minute' : 'minutes'}');
  return parts.isEmpty ? 'Less than 1 minute' : parts.join(' ');
}

class EventEditor extends ConsumerStatefulWidget {
  const EventEditor({
    super.key,
    this.event,
    required this.initialDay,
    required this.onClose,
    this.protectUnsavedEdits = false,
    this.navigationController,
  });
  final FixedEvent? event;
  final DateTime initialDay;
  final VoidCallback onClose;
  final bool protectUnsavedEdits;
  final EditorNavigationController? navigationController;

  @override
  ConsumerState<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<EventEditor> {
  Color _inheritedColor() {
    final controller = ref.read(appControllerProvider);
    final value = controller.categories
        .where((item) => item.id == categoryId)
        .firstOrNull
        ?.eventColor;
    return value == null ? Theme.of(context).colorScheme.primary : Color(value);
  }

  static const builtInDetails = <EventDetailType>[
    EventDetailType(id: 'location', name: 'Location'),
    EventDetailType(id: 'room', name: 'Room'),
    EventDetailType(id: 'meeting-link', name: 'Meeting link / URL'),
    EventDetailType(id: 'contact', name: 'Organizer or Contact'),
  ];
  late final TextEditingController title;
  late final TextEditingController notes;
  List<EventDetail> details = [];
  List<EventDetailType> detailTypes = [];
  late DateTime start;
  late DateTime end;
  bool endEdited = false;
  DateTime? suggestedEnd;
  bool allDay = false;
  EventRepeatKind? repeatKind;
  Set<int> weekdays = {};
  DateTime? repeatUntil;
  String? categoryId;
  String? projectId;
  int? colorValue;
  String? iconName;
  int? reminderMinutes;
  AlarmConfig alarm = const AlarmConfig();
  AlarmConfig initialAlarm = const AlarmConfig();
  AlarmRule? initialAlarmRule;
  _EventEditScope editScope = _EventEditScope.occurrence;
  bool busy = false;
  final exitGuard = GlobalKey<UnsavedEditorGuardState>();
  late String initialDraft;
  String get draftKey => jsonEncode([
    title.text,
    notes.text,
    start.toIso8601String(),
    end.toIso8601String(),
    allDay,
    repeatKind?.name,
    weekdays.toList()..sort(),
    repeatUntil?.toIso8601String(),
    categoryId,
    projectId,
    colorValue,
    iconName,
    reminderMinutes,
    alarm.toJson(),
    editScope.name,
    details.map((d) => d.toJson()).toList(),
  ]);
  int organizationPickerRevision = 0;

  Future<String?> _newOrganizationName(String kind) async {
    final noun = kind == 'category' ? 'Category' : 'Project';
    final value = await showDialog<String>(
      context: context,
      animationStyle: AppMotion.style(context),
      builder: (_) => TextPromptDialog(
        title: 'New $noun',
        label: '$noun name',
        submitLabel: 'Create',
        maxLength: null,
      ),
    );
    return value?.trim();
  }

  Future<void> _createCategory() async {
    final name = await _newOrganizationName('category');
    if (name == null || name.isEmpty || !mounted) {
      if (mounted) setState(() => organizationPickerRevision++);
      return;
    }
    try {
      final controller = ref.read(appControllerProvider);
      await controller.addCategory(name);
      if (mounted) {
        setState(() {
          categoryId = controller.categories
              .where((item) => item.name == name)
              .last
              .id;
          projectId = null;
          organizationPickerRevision++;
        });
      }
    } catch (error) {
      if (mounted) setState(() => organizationPickerRevision++);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _createProject() async {
    final parentId = categoryId;
    if (parentId == null) return;
    final name = await _newOrganizationName('project');
    if (name == null || name.isEmpty || !mounted) {
      if (mounted) setState(() => organizationPickerRevision++);
      return;
    }
    try {
      final controller = ref.read(appControllerProvider);
      await controller.addProject(parentId, name);
      if (mounted) {
        setState(() {
          projectId = controller.projects
              .where((item) => item.categoryId == parentId && item.name == name)
              .last
              .id;
          organizationPickerRevision++;
        });
      }
    } catch (error) {
      if (mounted) setState(() => organizationPickerRevision++);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  void changed() {
    if (widget.protectUnsavedEdits && mounted) setState(() {});
  }

  void finish() {
    exitGuard.currentState?.close(saved: true);
  }

  Future<bool> confirmLeave() async =>
      !busy &&
      (await exitGuard.currentState?.confirmLeave(
            dirty: draftKey != initialDraft,
          ) ??
          !widget.protectUnsavedEdits);

  void _initFromEvent() {
    title.text = widget.event?.title ?? '';
    notes.text = widget.event?.notes ?? '';
    details = List.of(widget.event?.details ?? const []);
    allDay = widget.event?.allDay ?? false;
    repeatKind = widget.event?.repeat?.kind;
    weekdays = {...?widget.event?.repeat?.weekdays};
    repeatUntil = widget.event?.repeat?.untilDate == null
        ? null
        : DateTime.parse(widget.event!.repeat!.untilDate!);
    categoryId = widget.event?.categoryId;
    projectId = widget.event?.projectId;
    colorValue = widget.event?.colorValue;
    iconName = widget.event?.iconName;
    reminderMinutes = widget.event?.reminderMinutes;
    alarm = widget.event == null
        ? const AlarmConfig()
        : eventAlarmRule(
                widget.event!,
                ref.read(appControllerProvider).alarmRules,
              )?.config ??
              const AlarmConfig();
    initialAlarm = alarm;
    if (widget.event != null) {
      initialAlarmRule = eventAlarmRule(
        widget.event!,
        ref.read(appControllerProvider).alarmRules,
      );
    } else {
      initialAlarmRule = null;
    }
    start =
        widget.event?.startsAt.toLocal() ??
        DateTime(
          widget.initialDay.year,
          widget.initialDay.month,
          widget.initialDay.day,
          widget.initialDay.hour == 0 ? 9 : widget.initialDay.hour,
          widget.initialDay.minute,
        );
    end = widget.event?.endsAt.toLocal() ?? start.add(const Duration(hours: 1));
    initialDraft = draftKey;
  }

  @override
  void initState() {
    super.initState();
    title = TextEditingController();
    notes = TextEditingController();
    _initFromEvent();
    _loadDetailTypes();
    title.addListener(changed);
    notes.addListener(changed);
    widget.navigationController?.attach(confirmLeave);
  }

  @override
  void didUpdateWidget(EventEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationController != widget.navigationController) {
      oldWidget.navigationController?.detach(confirmLeave);
      widget.navigationController?.attach(confirmLeave);
    }
    if (oldWidget.event?.id != widget.event?.id ||
        oldWidget.event?.nominalDate != widget.event?.nominalDate) {
      _initFromEvent();
    }
  }

  @override
  void dispose() {
    widget.navigationController?.detach(confirmLeave);
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _loadDetailTypes() async {
    final loaded = await ref
        .read(appControllerProvider)
        .repository
        .eventDetailTypes();
    if (mounted) setState(() => detailTypes = loaded);
  }

  Future<void> _addDetail(String typeId) async {
    if (typeId == 'manage') {
      await showDialog<void>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (context) => AlertDialog(
          title: const Text('Custom detail types'),
          content: SizedBox(
            width: 350,
            child: FadingListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Deleting a type removes it from this list. Details already saved on events stay intact.',
                ),
                const SizedBox(height: 8),
                if (detailTypes.isEmpty) const Text('No custom types yet.'),
                for (final type in detailTypes)
                  ListTile(
                    title: Text(type.name),
                    trailing: IconButton(
                      tooltip: 'Delete ${type.name} from catalog',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref
                            .read(appControllerProvider)
                            .repository
                            .deleteEventDetailType(type.id);
                        await _loadDetailTypes();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }
    EventDetailType? type;
    if (typeId == 'custom') {
      var enteredName = '';
      final name = await showDialog<String>(
        context: context,
        animationStyle: AppMotion.style(context),
        builder: (context) => AlertDialog(
          title: const Text('Add custom detail type'),
          content: TextField(
            onChanged: (value) => enteredName = value,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Type name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, enteredName),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      try {
        type = await ref
            .read(appControllerProvider)
            .repository
            .addEventDetailType(name);
        await _loadDetailTypes();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$error')));
        }
        return;
      }
    } else {
      type = [
        ...builtInDetails,
        ...detailTypes,
      ].where((item) => item.id == typeId).firstOrNull;
    }
    if (type != null && mounted) {
      setState(
        () => details.add(
          EventDetail(typeId: type!.id, label: type.name, value: ''),
        ),
      );
    }
  }

  Widget _detailsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Additional fields',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Add detail',
            icon: const Icon(Icons.add),
            onSelected: _addDetail,
            itemBuilder: (_) => [
              for (final type in [...builtInDetails, ...detailTypes])
                PopupMenuItem(value: type.id, child: Text(type.name)),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'manage',
                child: Text('Manage custom types'),
              ),
              const PopupMenuItem(
                value: 'custom',
                child: Text('Add custom detail type'),
              ),
            ],
          ),
        ],
      ),
      for (var index = 0; index < details.length; index++) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('detail-$index-${details[index].typeId}'),
                initialValue: details[index].value,
                keyboardType: details[index].typeId == 'meeting-link'
                    ? TextInputType.url
                    : TextInputType.text,
                decoration: InputDecoration(labelText: details[index].label),
                validator: details[index].typeId == 'meeting-link'
                    ? (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final uri = Uri.tryParse(value.trim());
                        return uri != null &&
                                (uri.scheme == 'https' ||
                                    uri.scheme == 'http') &&
                                uri.host.isNotEmpty
                            ? null
                            : 'Enter a valid HTTP or HTTPS URL';
                      }
                    : null,
                onChanged: (value) {
                  final current = details[index];
                  details[index] = EventDetail(
                    typeId: current.typeId,
                    label: current.label,
                    value: value,
                  );
                },
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Detail actions',
              icon: const Icon(Icons.more_vert),
              onSelected: (action) async {
                if (action == 'remove') {
                  setState(() => details.removeAt(index));
                } else {
                  final chosen = await showDialog<EventDetailType>(
                    context: context,
                    animationStyle: AppMotion.style(context),
                    builder: (context) => SimpleDialog(
                      title: const Text('Edit type'),
                      children: [
                        for (final type in [...builtInDetails, ...detailTypes])
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, type),
                            child: Text(type.name),
                          ),
                      ],
                    ),
                  );
                  if (chosen != null && mounted) {
                    setState(() {
                      details[index] = EventDetail(
                        typeId: chosen.id,
                        label: chosen.name,
                        value: details[index].value,
                      );
                    });
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit Type')),
                PopupMenuItem(value: 'remove', child: Text('Remove Detail')),
              ],
            ),
          ],
        ),
      ],
    ],
  );

  Future<void> _pick(bool isStart, bool dateOnly) async {
    final current = isStart
        ? start
        : allDay && dateOnly
        ? DateTime(end.year, end.month, end.day - 1)
        : end;
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: calendarUses24HourClock(context)),
          child: child!,
        ),
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
    if (next != null && mounted) {
      setState(() {
        if (isStart) {
          final movedEnd = endAfterMovingStart(
            start: start,
            end: end,
            nextStart: next!,
            allDay: allDay,
          );
          if (!endEdited) end = movedEnd;
          start = next;
          suggestedEnd = end.isAfter(start) ? null : movedEnd;
        } else {
          end = next!;
          endEdited = true;
          suggestedEnd = end.isAfter(start)
              ? null
              : endAfterMovingStart(
                  start: start,
                  end: end,
                  nextStart: start,
                  allDay: allDay,
                );
        }
      });
    }
  }

  Future<bool> _save({bool close = true}) async {
    if (busy) return false;
    for (final detail in details.where(
      (item) => item.typeId == 'meeting-link' && item.value.trim().isNotEmpty,
    )) {
      final uri = Uri.tryParse(detail.value.trim());
      if (uri == null ||
          !const ['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid HTTP or HTTPS meeting link.'),
          ),
        );
        return false;
      }
    }
    if (title.text.trim().isEmpty || !end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a title and an end after the start.'),
        ),
      );
      return false;
    }
    setState(() => busy = true);
    try {
      final draft = EventDraft(
        title: title.text,
        notes: notes.text,
        startsAt: start,
        endsAt: end,
        location:
            details
                .where(
                  (item) => item.typeId == 'location' || item.typeId == 'room',
                )
                .map((item) => item.value)
                .firstOrNull ??
            '',
        details: details.where((item) => item.value.trim().isNotEmpty).toList(),
        allDay: allDay,
        categoryId: categoryId,
        projectId: projectId,
        colorValue: colorValue,
        iconName: iconName,
        reminderMinutes: reminderMinutes,
        alarm: alarm.sameAs(initialAlarm) ? null : alarm,
        alarmReviewRevision:
            initialAlarmRule?.eventId == widget.event?.id &&
                initialAlarmRule?.nominalDate ==
                    (widget.event?.nominalDate ?? '') &&
                initialAlarmRule != null
            ? initialAlarmRule!.updatedAt
            : 'new',
        repeat:
            (widget.event?.nominalDate != null &&
                    editScope == _EventEditScope.occurrence) ||
                repeatKind == null
            ? null
            : EventRepeat(
                kind: repeatKind!,
                weekdays: weekdays,
                untilDate: repeatUntil == null ? null : localDate(repeatUntil!),
              ),
      );
      final controller = ref.read(appControllerProvider);
      if (!alarm.sameAs(initialAlarm) && alarm.enabled) {
        if (alarm.mode == 'custom' &&
            !alarm.at!.isAfter(DateTime.now().toUtc())) {
          throw const FormatException('Choose a future alarm time.');
        }
        if (Platform.isAndroid &&
            await AlarmDeviceStore.active().enabled() &&
            !await AndroidPlatform.requestNotifications()) {
          throw StateError(
            'Allow notifications or remove the alarm before saving.',
          );
        }
        if (Platform.isWindows && await AlarmDeviceStore.active().enabled()) {
          if (!NativeWidgetService().isAvailable) {
            throw StateError('Alarms require the packaged Windows companion.');
          }
          await NativeWidgetService().ensureRemindersRunning();
        }
      }
      if (reminderMinutes != null && Platform.isAndroid) {
        if (!await AndroidPlatform.requestNotifications()) {
          throw StateError(
            'Allow notifications in Android Settings or turn this reminder off.',
          );
        }
      } else if (reminderMinutes != null) {
        final companion = NativeWidgetService();
        if (!Platform.isWindows || !companion.isAvailable) {
          throw StateError(
            'Event reminders require the packaged Windows tray companion',
          );
        }
        await companion.ensureRemindersRunning();
      }
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
      if (mounted) {
        initialDraft = draftKey;
        if (close) finish();
      }
      return mounted;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save event: $error')));
      }
      return false;
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
          animationStyle: AppMotion.style(context),
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
      if (mounted) finish();
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
      if (mounted) finish();
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
          animationStyle: AppMotion.style(context),
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
      if (mounted) finish();
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
              details: event.details,
              allDay: event.allDay,
              categoryId: event.categoryId,
              projectId: event.projectId,
              colorValue: event.colorValue,
              iconName: event.iconName,
              reminderMinutes: event.reminderMinutes,
              repeat: event.repeat,
            ),
          );
      if (mounted) finish();
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
        details = List.of(occurrence.details);
        start = occurrence.startsAt.toLocal();
        end = occurrence.endsAt.toLocal();
        endEdited = false;
        suggestedEnd = null;
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
      details = List.of(original.details);
      start = original.startsAt.toLocal();
      end = original.endsAt.toLocal();
      endEdited = false;
      suggestedEnd = null;
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
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          exitGuard.currentState?.close(),
    },
    child: UnsavedEditorGuard(
      key: exitGuard,
      enabled: widget.protectUnsavedEdits,
      dirty: draftKey != initialDraft,
      busy: busy,
      onClose: widget.onClose,
      onSave: () => _save(close: false),
      child: Padding(
        padding: AppLayout.pageInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.event == null
                          ? 'New calendar event'
                          : 'Edit calendar event',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => exitGuard.currentState?.close(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: AppSpacing.content),
            Expanded(
              child: FadingListView(
                key: const ValueKey('event-editor-form-list'),
                padding: AppSpacing.editorScrollPadding(context),
                children: [
                  if (widget.event?.nominalDate != null) ...[
                    const AppSectionHeading('Edit recurring event'),
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          SegmentedButton<_EventEditScope>(
                            direction:
                                constraints.maxWidth <
                                    480 *
                                        MediaQuery.textScalerOf(context)
                                            .scale(14) /
                                        14
                                ? Axis.vertical
                                : Axis.horizontal,
                            showSelectedIcon: false,
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
                    ),
                    const SizedBox(height: AppSpacing.content),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: title,
                          autofocus: widget.event == null,
                          minLines: 1,
                          maxLines: 3,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.singleLineFormatter,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Choose event icon',
                        icon: Icon(iconForKey(iconName, Icons.event_outlined)),
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
                    ],
                  ),
                  const SizedBox(height: AppSpacing.related),
                  const AppSectionHeading('Date and time'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('All day'),
                    value: allDay,
                    onChanged: (value) => setState(() {
                      allDay = value;
                      endEdited = false;
                      suggestedEnd = null;
                      if (value) {
                        start = DateTime(start.year, start.month, start.day);
                        end = DateTime(start.year, start.month, start.day + 1);
                      }
                    }),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text('Start', style: Theme.of(context).textTheme.titleSmall),
                  _dateTimeRow(start, true),
                  const SizedBox(height: 12),
                  Text('End', style: Theme.of(context).textTheme.titleSmall),
                  _dateTimeRow(end, false),
                  if (suggestedEnd != null)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        end = suggestedEnd!;
                        suggestedEnd = null;
                        endEdited = false;
                      }),
                      icon: const Icon(Icons.update),
                      label: const Text('Move end with start'),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Duration: ${eventDurationLabel(start, end, allDay: allDay)}'
                      '${suggestedEnd == null ? '' : '. Your edited end is unchanged.'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    'Moving Start keeps the duration until you edit End.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  SettingsSection(
                    title: 'Details',
                    divider: true,
                    initiallyExpanded:
                        notes.text.isNotEmpty || details.isNotEmpty,
                    children: [
                      TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      const SizedBox(height: 12),
                      _detailsSection(),
                      const SizedBox(height: 12),
                    ],
                  ),
                  SettingsSection(
                    title: 'Organization and appearance',
                    divider: true,
                    initiallyExpanded: categoryId != null || projectId != null,
                    children: [
                      Builder(
                        builder: (context) {
                          final controller = ref.watch(appControllerProvider);
                          final projectChoices = categoryId == null
                              ? const <Project>[]
                              : controller.projects
                                    .where((p) => p.categoryId == categoryId)
                                    .toList();
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: 'Choose category',
                                child: AnchoredSelectField<String?>(
                                  key: ValueKey(
                                    'event-category:$categoryId:$organizationPickerRevision',
                                  ),
                                  initialValue: categoryId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('None / Inbox'),
                                    ),
                                    ...controller.categories.map(
                                      (category) => DropdownMenuItem<String?>(
                                        value: category.id,
                                        child: Text(category.name),
                                      ),
                                    ),
                                    const DropdownMenuItem<String?>(
                                      value: '__new_category__',
                                      child: Text('+ New Category'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == '__new_category__') {
                                      _createCategory();
                                      return;
                                    }
                                    setState(() {
                                      categoryId = value;
                                      projectId = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnchoredSelectField<String?>(
                                key: ValueKey(
                                  'event-project:$projectId:$categoryId:$organizationPickerRevision',
                                ),
                                initialValue: projectId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Project',
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('None'),
                                  ),
                                  ...projectChoices.map(
                                    (project) => DropdownMenuItem<String?>(
                                      value: project.id,
                                      child: Text(project.name),
                                    ),
                                  ),
                                  if (categoryId != null)
                                    const DropdownMenuItem<String?>(
                                      value: '__new_project__',
                                      child: Text('+ New Project'),
                                    ),
                                ],
                                onChanged: categoryId == null
                                    ? null
                                    : (value) {
                                        if (value == '__new_project__') {
                                          _createProject();
                                        } else {
                                          setState(() => projectId = value);
                                        }
                                      },
                              ),
                              const SizedBox(height: 12),
                              Tooltip(
                                message: 'Choose event color',
                                child: AnchoredSelectField<int?>(
                                  key: ValueKey('event-color:$colorValue'),
                                  initialValue: colorValue,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Color',
                                  ),
                                  items: [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            color: _inheritedColor(),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Inherited default',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    for (final color in eventColors)
                                      DropdownMenuItem<int?>(
                                        value: color.$2,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Color(color.$2),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                color.$1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (colorValue != null &&
                                        !eventColors.any(
                                          (item) => item.$2 == colorValue,
                                        ))
                                      DropdownMenuItem<int?>(
                                        value: colorValue,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Color(colorValue!),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                eventColorLabel(colorValue),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const DropdownMenuItem<int?>(
                                      value: -1,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.colorize_outlined,
                                            size: 16,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Custom Color…',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) async {
                                    if (value == -1) {
                                      final chosen = await chooseEventColor(
                                        context,
                                        colorValue ?? 0xFF5365B5,
                                      );
                                      if (chosen != null && mounted) {
                                        setState(() => colorValue = chosen);
                                      }
                                    } else {
                                      setState(() => colorValue = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Recurrence and reminders',
                    initiallyExpanded:
                        repeatKind != null || reminderMinutes != null,
                    children: [
                      AlarmField(
                        value: alarm,
                        event: true,
                        recurring:
                            repeatKind != null &&
                            widget.event?.nominalDate == null,
                        onChanged: (value) => setState(() {
                          alarm = value;
                          if (value.enabled) reminderMinutes = null;
                        }),
                      ),
                      if (reminderMinutes != null && !alarm.enabled)
                        AnchoredSelectField<int?>(
                          initialValue: reminderMinutes,
                          decoration: InputDecoration(
                            labelText: 'Reminder notifications',
                            helperText: Platform.isAndroid
                                ? 'Android reminders may be delayed by battery restrictions.'
                                : Platform.isWindows &&
                                      NativeWidgetService().isAvailable
                                ? 'Delivered by the Todorbit tray companion while it runs.'
                                : 'Requires the packaged Windows tray companion.',
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('None')),
                            DropdownMenuItem(value: 0, child: Text('At start')),
                            DropdownMenuItem(
                              value: 5,
                              child: Text('5 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: 15,
                              child: Text('15 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: 30,
                              child: Text('30 minutes before'),
                            ),
                            DropdownMenuItem(
                              value: 60,
                              child: Text('1 hour before'),
                            ),
                          ],
                          onChanged:
                              Platform.isAndroid ||
                                  (Platform.isWindows &&
                                      NativeWidgetService().isAvailable)
                              ? (value) =>
                                    setState(() => reminderMinutes = value)
                              : null,
                        ),
                      const SizedBox(height: 12),
                      AnchoredSelectField<EventRepeatKind?>(
                        initialValue: repeatKind,
                        decoration: const InputDecoration(labelText: 'Repeat'),
                        items: const [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Does not repeat'),
                          ),
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
                        WeekdayPickerRow(
                          firstWeekday: ref
                              .watch(appControllerProvider)
                              .firstWeekday,
                          selected: weekdays,
                          onSelected:
                              widget.event?.nominalDate != null &&
                                  editScope == _EventEditScope.occurrence
                              ? null
                              : (day, selected) => setState(() {
                                  if (selected) {
                                    weekdays.add(day);
                                  } else {
                                    weekdays.remove(day);
                                  }
                                }),
                        ),
                      ],
                      if (repeatKind != null) ...[
                        const SizedBox(height: 8),
                        AnchoredSelectField<bool>(
                          key: ValueKey(
                            'recurrence-ends-${repeatUntil != null}',
                          ),
                          initialValue: repeatUntil != null,
                          decoration: const InputDecoration(
                            labelText: 'Recurrence ends',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: false,
                              child: Text('Never'),
                            ),
                            DropdownMenuItem(
                              value: true,
                              child: Text('On date'),
                            ),
                          ],
                          onChanged:
                              widget.event?.nominalDate != null &&
                                  editScope == _EventEditScope.occurrence
                              ? null
                              : (value) => setState(
                                  () => repeatUntil = value == true
                                      ? (repeatUntil ?? start)
                                      : null,
                                ),
                        ),
                        if (repeatUntil != null)
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
                              'Repeat through ${localDate(repeatUntil!)}',
                            ),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.event?.cancelled == true)
                    const Text('This occurrence is cancelled.'),
                ],
              ),
            ),
            const Divider(height: AppSpacing.content),
            DialogActionBar(
              alignment: widget.event == null
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
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
                FilledButton.icon(
                  onPressed: busy ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(busy ? 'Saving…' : 'Save event'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _dateTimeRow(DateTime value, bool isStart) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: DateTimeButtonRow(
      dateKey: ValueKey('event-${isStart ? 'start' : 'end'}-date'),
      onDatePressed: () => _pick(isStart, true),
      fieldLabel: isStart ? 'start' : 'end',
      dateLabel: MaterialLocalizations.of(context).formatShortDate(
        allDay && !isStart ? value.subtract(const Duration(days: 1)) : value,
      ),
      timeKey: ValueKey('event-${isStart ? 'start' : 'end'}-time'),
      onTimePressed: () => _pick(isStart, false),
      timeLabel: allDay ? null : calendarTimeLabel(context, value),
    ),
  );
}
