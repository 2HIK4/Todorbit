part of 'life_repository.dart';

extension HabitRepository on LifeRepository {
  RecurrenceRule _habitRule(QueryRow row) => RecurrenceRule(
    kind: RecurrenceKind.values.byName(row.read<String>('schedule_kind')),
    startDate: row.read<String>('start_date'),
    interval: row.read<int>('interval'),
    weekdays: row.read<String>('weekdays').isEmpty
        ? const {}
        : row.read<String>('weekdays').split(',').map(int.parse).toSet(),
    endDate: row.read<String?>('end_date'),
  );

  Habit _habitFromRow(QueryRow row) => Habit(
    id: row.read<String>('id'),
    title: row.read<String>('title'),
    notes: row.read<String>('notes'),
    kind: HabitKind.values.byName(row.read<String>('kind')),
    target: row.read<double?>('target'),
    unit: row.read<String>('unit'),
    rule: _habitRule(row),
    createdAt: DateTime.parse(row.read<String>('created_at')),
    updatedAt: DateTime.parse(row.read<String>('updated_at')),
    archivedAt: row.read<String?>('archived_at') == null
        ? null
        : DateTime.parse(row.read<String>('archived_at')),
  );

  Future<List<Habit>> habits({bool includeArchived = false}) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM habits ${includeArchived ? '' : 'WHERE archived_at IS NULL'} ORDER BY title COLLATE NOCASE,id',
        )
        .get();
    return rows.map(_habitFromRow).toList();
  }

  Future<List<HabitEntry>> habitEntries({String? habitId}) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM habit_entries ${habitId == null ? '' : 'WHERE habit_id=?'} ORDER BY local_date,id',
          variables: habitId == null ? [] : [Variable.withString(habitId)],
        )
        .get();
    return [
      for (final row in rows)
        HabitEntry(
          id: row.read<String>('id'),
          habitId: row.read<String>('habit_id'),
          localDate: row.read<String>('local_date'),
          value: row.read<double>('value'),
          notes: row.read<String>('notes'),
          createdAt: DateTime.parse(row.read<String>('created_at')),
          updatedAt: DateTime.parse(row.read<String>('updated_at')),
        ),
    ];
  }

  Future<List<HabitRestDay>> habitRestDays({String? habitId}) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM habit_rest_days ${habitId == null ? '' : 'WHERE habit_id=?'} ORDER BY local_date,id',
          variables: habitId == null ? [] : [Variable.withString(habitId)],
        )
        .get();
    return [
      for (final row in rows)
        HabitRestDay(
          id: row.read<String>('id'),
          habitId: row.read<String>('habit_id'),
          localDate: row.read<String>('local_date'),
          notes: row.read<String>('notes'),
        ),
    ];
  }

  void _validateHabit(HabitDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError('Habit title is required');
    }
    if (draft.rule.kind == RecurrenceKind.afterCompletion ||
        draft.rule.maxOccurrences != null) {
      throw ArgumentError('Habits need a fixed schedule without a count limit');
    }
    if (draft.kind == HabitKind.binary) {
      if (draft.target != null || draft.unit.trim().isNotEmpty) {
        throw ArgumentError('Yes/No habits have no numeric target or unit');
      }
    } else if (draft.target == null ||
        !draft.target!.isFinite ||
        draft.target! <= 0) {
      throw ArgumentError('Numeric habits need a positive target');
    }
  }

  List<Variable> _habitValues(HabitDraft draft) => [
    Variable.withString(draft.title.trim()),
    Variable.withString(draft.notes),
    Variable.withString(draft.kind.name),
    Variable<double>(draft.target),
    Variable.withString(draft.unit.trim()),
    Variable.withString(draft.rule.kind.name),
    Variable.withString(draft.rule.startDate),
    Variable.withInt(draft.rule.interval),
    Variable.withString((draft.rule.weekdays.toList()..sort()).join(',')),
    Variable<String>(draft.rule.endDate),
  ];

  Future<Habit> addHabit(HabitDraft draft) async {
    _validateHabit(draft);
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.customInsert(
      '''INSERT INTO habits(id,title,notes,kind,target,unit,schedule_kind,
        start_date,interval,weekdays,end_date,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)''',
      variables: [
        Variable.withString(id),
        ..._habitValues(draft),
        Variable.withString(now),
        Variable.withString(now),
      ],
    );
    return (await habits()).singleWhere((habit) => habit.id == id);
  }

  Future<void> updateHabit(Habit previous, HabitDraft draft) async {
    _validateHabit(draft);
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await db.customUpdate(
      '''UPDATE habits SET title=?,notes=?,kind=?,target=?,unit=?,
        schedule_kind=?,start_date=?,interval=?,weekdays=?,end_date=?,
        updated_at=? WHERE id=? AND updated_at=? AND archived_at IS NULL''',
      variables: [
        ..._habitValues(draft),
        Variable.withString(now),
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) {
      throw StateError('Habit changed. Reopen it before editing.');
    }
  }

  Future<void> setHabitArchived(Habit previous, bool archived) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await db.customUpdate(
      'UPDATE habits SET archived_at=?,updated_at=? WHERE id=? AND updated_at=?',
      variables: [
        Variable<String>(archived ? now : null),
        Variable.withString(now),
        Variable.withString(previous.id),
        Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
      ],
    );
    if (count != 1) {
      throw StateError('Habit changed. Reopen it before archiving.');
    }
  }

  void _validateHabitValue(Habit habit, String day, double value) {
    RecurrenceRule.daysBetween(day, day);
    if (day.compareTo(localDate(DateTime.now())) > 0) {
      throw ArgumentError('Future outcomes cannot be logged');
    }
    if (habit.archivedAt != null) {
      throw StateError('Archived habit is read only');
    }
    if (!habit.scheduledOn(day)) {
      throw ArgumentError('Day is outside the habit schedule');
    }
    if (!value.isFinite ||
        value < 0 ||
        (habit.kind == HabitKind.binary && value != 0 && value != 1)) {
      throw ArgumentError('Invalid habit value');
    }
  }

  Future<void> recordHabitDay(
    Habit habit,
    String day,
    double value, {
    String notes = '',
    HabitEntry? previous,
  }) async {
    _validateHabitValue(habit, day, value);
    await db.transaction(() async {
      final current = await db
          .customSelect(
            'SELECT updated_at FROM habits WHERE id=? AND archived_at IS NULL',
            variables: [Variable.withString(habit.id)],
          )
          .getSingleOrNull();
      if (current == null ||
          current.read<String>('updated_at') !=
              habit.updatedAt.toUtc().toIso8601String()) {
        throw StateError('Habit rule changed. Reopen it before logging.');
      }
      final rest = await db
          .customSelect(
            'SELECT 1 FROM habit_rest_days WHERE habit_id=? AND local_date=?',
            variables: [
              Variable.withString(habit.id),
              Variable.withString(day),
            ],
          )
          .getSingleOrNull();
      if (rest != null) throw StateError('Remove the rest day before logging');
      final now = DateTime.now().toUtc().toIso8601String();
      if (previous == null) {
        final existing = await db
            .customSelect(
              'SELECT 1 FROM habit_entries WHERE habit_id=? AND local_date=?',
              variables: [
                Variable.withString(habit.id),
                Variable.withString(day),
              ],
            )
            .getSingleOrNull();
        if (existing != null) {
          throw StateError('Day already logged. Reopen it first.');
        }
        await db.customInsert(
          '''INSERT INTO habit_entries(id,habit_id,local_date,value,notes,
            created_at,updated_at) VALUES(?,?,?,?,?,?,?)''',
          variables: [
            Variable.withString(_uuid.v4()),
            Variable.withString(habit.id),
            Variable.withString(day),
            Variable.withReal(value),
            Variable.withString(notes),
            Variable.withString(now),
            Variable.withString(now),
          ],
        );
      } else {
        if (previous.habitId != habit.id || previous.localDate != day) {
          throw ArgumentError('Entry does not match this habit day');
        }
        final count = await db.customUpdate(
          '''UPDATE habit_entries SET value=?,notes=?,updated_at=?
            WHERE id=? AND updated_at=?''',
          variables: [
            Variable.withReal(value),
            Variable.withString(notes),
            Variable.withString(now),
            Variable.withString(previous.id),
            Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
          ],
        );
        if (count != 1) {
          throw StateError('Habit entry changed. Reopen it first.');
        }
      }
      await db.customInsert(
        '''INSERT INTO habit_entry_history(id,habit_id,local_date,
          before_value,after_value,before_notes,after_notes,changed_at)
          VALUES(?,?,?,?,?,?,?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(habit.id),
          Variable.withString(day),
          Variable<double>(previous?.value),
          Variable.withReal(value),
          Variable<String>(previous?.notes),
          Variable.withString(notes),
          Variable.withString(now),
        ],
      );
    });
  }

  Future<void> clearHabitDay(HabitEntry previous) async {
    await db.transaction(() async {
      final active = await db
          .customSelect(
            'SELECT 1 FROM habits WHERE id=? AND archived_at IS NULL',
            variables: [Variable.withString(previous.habitId)],
          )
          .getSingleOrNull();
      if (active == null) throw StateError('Archived habit is read only');
      final now = DateTime.now().toUtc().toIso8601String();
      final count = await db.customUpdate(
        'DELETE FROM habit_entries WHERE id=? AND updated_at=?',
        variables: [
          Variable.withString(previous.id),
          Variable.withString(previous.updatedAt.toUtc().toIso8601String()),
        ],
      );
      if (count != 1) throw StateError('Habit entry changed. Reopen it first.');
      await db.customInsert(
        '''INSERT INTO habit_entry_history(id,habit_id,local_date,
          before_value,after_value,before_notes,after_notes,changed_at)
          VALUES(?,?,?, ?,NULL, ?,NULL,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(previous.habitId),
          Variable.withString(previous.localDate),
          Variable.withReal(previous.value),
          Variable.withString(previous.notes),
          Variable.withString(now),
        ],
      );
    });
  }

  Future<void> addHabitRestDay(
    Habit habit,
    String day, {
    String notes = '',
  }) async {
    RecurrenceRule.daysBetween(day, day);
    if (!habit.scheduledOn(day)) {
      throw ArgumentError('Day is outside the habit schedule');
    }
    await db.transaction(() async {
      final current = await db
          .customSelect(
            'SELECT updated_at FROM habits WHERE id=? AND archived_at IS NULL',
            variables: [Variable.withString(habit.id)],
          )
          .getSingleOrNull();
      if (current == null ||
          current.read<String>('updated_at') !=
              habit.updatedAt.toUtc().toIso8601String()) {
        throw StateError('Habit rule changed. Reopen it before resting.');
      }
      final existing = await db
          .customSelect(
            'SELECT 1 FROM habit_entries WHERE habit_id=? AND local_date=?',
            variables: [
              Variable.withString(habit.id),
              Variable.withString(day),
            ],
          )
          .getSingleOrNull();
      if (existing != null) {
        throw StateError('Clear the logged value before resting');
      }
      await db.customInsert(
        '''INSERT OR IGNORE INTO habit_rest_days(
          id,habit_id,local_date,notes,created_at) VALUES(?,?,?,?,?)''',
        variables: [
          Variable.withString(_uuid.v4()),
          Variable.withString(habit.id),
          Variable.withString(day),
          Variable.withString(notes),
          Variable.withString(DateTime.now().toUtc().toIso8601String()),
        ],
      );
    });
  }

  Future<void> removeHabitRestDay(HabitRestDay rest) async {
    final count = await db.customUpdate(
      '''DELETE FROM habit_rest_days WHERE id=? AND habit_id IN
        (SELECT id FROM habits WHERE archived_at IS NULL)''',
      variables: [Variable.withString(rest.id)],
    );
    if (count != 1) throw StateError('Rest day changed or habit is archived');
  }
}
