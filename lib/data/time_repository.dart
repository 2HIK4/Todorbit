part of 'life_repository.dart';

extension TimeRepository on LifeRepository {
  TimerRun _runFromRow(QueryRow row) => TimerRun(
    id: row.read<String>('id'),
    taskId: row.read<String?>('task_id'),
    state: TimerState.values.byName(row.read<String>('state')),
    startedAt: DateTime.parse(row.read<String>('started_at')),
    lastSeenAt: DateTime.parse(row.read<String>('last_seen_at')),
    stoppedAt: row.read<String?>('stopped_at') == null
        ? null
        : DateTime.parse(row.read<String>('stopped_at')),
    updatedAt: DateTime.parse(row.read<String>('updated_at')),
  );

  TimeEntry _timeFromRow(QueryRow row) => TimeEntry(
    id: row.read<String>('id'),
    taskId: row.read<String?>('task_id'),
    sessionId: row.read<String?>('session_id'),
    timerRunId: row.read<String?>('timer_run_id'),
    source: TimeEntrySource.values.byName(row.read<String>('source')),
    startsAt: DateTime.parse(row.read<String>('starts_at')),
    endsAt: row.read<String?>('ends_at') == null
        ? null
        : DateTime.parse(row.read<String>('ends_at')),
    notes: row.read<String>('notes'),
    updatedAt: DateTime.parse(row.read<String>('updated_at')),
  );

  Future<TimerRun?> activeTimerRun() async {
    final row = await db
        .customSelect("SELECT * FROM timer_runs WHERE state!='stopped' LIMIT 1")
        .getSingleOrNull();
    return row == null ? null : _runFromRow(row);
  }

  Future<List<TimeEntry>> timeEntries({String? taskId}) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM time_entries ${taskId == null ? '' : 'WHERE task_id=?'} ORDER BY starts_at DESC,id',
          variables: taskId == null ? [] : [Variable.withString(taskId)],
        )
        .get();
    return rows.map(_timeFromRow).toList();
  }

  Future<TimerRun> startTimer(String taskId) async {
    final id = _uuid.v4();
    await db.transaction(() async {
      final task = await db
          .customSelect(
            '''SELECT 1 FROM tasks t
              LEFT JOIN categories c ON c.id=t.category_id
              LEFT JOIN projects p ON p.id=t.project_id
              LEFT JOIN recurrence_occurrences o ON o.task_id=t.id
              LEFT JOIN recurrence_series s ON s.id=o.series_id
              WHERE t.id=? AND t.deleted_at IS NULL AND t.archived_at IS NULL
                AND (c.id IS NULL OR c.deleted_at IS NULL)
                AND (p.id IS NULL OR p.deleted_at IS NULL)
                AND (s.id IS NULL OR (s.deleted_at IS NULL AND s.archived_at IS NULL))''',
            variables: [Variable.withString(taskId)],
          )
          .getSingleOrNull();
      if (task == null) throw StateError('Task no longer exists');
      if (await activeTimerRun() != null) {
        throw StateError('Pause or stop the existing timer first');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customInsert(
        '''INSERT INTO timer_runs(id,task_id,state,started_at,last_seen_at,
          created_at,updated_at) VALUES(?,?,'running',?,?,?,?)''',
        variables: [
          Variable.withString(id),
          Variable.withString(taskId),
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      await db.customInsert(
        '''INSERT INTO time_entries(id,task_id,timer_run_id,source,starts_at,
          notes,created_at,updated_at) VALUES(?,?,?,'timer',?,'',?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(taskId),
          Variable.withString(id),
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    });
    return (await activeTimerRun())!;
  }

  Future<TimerRun> _currentRun(TimerRun previous, String expectedState) async {
    final row = await db
        .customSelect(
          'SELECT * FROM timer_runs WHERE id=? AND state=? AND updated_at=?',
          variables: [
            Variable.withString(previous.id),
            Variable.withString(expectedState),
            Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
          ],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Timer changed. Refresh it first.');
    return _runFromRow(row);
  }

  Future<DateTime?> heartbeatTimer(TimerRun previous) async {
    return db.transaction(() async {
      final current = await _currentRun(previous, 'running');
      final now = DateTime.now().toUtc();
      if (current.needsReview(now)) return null;
      await db.customUpdate(
        'UPDATE timer_runs SET last_seen_at=? WHERE id=?',
        variables: [
          Variable.withString(now.toIso8601String()),
          Variable.withString(previous.id),
        ],
      );
      return now;
    });
  }

  Future<void> _closeOpenInterval(String runId, DateTime end) async {
    final row = await db
        .customSelect(
          'SELECT id,starts_at FROM time_entries WHERE timer_run_id=? AND ends_at IS NULL',
          variables: [Variable.withString(runId)],
        )
        .getSingleOrNull();
    if (row == null) throw StateError('Open timer interval is missing');
    final starts = DateTime.parse(row.read<String>('starts_at'));
    final safeEnd = end.isBefore(starts) ? starts : end;
    await db.customUpdate(
      'UPDATE time_entries SET ends_at=?,updated_at=? WHERE id=?',
      variables: [
        Variable.withString(safeEnd.toUtc().toIso8601String()),
        Variable.withString(DateTime.now().toUtc().toIso8601String()),
        Variable.withString(row.read<String>('id')),
      ],
    );
  }

  Future<void> pauseTimer(TimerRun previous) async {
    await db.transaction(() async {
      final current = await _currentRun(previous, 'running');
      final now = DateTime.now().toUtc();
      if (current.needsReview(now)) {
        throw StateError('Review the recovered timer before pausing it');
      }
      await _closeOpenInterval(previous.id, now);
      await db.customUpdate(
        "UPDATE timer_runs SET state='paused',last_seen_at=?,updated_at=? WHERE id=?",
        variables: [
          Variable.withString(now.toIso8601String()),
          Variable.withString(now.toIso8601String()),
          Variable.withString(previous.id),
        ],
      );
    });
  }

  Future<void> resumeTimer(TimerRun previous) async {
    await db.transaction(() async {
      final current = await _currentRun(previous, 'paused');
      if (current.taskId == null) throw StateError('The task was deleted');
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customInsert(
        '''INSERT INTO time_entries(id,task_id,timer_run_id,source,starts_at,
          notes,created_at,updated_at) VALUES(?,?,?,'timer',?,'',?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(current.taskId!),
          Variable.withString(current.id),
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
      await db.customUpdate(
        "UPDATE timer_runs SET state='running',last_seen_at=?,updated_at=? WHERE id=?",
        variables: [
          Variable.withString(now),
          Variable.withString(now),
          Variable.withString(previous.id),
        ],
      );
    });
  }

  Future<void> stopTimer(TimerRun previous) async {
    await db.transaction(() async {
      final current = await _currentRun(previous, previous.state.name);
      final now = DateTime.now().toUtc();
      if (current.state == TimerState.running) {
        if (current.needsReview(now)) {
          throw StateError('Review the recovered timer before stopping it');
        }
        await _closeOpenInterval(previous.id, now);
      }
      await db.customUpdate(
        "UPDATE timer_runs SET state='stopped',stopped_at=?,updated_at=? WHERE id=?",
        variables: [
          Variable.withString(now.toIso8601String()),
          Variable.withString(now.toIso8601String()),
          Variable.withString(previous.id),
        ],
      );
    });
  }

  Future<void> keepRecoveredTimer(TimerRun previous) async {
    await db.transaction(() async {
      final current = await _currentRun(previous, 'running');
      final now = DateTime.now().toUtc();
      if (!current.needsReview(now)) return;
      await db.customUpdate(
        'UPDATE timer_runs SET last_seen_at=?,updated_at=? WHERE id=?',
        variables: [
          Variable.withString(now.toIso8601String()),
          Variable.withString(now.toIso8601String()),
          Variable.withString(previous.id),
        ],
      );
    });
  }

  Future<void> stopRecoveredTimerAtCheckpoint(TimerRun previous) async {
    await db.transaction(() async {
      final current = await _currentRun(previous, 'running');
      if (!current.needsReview(DateTime.now().toUtc())) {
        throw StateError('Timer does not need recovery');
      }
      await _closeOpenInterval(previous.id, current.lastSeenAt);
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customUpdate(
        "UPDATE timer_runs SET state='stopped',stopped_at=?,updated_at=? WHERE id=?",
        variables: [
          Variable.withString(current.lastSeenAt.toIso8601String()),
          Variable.withString(now),
          Variable.withString(previous.id),
        ],
      );
    });
  }

  void _checkManualInterval(DateTime startsAt, DateTime endsAt) {
    if (!endsAt.toUtc().isAfter(startsAt.toUtc())) {
      throw ArgumentError('Actual work end must follow its start');
    }
    if (endsAt.toUtc().isAfter(DateTime.now().toUtc())) {
      throw ArgumentError('Actual work cannot be logged in the future');
    }
  }

  Future<void> addManualTime(
    String taskId,
    DateTime startsAt,
    DateTime endsAt,
    String notes, {
    String? sessionId,
  }) async {
    _checkManualInterval(startsAt, endsAt);
    await db.transaction(() async {
      if (sessionId != null) {
        final row = await db
            .customSelect(
              'SELECT 1 FROM work_sessions WHERE id=? AND task_id=?',
              variables: [
                Variable.withString(sessionId),
                Variable.withString(taskId),
              ],
            )
            .getSingleOrNull();
        if (row == null) throw ArgumentError('Session does not belong to task');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await db.customInsert(
        '''INSERT INTO time_entries(id,task_id,session_id,source,starts_at,
          ends_at,notes,created_at,updated_at)
          VALUES(?,?,?,'manual',?,?,?,?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(taskId),
          Variable<String>(sessionId),
          Variable.withString(startsAt.toUtc().toIso8601String()),
          Variable.withString(endsAt.toUtc().toIso8601String()),
          Variable.withString(notes),
          Variable.withString(now),
          Variable.withString(now),
        ],
      );
    });
  }

  Future<void> updateManualTime(
    TimeEntry previous,
    DateTime startsAt,
    DateTime endsAt,
    String notes,
  ) async {
    if (previous.source != TimeEntrySource.manual) {
      throw ArgumentError('Timer intervals cannot be rewritten as manual logs');
    }
    _checkManualInterval(startsAt, endsAt);
    await db.transaction(() async {
      final now = DateTime.now().toUtc().toIso8601String();
      final count = await db.customUpdate(
        '''UPDATE time_entries SET starts_at=?,ends_at=?,notes=?,updated_at=?
          WHERE id=? AND updated_at=? AND source='manual' ''',
        variables: [
          Variable.withString(startsAt.toUtc().toIso8601String()),
          Variable.withString(endsAt.toUtc().toIso8601String()),
          Variable.withString(notes),
          Variable.withString(now),
          Variable.withString(previous.id),
          Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (count != 1) throw StateError('Time entry changed. Reopen it first.');
      await _recordTimeHistory(
        previous,
        'edit',
        jsonEncode({
          'starts_at': startsAt.toUtc().toIso8601String(),
          'ends_at': endsAt.toUtc().toIso8601String(),
          'notes': notes,
        }),
        now,
      );
    });
  }

  Future<void> clearManualTime(TimeEntry previous) async {
    if (previous.source != TimeEntrySource.manual) {
      throw ArgumentError('Timer intervals cannot be cleared here');
    }
    await db.transaction(() async {
      final count = await db.customUpdate(
        "DELETE FROM time_entries WHERE id=? AND updated_at=? AND source='manual'",
        variables: [
          Variable.withString(previous.id),
          Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (count != 1) throw StateError('Time entry changed. Reopen it first.');
      await _recordTimeHistory(
        previous,
        'clear',
        null,
        DateTime.now().toUtc().toIso8601String(),
      );
    });
  }

  Future<void> _recordTimeHistory(
    TimeEntry previous,
    String action,
    String? after,
    String now,
  ) => db.customInsert(
    '''INSERT INTO time_entry_history(id,entry_id,task_id,action,before_json,
      after_json,changed_at) VALUES(?,?,?,?,?,?,?)''',
    variables: [
      Variable.withString(_uuid.v4()),
      Variable.withString(previous.id),
      Variable<String>(previous.taskId),
      Variable.withString(action),
      Variable.withString(
        jsonEncode({
          'starts_at': previous.startsAt.toUtc().toIso8601String(),
          'ends_at': previous.endsAt?.toUtc().toIso8601String(),
          'notes': previous.notes,
        }),
      ),
      Variable<String>(after),
      Variable.withString(now),
    ],
  );
}
