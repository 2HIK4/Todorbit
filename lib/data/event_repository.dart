part of 'life_repository.dart';

FixedEvent _eventFromRow(QueryRow row) {
  final kind = row.read<String?>('recurrence_kind');
  final weekdays = row.read<String?>('recurrence_weekdays');
  return FixedEvent(
    id: row.read<String>('id'),
    title: row.read<String>('title'),
    notes: row.read<String>('notes'),
    startsAt: DateTime.parse(row.read<String>('starts_at')),
    endsAt: DateTime.parse(row.read<String>('ends_at')),
    createdAt: DateTime.parse(row.read<String>('created_at')),
    updatedAt: DateTime.parse(row.read<String>('updated_at')),
    location: row.read<String>('location'),
    allDay: row.read<int>('all_day') == 1,
    categoryId: row.read<String?>('category_id'),
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

extension EventRepository on LifeRepository {
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
      allDay: draft.allDay,
      categoryId: draft.categoryId,
      colorValue: draft.colorValue,
      iconName: draft.iconName,
      reminderMinutes: draft.reminderMinutes,
      repeat: draft.repeat,
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
    final throughEnd = DateTime.parse('$throughDate 00:00:00')
        .add(const Duration(days: 1));
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
      final spanDays = originalEnd.difference(originalStart).inDays + 1;
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
            allDay: override?['allDay'] as bool? ?? template.allDay,
            categoryId:
                override?['categoryId'] as String? ?? template.categoryId,
            colorValue: override?['colorValue'] as int? ?? template.colorValue,
            iconName: override?['iconName'] as String? ?? template.iconName,
            reminderMinutes:
                override?['reminderMinutes'] as int? ??
                template.reminderMinutes,
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
            allDay: override['allDay'] as bool,
            categoryId: override['categoryId'] as String?,
            colorValue: override['colorValue'] as int?,
            iconName: override['iconName'] as String?,
            reminderMinutes: override['reminderMinutes'] as int?,
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

  Future<void> updateEventOccurrence(
    FixedEvent occurrence,
    EventDraft draft,
  ) async {
    final date = occurrence.nominalDate;
    if (date == null) throw ArgumentError('Choose a recurring occurrence');
    _validateEvent(draft);
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = jsonEncode({
      'title': draft.title.trim(),
      'notes': draft.notes,
      'startsAt': draft.startsAt.toUtc().toIso8601String(),
      'endsAt': draft.endsAt.toUtc().toIso8601String(),
      'location': draft.location.trim(),
      'allDay': draft.allDay,
      'categoryId': draft.categoryId,
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
  }
}
