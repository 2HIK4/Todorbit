part of 'life_repository.dart';

String? _occurrenceCategory(FixedEvent template, Map<String, dynamic>? value) =>
    value != null && value.containsKey('categoryId')
    ? value['categoryId'] as String?
    : template.categoryId;

String? _occurrenceProject(FixedEvent template, Map<String, dynamic>? value) {
  if (value != null && value.containsKey('projectId')) {
    return value['projectId'] as String?;
  }
  // Older payloads have no project field. Inherit only when their effective
  // category still matches; a project cannot cross a category boundary.
  return _occurrenceCategory(template, value) == template.categoryId
      ? template.projectId
      : null;
}

FixedEvent _eventFromRow(QueryRow row) {
  final kind = row.read<String?>('recurrence_kind');
  final weekdays = row.read<String?>('recurrence_weekdays');
  final savedDetails = (jsonDecode(
    row.read<String>('details_json'),
  ) as List<dynamic>).map(EventDetail.fromJson).toList();
  final location = row.read<String>('location');
  return FixedEvent(
    id: row.read<String>('id'),
    title: row.read<String>('title'),
    notes: row.read<String>('notes'),
    startsAt: DateTime.parse(row.read<String>('starts_at')),
    endsAt: DateTime.parse(row.read<String>('ends_at')),
    createdAt: DateTime.parse(row.read<String>('created_at')),
    updatedAt: DateTime.parse(row.read<String>('updated_at')),
    location: location,
    details: savedDetails.isEmpty && location.trim().isNotEmpty
        ? [EventDetail(typeId: 'location', label: 'Location', value: location)]
        : savedDetails,
    allDay: row.read<int>('all_day') == 1,
    categoryId: row.read<String?>('category_id'),
    projectId: row.read<String?>('project_id'),
    colorValue: row.read<int?>('color_value'),
    iconName: row.read<String?>('icon_name'),
    reminderMinutes: row.read<int?>('reminder_minutes'),
    repeat: kind == null
        ? null
        : EventRepeat(
            kind: EventRepeatKind.values.byName(kind),
            interval: row.read<int>('recurrence_interval'),
            weekdays: weekdays == null
                ? const {}
                : (jsonDecode(weekdays) as List<dynamic>)
                      .map((value) => value as int)
                      .toSet(),
            untilDate: row.read<String?>('recurrence_until'),
          ),
    activeFromDate: row.read<String?>('active_from_date'),
    activeThroughDate: row.read<String?>('active_through_date'),
    seriesFamilyId: row.read<String?>('series_family_id'),
  );
}

List<Variable> _eventExtraVariables(EventDraft draft) => [
  Variable.withString(draft.location.trim()),
  Variable.withInt(draft.allDay ? 1 : 0),
  Variable<String>(draft.categoryId),
  Variable<String>(draft.projectId),
  Variable<int>(draft.colorValue),
  Variable<String>(draft.iconName),
  Variable<int>(draft.reminderMinutes),
  Variable<String>(draft.repeat?.kind.name),
  Variable.withInt(draft.repeat?.interval ?? 1),
  Variable<String>(
    draft.repeat == null
        ? null
        : jsonEncode((draft.repeat!.weekdays.toList()..sort())),
  ),
  Variable<String>(draft.repeat?.untilDate),
];

class _MigratedException {
  const _MigratedException({
    required this.oldNominalDate,
    required this.newNominalDate,
    required this.cancelled,
    required this.payloadJson,
    required this.createdAt,
  });

  final String oldNominalDate;
  final String newNominalDate;
  final bool cancelled;
  final String? payloadJson;
  final String createdAt;
}

class _MigratedAlarm {
  const _MigratedAlarm({
    required this.oldId,
    required this.newId,
    required this.oldNominalDate,
    required this.newNominalDate,
    required this.configJson,
    required this.createdAt,
    required this.deletedAt,
    required this.archivedAt,
  });

  final String oldId;
  final String newId;
  final String oldNominalDate;
  final String newNominalDate;
  final String configJson;
  final String createdAt;
  final String? deletedAt;
  final String? archivedAt;
}

// Only the final recurrence interval is needed to compare finite slot counts.
// A full expansion could allocate millions of daily occurrences in a UI check.
int _calendarFinalOrdinal(RecurrenceRule rule) {
  final end = rule.endDate!;
  final span = RecurrenceRule.daysBetween(rule.startDate, end);
  final lookback = span < 366 * rule.interval ? span : 366 * rule.interval;
  return rule
      .between(RecurrenceRule.shiftDate(end, -lookback), end)
      .last
      .ordinal;
}

extension EventRepository on LifeRepository {
  Future<String?> calendarSeriesMoveProblem(
    FixedEvent master, [
    EventDraft? draft,
  ]) async {
    final sibling = await db
        .customSelect(
          'SELECT 1 FROM fixed_events WHERE COALESCE(series_family_id,id)=? AND id<>? LIMIT 1',
          variables: [
            Variable.withString(master.seriesFamilyId ?? master.id),
            Variable.withString(master.id),
          ],
        )
        .getSingleOrNull();
    if (master.activeThroughDate != null || sibling != null) {
      return 'This series has separate historical generations. Review its future schedule in the editor.';
    }

    final overrides = await db
        .customSelect(
          'SELECT nominal_date, cancelled, payload_json, created_at FROM event_occurrence_changes WHERE event_id=?',
          variables: [Variable.withString(master.id)],
        )
        .get();
    final alarms = await db
        .customSelect(
          "SELECT id, nominal_date, config_json, created_at, deleted_at, archived_at FROM alarm_rules WHERE event_id=? AND nominal_date<>''",
          variables: [Variable.withString(master.id)],
        )
        .get();

    if (draft == null) {
      if (overrides.isEmpty && alarms.isEmpty) return null;
      return 'This series contains edited, cancelled or alarm-specific occurrences. '
          'Move this occurrence only, or review the series in the editor; moving '
          'the whole series could detach those exceptions.';
    }

    final oldRepeat = master.repeat;
    final newRepeat = draft.repeat;
    if (oldRepeat == null || newRepeat == null) {
      return 'The series recurrence rule is missing.';
    }
    if (oldRepeat.kind != newRepeat.kind ||
        oldRepeat.interval != newRepeat.interval) {
      return 'This recurrence change cannot safely preserve modified occurrences. Move this occurrence only, or customize the series in the editor.';
    }
    if (oldRepeat.kind == EventRepeatKind.weekdays &&
        oldRepeat.weekdays.length != newRepeat.weekdays.length) {
      return 'Changing repeat weekdays cannot safely preserve modified occurrences. Customize the series in the editor.';
    }

    final oldRule = RecurrenceRule(
      kind: RecurrenceKind.values.byName(oldRepeat.kind.name),
      startDate: localDate(master.startsAt.toLocal()),
      interval: oldRepeat.interval,
      weekdays: oldRepeat.weekdays,
      endDate: oldRepeat.untilDate,
    );
    final newRule = RecurrenceRule(
      kind: RecurrenceKind.values.byName(newRepeat.kind.name),
      startDate: localDate(draft.startsAt.toLocal()),
      interval: newRepeat.interval,
      weekdays: newRepeat.weekdays,
      endDate: newRepeat.untilDate,
    );

    if ((oldRule.endDate == null) != (newRule.endDate == null) ||
        (oldRule.endDate != null &&
            _calendarFinalOrdinal(oldRule) != _calendarFinalOrdinal(newRule))) {
      return 'This move would add or remove occurrences at the recurrence end date. Move this occurrence only, or customize the end date in the editor.';
    }

    final mappedDates = <String, String>{};
    for (final row in overrides) {
      final oldNominal = row.read<String>('nominal_date');
      final slot = oldRule.between(oldNominal, oldNominal).firstOrNull;
      if (slot == null) {
        return 'This series contains an exception on $oldNominal that does not match the recurrence pattern. Review the series in the editor.';
      }
      final newNominal = newRule.slotDateAtOrdinal(slot.ordinal);
      if (newRule.endDate != null &&
          newNominal.compareTo(newRule.endDate!) > 0) {
        return 'Moving this series would drop a modified occurrence on $oldNominal because the new end date is earlier.';
      }
      if (mappedDates.containsValue(newNominal)) {
        return 'Moving this series causes an occurrence collision on $newNominal. Review the series in the editor.';
      }
      mappedDates[oldNominal] = newNominal;
    }

    for (final row in alarms) {
      final oldNominal = row.read<String>('nominal_date');
      final slot = oldRule.between(oldNominal, oldNominal).firstOrNull;
      if (slot == null) {
        return 'This series contains an occurrence alarm on $oldNominal that does not match the recurrence pattern. Review the series in the editor.';
      }
      final newNominal = newRule.slotDateAtOrdinal(slot.ordinal);
      if (newRule.endDate != null &&
          newNominal.compareTo(newRule.endDate!) > 0) {
        return 'Moving this series would drop an alarm on $oldNominal because the new end date is earlier.';
      }
    }

    return null;
  }

  Future<void> moveCalendarSeries(
    FixedEvent master,
    EventDraft draft,
  ) => db.transaction(() async {
    final problem = await calendarSeriesMoveProblem(master, draft);
    if (problem != null) throw StateError(problem);

    final oldRepeat = master.repeat;
    final newRepeat = draft.repeat;

    final overrides = await db
        .customSelect(
          'SELECT nominal_date, cancelled, payload_json, created_at FROM event_occurrence_changes WHERE event_id=?',
          variables: [Variable.withString(master.id)],
        )
        .get();
    final alarms = await db
        .customSelect(
          "SELECT id, nominal_date, config_json, created_at, deleted_at, archived_at FROM alarm_rules WHERE event_id=? AND nominal_date<>''",
          variables: [Variable.withString(master.id)],
        )
        .get();

    final hasExceptions = overrides.isNotEmpty || alarms.isNotEmpty;
    final List<_MigratedException> migratedExceptions = [];
    final List<_MigratedAlarm> migratedAlarms = [];

    if (hasExceptions && oldRepeat != null && newRepeat != null) {
      final oldRule = RecurrenceRule(
        kind: RecurrenceKind.values.byName(oldRepeat.kind.name),
        startDate: localDate(master.startsAt.toLocal()),
        interval: oldRepeat.interval,
        weekdays: oldRepeat.weekdays,
        endDate: oldRepeat.untilDate,
      );
      final newRule = RecurrenceRule(
        kind: RecurrenceKind.values.byName(newRepeat.kind.name),
        startDate: localDate(draft.startsAt.toLocal()),
        interval: newRepeat.interval,
        weekdays: newRepeat.weekdays,
        endDate: newRepeat.untilDate,
      );

      final oldBaseStart = master.startsAt.toLocal();
      final newBaseStart = draft.startsAt.toLocal();

      for (final row in overrides) {
        final oldNominal = row.read<String>('nominal_date');
        final cancelled = row.read<int>('cancelled') == 1;
        final payloadRaw = row.read<String?>('payload_json');
        final createdAt = row.read<String>('created_at');

        final slot = oldRule.between(oldNominal, oldNominal).first;
        final newNominal = newRule.slotDateAtOrdinal(slot.ordinal);

        String? newPayloadJson;
        if (payloadRaw != null) {
          final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
          final oldNominalDay = DateTime.parse('$oldNominal 00:00:00');
          final oldOccurrenceDefaultStart = DateTime(
            oldNominalDay.year,
            oldNominalDay.month,
            oldNominalDay.day,
            oldBaseStart.hour,
            oldBaseStart.minute,
            oldBaseStart.second,
          );

          final newNominalDay = DateTime.parse('$newNominal 00:00:00');
          final newOccurrenceDefaultStart = DateTime(
            newNominalDay.year,
            newNominalDay.month,
            newNominalDay.day,
            newBaseStart.hour,
            newBaseStart.minute,
            newBaseStart.second,
          );

          if (payload.containsKey('startsAt') &&
              payload.containsKey('endsAt')) {
            final overrideStart = DateTime.parse(payload['startsAt'] as String)
                .toLocal();
            final overrideEnd = DateTime.parse(payload['endsAt'] as String)
                .toLocal();
            final offset = overrideStart.difference(oldOccurrenceDefaultStart);
            final duration = overrideEnd.difference(overrideStart);

            final newOverrideStart = newOccurrenceDefaultStart.add(offset);
            final newOverrideEnd = newOverrideStart.add(duration);

            payload['startsAt'] = newOverrideStart.toUtc().toIso8601String();
            payload['endsAt'] = newOverrideEnd.toUtc().toIso8601String();
          }
          newPayloadJson = jsonEncode(payload);
        }

        migratedExceptions.add(
          _MigratedException(
            oldNominalDate: oldNominal,
            newNominalDate: newNominal,
            cancelled: cancelled,
            payloadJson: newPayloadJson,
            createdAt: createdAt,
          ),
        );
      }

      for (final row in alarms) {
        final oldId = row.read<String>('id');
        final oldNominal = row.read<String>('nominal_date');
        final configRaw = row.read<String>('config_json');
        final createdAt = row.read<String>('created_at');

        final slot = oldRule.between(oldNominal, oldNominal).first;
        final newNominal = newRule.slotDateAtOrdinal(slot.ordinal);

        final newId = const Uuid().v5(
          Namespace.url.value,
          'todorbit:alarm:null:${master.id}:null:$newNominal',
        );

        final configMap = (jsonDecode(configRaw) as Map)
            .cast<String, dynamic>();
        final config = AlarmConfig.fromJson(configMap);
        AlarmConfig updatedConfig = config;

        if (config.mode == 'custom' && config.at != null) {
          final oldNominalDay = DateTime.parse('$oldNominal 00:00:00');
          final oldOccurrenceDefaultStart = DateTime(
            oldNominalDay.year,
            oldNominalDay.month,
            oldNominalDay.day,
            oldBaseStart.hour,
            oldBaseStart.minute,
            oldBaseStart.second,
          );
          final newNominalDay = DateTime.parse('$newNominal 00:00:00');
          final newOccurrenceDefaultStart = DateTime(
            newNominalDay.year,
            newNominalDay.month,
            newNominalDay.day,
            newBaseStart.hour,
            newBaseStart.minute,
            newBaseStart.second,
          );
          final alarmOffset = config.at!.difference(oldOccurrenceDefaultStart);
          final newAt = newOccurrenceDefaultStart.add(alarmOffset);
          updatedConfig = AlarmConfig(
            mode: config.mode,
            at: newAt,
            localMinute: config.localMinute,
            minutesBefore: config.minutesBefore,
            sound: config.sound,
            vibrate: config.vibrate,
            durationSeconds: config.durationSeconds,
          );
        }

        migratedAlarms.add(
          _MigratedAlarm(
            oldId: oldId,
            newId: newId,
            oldNominalDate: oldNominal,
            newNominalDate: newNominal,
            configJson: jsonEncode(updatedConfig.toJson()),
            createdAt: createdAt,
            deletedAt: row.read<String?>('deleted_at'),
            archivedAt: row.read<String?>('archived_at'),
          ),
        );
      }
    }

    // Apply master update atomically with CAS
    await updateEvent(master, draft, moveSeriesAnchor: true);

    final now = DateTime.now().toUtc().toIso8601String();

    if (migratedExceptions.isNotEmpty) {
      await db.customStatement(
        'DELETE FROM event_occurrence_changes WHERE event_id=?',
        [master.id],
      );
      for (final exc in migratedExceptions) {
        await db.customStatement(
          '''INSERT INTO event_occurrence_changes
              (event_id, nominal_date, cancelled, payload_json, created_at, updated_at)
              VALUES(?,?,?,?,?,?)''',
          [
            master.id,
            exc.newNominalDate,
            exc.cancelled ? 1 : 0,
            exc.payloadJson,
            exc.createdAt,
            now,
          ],
        );
      }
    }

    if (migratedAlarms.isNotEmpty) {
      await db.customStatement(
        "DELETE FROM alarm_rules WHERE event_id=? AND nominal_date<>''",
        [master.id],
      );
      for (final alarm in migratedAlarms) {
        await db.customStatement(
          '''INSERT INTO alarm_rules
              (id, task_id, event_id, series_id, nominal_date, config_json, created_at, updated_at, deleted_at, archived_at)
              VALUES(?,NULL,?,NULL,?,?,?,?,?,?)''',
          [
            alarm.newId,
            master.id,
            alarm.newNominalDate,
            alarm.configJson,
            alarm.createdAt,
            now,
            alarm.deletedAt,
            alarm.archivedAt,
          ],
        );
      }
    }
  });

  Future<bool> hasEventReminders() async {
    final row = await db.customSelect(
      '''SELECT 1 FROM fixed_events
      WHERE deleted_at IS NULL AND reminder_minutes IS NOT NULL LIMIT 1''',
    ).getSingleOrNull();
    if (row != null) return true;
    final changed = await db.customSelect(r'''SELECT 1
      FROM event_occurrence_changes c JOIN fixed_events e ON e.id=c.event_id
      WHERE e.deleted_at IS NULL AND c.cancelled=0 AND
        json_extract(c.payload_json,'$.reminderMinutes') IS NOT NULL
      LIMIT 1''').getSingleOrNull();
    return changed != null;
  }

  Future<void> endEventSeries(FixedEvent occurrence) async {
    final boundary = occurrence.nominalDate;
    if (boundary == null) throw ArgumentError('Choose a recurring date');
    final family = occurrence.seriesFamilyId ?? occurrence.id;
    await db.transaction(() async {
      final rows = await db
          .customSelect(
            '''SELECT id,starts_at,active_from_date,
      active_through_date,updated_at FROM fixed_events WHERE
      COALESCE(series_family_id,id)=? AND deleted_at IS NULL''',
            variables: [Variable.withString(family)],
          )
          .get();
      if (!rows.any(
        (row) =>
            row.read<String>('id') == occurrence.id &&
            row.read<String>('updated_at') ==
                occurrence.updatedAt.toUtc().toIso8601String(),
      )) {
        throw StateError('Event series changed; reload it');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      for (final row in rows) {
        final first =
            row.read<String?>('active_from_date') ??
            localDate(DateTime.parse(row.read<String>('starts_at')).toLocal());
        final through = row.read<String?>('active_through_date');
        final id = row.read<String>('id');
        if (first.compareTo(boundary) >= 0) {
          await db.customUpdate(
            '''UPDATE fixed_events SET deleted_at=?,
            updated_at=? WHERE id=? AND deleted_at IS NULL''',
            variables: [
              Variable.withString(now),
              Variable.withString(now),
              Variable.withString(id),
            ],
          );
        } else if (through == null || through.compareTo(boundary) >= 0) {
          await db.customUpdate(
            '''UPDATE fixed_events SET active_through_date=?,
            updated_at=? WHERE id=? AND deleted_at IS NULL''',
            variables: [
              Variable.withString(RecurrenceRule.shiftDate(boundary, -1)),
              Variable.withString(now),
              Variable.withString(id),
            ],
          );
        }
      }
    });
  }

  Future<void> deleteEventFamily(FixedEvent occurrence) async {
    final family = occurrence.seriesFamilyId ?? occurrence.id;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction(() async {
      await db.customUpdate(
        '''UPDATE fixed_events SET deleted_at=?,updated_at=?
        WHERE COALESCE(series_family_id,id)=? AND deleted_at IS NULL''',
        variables: [
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(family),
        ],
      );
    });
  }

  /// Begins a new rule generation without changing dates before [boundary].
  /// Existing occurrence overrides move with the future generation.
  Future<FixedEvent> splitEventSeries(
    FixedEvent occurrence,
    String boundary,
    EventDraft draft,
  ) async {
    if (occurrence.repeat == null || occurrence.nominalDate == null) {
      throw ArgumentError('Choose a recurring event');
    }
    final template = (await events()).firstWhere(
      (event) => event.id == occurrence.id,
    );
    final originalStart = localDate(template.startsAt.toLocal());
    if (boundary.compareTo(originalStart) < 0) {
      throw ArgumentError('Boundary is before the series starts');
    }
    if (template.activeThroughDate != null &&
        boundary.compareTo(template.activeThroughDate!) > 0) {
      throw StateError('This series generation already ended');
    }
    var anchor = DateTime.parse('$boundary 00:00:00');
    final repeat = draft.repeat;
    if (repeat == null) {
      throw ArgumentError('A future series needs a recurrence rule');
    }
    if (repeat.kind == EventRepeatKind.weekdays && repeat.weekdays.isEmpty) {
      throw ArgumentError('Select at least one weekday');
    }
    if (repeat.kind == EventRepeatKind.weekdays) {
      while (!repeat.weekdays.contains(anchor.weekday)) {
        anchor = anchor.add(const Duration(days: 1));
      }
    } else if (repeat.kind == EventRepeatKind.weekly) {
      while (anchor.weekday != draft.startsAt.toLocal().weekday) {
        anchor = anchor.add(const Duration(days: 1));
      }
    }
    final sourceStart = draft.startsAt.toLocal();
    final adjustedStart = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
      sourceStart.hour,
      sourceStart.minute,
      sourceStart.second,
    );
    final adjustedDraft = EventDraft(
      title: draft.title,
      notes: draft.notes,
      startsAt: adjustedStart,
      endsAt: adjustedStart.add(draft.endsAt.difference(draft.startsAt)),
      location: draft.location,
      details: draft.details,
      allDay: draft.allDay,
      categoryId: draft.categoryId,
      projectId: draft.projectId,
      colorValue: draft.colorValue,
      iconName: draft.iconName,
      reminderMinutes: draft.reminderMinutes,
      repeat: draft.repeat,
      alarm: draft.alarm,
      alarmReviewRevision: 'new',
    );
    _validateEvent(adjustedDraft);
    late FixedEvent created;
    await db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final changed = await db.customUpdate(
        '''UPDATE fixed_events SET
        active_through_date=?,series_family_id=COALESCE(series_family_id,id),
        updated_at=? WHERE id=? AND updated_at=? AND deleted_at IS NULL''',
        variables: [
          Variable.withString(RecurrenceRule.shiftDate(boundary, -1)),
          Variable.withString(now),
          Variable.withString(template.id),
          Variable.withString(template.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (changed != 1) throw StateError('Event changed; reload it');
      created = await addEvent(adjustedDraft);
      await db.customUpdate(
        '''UPDATE fixed_events SET
        series_family_id=?,active_from_date=?,active_through_date=? WHERE id=?''',
        variables: [
          Variable.withString(template.seriesFamilyId ?? template.id),
          Variable.withString(boundary),
          Variable<String>(template.activeThroughDate),
          Variable.withString(created.id),
        ],
      );
      await db.customUpdate(
        '''UPDATE event_occurrence_changes SET event_id=?
        WHERE event_id=? AND nominal_date>=?''',
        variables: [
          Variable.withString(created.id),
          Variable.withString(template.id),
          Variable.withString(boundary),
        ],
      );
    });
    return (await events()).firstWhere((event) => event.id == created.id);
  }

  /// Projects a bounded local-day window. Only exceptions occupy SQLite rows;
  /// recurring dates themselves are never materialized into the database.
  Future<List<FixedEvent>> eventOccurrences(
    String fromDate,
    String throughDate, {
    bool showCancelled = true,
  }) async {
    if (fromDate.compareTo(throughDate) > 0) return [];
    final templates = await events();
    final changes = await db
        .customSelect('SELECT * FROM event_occurrence_changes')
        .get();
    final exceptions = <String, QueryRow>{
      for (final row in changes)
        '${row.read<String>('event_id')}/${row.read<String>('nominal_date')}':
            row,
    };
    final fromStart = DateTime.parse('$fromDate 00:00:00');
    final throughDay = DateTime.parse('$throughDate 00:00:00');
    final throughEnd = DateTime(
      throughDay.year,
      throughDay.month,
      throughDay.day + 1,
    );
    final result = <FixedEvent>[];
    for (final template in templates) {
      final repeat = template.repeat;
      if (repeat == null) {
        if (template.startsAt.toLocal().isBefore(throughEnd) &&
            template.endsAt.toLocal().isAfter(fromStart)) {
          result.add(template);
        }
        continue;
      }
      final originalStart = template.startsAt.toLocal();
      final originalEnd = template.endsAt.toLocal();
      // Projection windows count civil dates, including 23/25-hour local days.
      final spanDays =
          DateTime.utc(originalEnd.year, originalEnd.month, originalEnd.day)
              .difference(
                DateTime.utc(
                  originalStart.year,
                  originalStart.month,
                  originalStart.day,
                ),
              )
              .inDays +
          1;
      final rule = RecurrenceRule(
        kind: RecurrenceKind.values.byName(repeat.kind.name),
        startDate: localDate(originalStart),
        interval: repeat.interval,
        weekdays: repeat.weekdays,
        endDate: repeat.untilDate,
      );
      final generatedDates = <String>{};
      for (final slot in rule.between(
        RecurrenceRule.shiftDate(fromDate, -spanDays),
        throughDate,
      )) {
        if (template.activeFromDate != null &&
            slot.nominalDate.compareTo(template.activeFromDate!) < 0) {
          continue;
        }
        if (template.activeThroughDate != null &&
            slot.nominalDate.compareTo(template.activeThroughDate!) > 0) {
          continue;
        }
        generatedDates.add(slot.nominalDate);
        final day = DateTime.parse('${slot.nominalDate} 00:00:00');
        final start = DateTime(
          day.year,
          day.month,
          day.day,
          originalStart.hour,
          originalStart.minute,
          originalStart.second,
        );
        final dayOffset =
            DateTime.utc(originalEnd.year, originalEnd.month, originalEnd.day)
                .difference(
                  DateTime.utc(
                    originalStart.year,
                    originalStart.month,
                    originalStart.day,
                  ),
                )
                .inDays;
        final end = DateTime(
          day.year,
          day.month,
          day.day + dayOffset,
          originalEnd.hour,
          originalEnd.minute,
          originalEnd.second,
        );
        final change = exceptions['${template.id}/${slot.nominalDate}'];
        final cancelled = change?.read<int>('cancelled') == 1;
        if (cancelled && !showCancelled) continue;
        final payload = change?.read<String?>('payload_json');
        final override = payload == null
            ? null
            : jsonDecode(payload) as Map<String, dynamic>;
        final occurrenceStart = override == null
            ? start
            : DateTime.parse(override['startsAt'] as String).toLocal();
        final occurrenceEnd = override == null
            ? end
            : DateTime.parse(override['endsAt'] as String).toLocal();
        if (!occurrenceStart.isBefore(throughEnd) ||
            !occurrenceEnd.isAfter(fromStart)) {
          continue;
        }
        result.add(
          FixedEvent(
            id: template.id,
            title: override?['title'] as String? ?? template.title,
            notes: override?['notes'] as String? ?? template.notes,
            startsAt: occurrenceStart.toUtc(),
            endsAt: occurrenceEnd.toUtc(),
            createdAt: template.createdAt,
            updatedAt: template.updatedAt,
            location: override?['location'] as String? ?? template.location,
            details: override?['details'] is List
                ? (override!['details'] as List<dynamic>)
                      .map(EventDetail.fromJson)
                      .toList()
                : template.details,
            allDay: override?['allDay'] as bool? ?? template.allDay,
            categoryId: _occurrenceCategory(template, override),
            projectId: _occurrenceProject(template, override),
            colorValue: override?.containsKey('colorValue') == true
                ? override!['colorValue'] as int?
                : template.colorValue,
            iconName: override?.containsKey('iconName') == true
                ? override!['iconName'] as String?
                : template.iconName,
            reminderMinutes: override?.containsKey('reminderMinutes') == true
                ? override!['reminderMinutes'] as int?
                : template.reminderMinutes,
            repeat: repeat,
            nominalDate: slot.nominalDate,
            cancelled: cancelled,
            activeFromDate: template.activeFromDate,
            activeThroughDate: template.activeThroughDate,
            seriesFamilyId: template.seriesFamilyId,
          ),
        );
      }
      // A manually changed future occurrence remains visible even when a new
      // rule generation no longer contains its nominal weekday.
      for (final change in changes) {
        if (change.read<String>('event_id') != template.id) continue;
        final nominal = change.read<String>('nominal_date');
        if (generatedDates.contains(nominal)) continue;
        if (template.activeFromDate != null &&
            nominal.compareTo(template.activeFromDate!) < 0) {
          continue;
        }
        if (template.activeThroughDate != null &&
            nominal.compareTo(template.activeThroughDate!) > 0) {
          continue;
        }
        final payload = change.read<String?>('payload_json');
        if (payload == null) continue;
        final cancelled = change.read<int>('cancelled') == 1;
        if (cancelled && !showCancelled) continue;
        final override = jsonDecode(payload) as Map<String, dynamic>;
        final start = DateTime.parse(override['startsAt'] as String);
        final end = DateTime.parse(override['endsAt'] as String);
        if (!start.toLocal().isBefore(throughEnd) ||
            !end.toLocal().isAfter(fromStart)) {
          continue;
        }
        result.add(
          FixedEvent(
            id: template.id,
            title: override['title'] as String,
            notes: override['notes'] as String,
            startsAt: start,
            endsAt: end,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt,
            location: override['location'] as String,
            details: override['details'] is List
                ? (override['details'] as List<dynamic>)
                      .map(EventDetail.fromJson)
                      .toList()
                : template.details,
            allDay: override['allDay'] as bool,
            categoryId: _occurrenceCategory(template, override),
            projectId: _occurrenceProject(template, override),
            colorValue: override.containsKey('colorValue')
                ? override['colorValue'] as int?
                : template.colorValue,
            iconName: override.containsKey('iconName')
                ? override['iconName'] as String?
                : template.iconName,
            reminderMinutes: override.containsKey('reminderMinutes')
                ? override['reminderMinutes'] as int?
                : template.reminderMinutes,
            repeat: repeat,
            nominalDate: nominal,
            cancelled: cancelled,
            activeFromDate: template.activeFromDate,
            activeThroughDate: template.activeThroughDate,
            seriesFamilyId: template.seriesFamilyId,
          ),
        );
      }
    }
    result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return result;
  }

  Future<void> setEventOccurrenceCancelled(
    FixedEvent occurrence,
    bool cancelled,
  ) async {
    final date = occurrence.nominalDate;
    if (date == null) throw ArgumentError('Choose a recurring occurrence');
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customStatement(
      '''INSERT INTO event_occurrence_changes
      (event_id,nominal_date,cancelled,created_at,updated_at)
      VALUES(?,?,?,?,?) ON CONFLICT(event_id,nominal_date) DO UPDATE SET
      cancelled=excluded.cancelled,updated_at=excluded.updated_at''',
      [occurrence.id, date, cancelled ? 1 : 0, now, now],
    );
  }

  Future<void> updateEventOccurrence(FixedEvent occurrence, EventDraft draft) =>
      db.transaction(() async {
        final date = occurrence.nominalDate;
        if (date == null) throw ArgumentError('Choose a recurring occurrence');
        final occurrenceDraft = draft.repeat != null
            ? EventDraft(
                title: draft.title,
                notes: draft.notes,
                startsAt: draft.startsAt,
                endsAt: draft.endsAt,
                location: draft.location,
                details: draft.details,
                allDay: draft.allDay,
                categoryId: draft.categoryId,
                projectId: draft.projectId,
                colorValue: draft.colorValue,
                iconName: draft.iconName,
                reminderMinutes: draft.reminderMinutes,
                alarm: draft.alarm,
                alarmReviewRevision: draft.alarmReviewRevision,
                repeat: null,
              )
            : draft;
        _validateEvent(occurrenceDraft);
        await _checkAssignment(draft.categoryId, draft.projectId);
        if (draft.alarm != null) {
          await saveAlarm(
            draft.alarm!,
            eventId: occurrence.id,
            nominalDate: date,
            expectedRevision: draft.alarmReviewRevision,
          );
        }
        final now = DateTime.now().toUtc().toIso8601String();
        final payload = jsonEncode({
          'title': draft.title.trim(),
          'notes': draft.notes,
          'startsAt': draft.startsAt.toUtc().toIso8601String(),
          'endsAt': draft.endsAt.toUtc().toIso8601String(),
          'location': draft.location.trim(),
          'details': draft.details.map((item) => item.toJson()).toList(),
          'allDay': draft.allDay,
          'categoryId': draft.categoryId,
          'projectId': draft.projectId,
          'colorValue': draft.colorValue,
          'iconName': draft.iconName,
          'reminderMinutes': draft.reminderMinutes,
        });
        await db.customStatement(
          '''INSERT INTO event_occurrence_changes
      (event_id,nominal_date,cancelled,payload_json,created_at,updated_at)
      VALUES(?,?,0,?,?,?) ON CONFLICT(event_id,nominal_date) DO UPDATE SET
      cancelled=0,payload_json=excluded.payload_json,
      updated_at=excluded.updated_at''',
          [occurrence.id, date, payload, now, now],
        );
      });
}
