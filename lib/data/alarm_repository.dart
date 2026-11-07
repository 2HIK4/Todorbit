part of 'life_repository.dart';

extension AlarmRepository on LifeRepository {
  Future<List<AlarmRule>> alarmRules() async =>
      (await db
              .customSelect(
                'SELECT * FROM alarm_rules WHERE deleted_at IS NULL AND archived_at IS NULL',
              )
              .get())
          .map(
            (r) => AlarmRule(
              id: r.read<String>('id'),
              taskId: r.read<String?>('task_id'),
              eventId: r.read<String?>('event_id'),
              seriesId: r.read<String?>('series_id'),
              nominalDate: r.read<String>('nominal_date'),
              updatedAt: r.read<String>('updated_at'),
              config: AlarmConfig.fromJson(
                (jsonDecode(r.read<String>('config_json')) as Map)
                    .cast<String, dynamic>(),
              ),
            ),
          )
          .toList();

  Future<void> replaceTaskAlarm(LifeTask task, TaskDraft draft) async {
    if (draft.alarm == null) return;
    if (!draft.alarmForFamily) {
      await saveAlarm(
        draft.alarm!,
        taskId: task.id,
        expectedRevision: draft.alarmReviewRevision,
      );
      return;
    }
    final family = task.recurrenceFamilyId ?? task.recurrenceSeriesId;
    if (family == null) throw StateError('This task has no recurring family.');
    final current = await db
        .customSelect(
          'SELECT id,updated_at FROM alarm_rules WHERE task_id=?',
          variables: [Variable.withString(task.id)],
        )
        .getSingleOrNull();
    final reviewed = draft.alarmReviewRevision;
    if (reviewed != null &&
        ((reviewed == 'new' && current != null) ||
            (reviewed != 'new' &&
                current?.read<String>('updated_at') != reviewed))) {
      throw StateError('Alarm changed; reopen the editor before saving.');
    }
    if (current != null) {
      await db.customStatement('DELETE FROM alarm_rules WHERE id=?', [
        current.read<String>('id'),
      ]);
    }
    await saveAlarm(
      draft.alarm!,
      seriesId: family,
      expectedRevision: draft.alarmFamilyReviewRevision,
    );
  }

  /// Called inside the entity mutation transaction, never a native OS write.
  Future<void> saveAlarm(
    AlarmConfig config, {
    String? taskId,
    String? eventId,
    String? seriesId,
    String nominalDate = '',
    String? expectedRevision,
  }) => db.transaction(() async {
    AlarmConfig.fromJson(config.toJson());
    if ([taskId, eventId, seriesId].whereType<String>().length != 1 ||
        (nominalDate.isNotEmpty &&
            (eventId == null ||
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(nominalDate))) ||
        (seriesId != null && config.mode == 'custom') ||
        (eventId != null && config.mode == 'planned')) {
      throw const FormatException(
        'Choose one alarm owner; recurring tasks use a relative time',
      );
    }
    if (config.mode == 'custom' && eventId != null && nominalDate.isEmpty) {
      final owner = await db
          .customSelect(
            'SELECT recurrence_kind FROM fixed_events WHERE id=?',
            variables: [Variable.withString(eventId)],
          )
          .getSingleOrNull();
      if (owner?.read<String?>('recurrence_kind') != null) {
        throw const FormatException(
          'Recurring event alarms use event-start timing; select a single occurrence for an exact alarm.',
        );
      }
    }
    final id = const Uuid().v5(
      Namespace.url.value,
      'todorbit:alarm:$taskId:$eventId:$seriesId:$nominalDate',
    );
    if (expectedRevision != null) {
      final previous = await db
          .customSelect(
            'SELECT updated_at FROM alarm_rules WHERE id=?',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      if ((expectedRevision == 'new' && previous != null) ||
          (expectedRevision != 'new' &&
              previous?.read<String>('updated_at') != expectedRevision)) {
        throw StateError('Alarm changed; reopen the editor before saving.');
      }
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customStatement(
      '''INSERT INTO alarm_rules
      (id,task_id,event_id,series_id,nominal_date,config_json,created_at,updated_at)
      VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET
      config_json=excluded.config_json,updated_at=excluded.updated_at,deleted_at=NULL,archived_at=NULL''',
      [
        id,
        taskId,
        eventId,
        seriesId,
        nominalDate,
        jsonEncode(config.toJson()),
        now,
        now,
      ],
    );
  });
}
