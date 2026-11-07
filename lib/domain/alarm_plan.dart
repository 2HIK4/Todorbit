import 'alarms.dart';
import 'models.dart';

AlarmRule? taskAlarmRule(LifeTask task, List<AlarmRule> rules) =>
    rules.where((r) => r.taskId == task.id).firstOrNull ??
    rules
        .where(
          (r) =>
              r.seriesId != null &&
              (r.seriesId == task.recurrenceSeriesId ||
                  r.seriesId == task.recurrenceFamilyId),
        )
        .firstOrNull;

AlarmRule? eventAlarmRule(FixedEvent event, List<AlarmRule> rules) {
  final owners = [
    event.id,
    if (event.seriesFamilyId != event.id) event.seriesFamilyId,
  ];
  if (event.nominalDate != null) {
    for (final owner in owners.whereType<String>()) {
      final match = rules
          .where(
            (r) => r.eventId == owner && r.nominalDate == event.nominalDate,
          )
          .firstOrNull;
      if (match != null) return match;
    }
  }
  for (final owner in owners.whereType<String>()) {
    final general = rules
        .where((r) => r.eventId == owner && r.nominalDate.isEmpty)
        .firstOrNull;
    if (general != null) return general;
  }
  return null;
}

/// Pure bounded projection. No native handles or device receipts become portable.
List<Map<String, Object>> alarmPlan({
  required List<AlarmRule> rules,
  required List<LifeTask> tasks,
  required List<FixedEvent> events,
  required List<WorkSession> sessions,
  required DateTime now,
}) {
  final result = <Map<String, Object>>[];
  void add(
    AlarmRule rule,
    String kind,
    String id,
    String nominal,
    String title,
    DateTime? at,
    DateTime? start,
  ) {
    if (at == null ||
        at.isBefore(now.subtract(const Duration(hours: 24))) ||
        at.isAfter(now.add(const Duration(days: 93)))) {
      return;
    }
    final offset = start?.difference(at).inMinutes;
    final body = offset != null && offset > 0
        ? '$title starts in $offset minutes.'
        : '$title: alarm';
    result.add({
      'key': 'alarm:${rule.id}:$kind:$id:$nominal:${at.millisecondsSinceEpoch}',
      'at': at.millisecondsSinceEpoch,
      'occurrenceAt': at.millisecondsSinceEpoch,
      'rule': rule.id,
      'title': title,
      'body': body,
      'link': Uri(
        scheme: 'todorbit',
        host: kind,
        queryParameters: {'id': id, if (nominal.isNotEmpty) 'nominal': nominal},
      ).toString(),
      if (start != null) 'startsAt': start.millisecondsSinceEpoch,
      'alarm': true,
      'sound': rule.config.sound,
      'vibrate': rule.config.vibrate,
      'durationSeconds': rule.config.durationSeconds,
    });
  }

  for (final task in tasks.where((t) => t.isOpen)) {
    final rule = taskAlarmRule(task, rules);
    if (rule == null || !rule.config.enabled) continue;
    final upcoming =
        sessions
            .where(
              (s) =>
                  s.taskId == task.id &&
                  s.outcome == SessionOutcome.upcoming &&
                  s.endsAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final start = rule.config.mode == 'planned'
        ? rule.config
              .copyWith(minutesBefore: 0)
              .trigger(plannedDay: task.scheduledDate)
        : upcoming.firstOrNull?.startsAt;
    add(
      rule,
      'task',
      task.id,
      task.nominalDate ?? '',
      task.title,
      rule.config.trigger(plannedDay: task.scheduledDate, start: start),
      start,
    );
  }
  for (final event in events.where((e) => !e.cancelled)) {
    final rule = eventAlarmRule(event, rules);
    if (rule == null || !rule.config.enabled) continue;
    add(
      rule,
      'event',
      event.id,
      event.nominalDate ?? '',
      event.title,
      rule.config.trigger(start: event.startsAt),
      event.startsAt,
    );
  }
  result.sort((a, b) => (a['at'] as int).compareTo(b['at'] as int));
  return result;
}
