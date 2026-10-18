import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;

class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  static const currentSchemaVersion = 15;

  static Future<File> defaultFile() async {
    final String basePath;
    if (Platform.isWindows) {
      basePath =
          Platform.environment['APPDATA'] ??
          (throw StateError('Windows APPDATA directory is unavailable'));
    } else {
      final home = Platform.environment['HOME'];
      basePath =
          Platform.environment['XDG_DATA_HOME'] ??
          (home == null
              ? throw StateError('User data directory is unavailable')
              : path.join(home, '.local', 'share'));
    }
    final directory = Directory(path.join(basePath, 'Life Manager'));
    await directory.create(recursive: true);
    return File(path.join(directory.path, 'life_manager.sqlite'));
  }

  static Future<AppDatabase> openDefault() async {
    final file = await defaultFile();
    return AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (database) {
          database.execute('PRAGMA foreign_keys = ON');
          database.execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
  }

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (migrator) async {
      await customStatement('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL COLLATE NOCASE UNIQUE,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE projects (
          id TEXT PRIMARY KEY,
          category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(category_id, name)
        )
      ''');
      await customStatement('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL CHECK(length(trim(title)) > 0),
          notes TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL CHECK(status IN ('notStarted','inProgress','waiting','onHold','completed','cancelled')),
          priority INTEGER NOT NULL DEFAULT 0 CHECK(priority BETWEEN 0 AND 3),
          category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
          project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT,
          scheduled_date TEXT,
          deadline_date TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          completed_at TEXT,
          planned_duration_minutes INTEGER CHECK(planned_duration_minutes IS NULL OR planned_duration_minutes > 0),
          remaining_work_minutes INTEGER CHECK(remaining_work_minutes IS NULL OR remaining_work_minutes >= 0),
          scheduling_locked INTEGER NOT NULL DEFAULT 0 CHECK(scheduling_locked IN (0,1))
        )
      ''');
      await customStatement(
        'CREATE INDEX tasks_status_schedule ON tasks(status, scheduled_date)',
      );
      await customStatement(
        'CREATE INDEX tasks_deadline ON tasks(deadline_date)',
      );
      await customStatement('CREATE INDEX tasks_project ON tasks(project_id)');
      await customStatement(
        'CREATE INDEX tasks_category ON tasks(category_id)',
      );
      await customStatement(
        'CREATE INDEX projects_category ON projects(category_id)',
      );
      await _createEvents();
      await _createSessions();
      await _createScheduling();
      await _createRelationships();
      await _createRecurrence();
      await _createSeriesEditHistory();
      await _createRecurrenceCollisionHistory();
      await _createHabits();
      await _createGoals();
      await _createTimeTracking();
      await _createTemplates();
      await _createSavedViews();
      await _createTrash();
      await _createNotifications();
      await _createTaskResources();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from > 14 || to != 15) {
        throw StateError('No migration registered from schema $from to $to');
      }
      if (from == 1) {
        await _createEvents();
      }
      if (from < 3) {
        await _createSessions();
      }
      if (from < 4) {
        await customStatement(
          'ALTER TABLE tasks ADD COLUMN planned_duration_minutes INTEGER CHECK(planned_duration_minutes IS NULL OR planned_duration_minutes > 0)',
        );
        await customStatement(
          'ALTER TABLE tasks ADD COLUMN remaining_work_minutes INTEGER CHECK(remaining_work_minutes IS NULL OR remaining_work_minutes >= 0)',
        );
        await customStatement(
          'ALTER TABLE tasks ADD COLUMN scheduling_locked INTEGER NOT NULL DEFAULT 0 CHECK(scheduling_locked IN (0,1))',
        );
        await _createScheduling();
      }
      if (from < 5) {
        await _createRelationships();
      }
      if (from < 6) {
        await _createRecurrence();
      } else if (from < 7) {
        await _upgradeRecurrenceVersions();
      }
      if (from < 7) {
        await _createSeriesEditHistory();
        await _createRecurrenceCollisionHistory();
      }
      if (from < 8) await _createHabits();
      if (from < 9) await _createGoals();
      if (from < 10) await _createTimeTracking();
      await _createTemplates();
      await _createSavedViews();
      await _createTrash();
      await _createNotifications();
      await _createTaskResources();
    },
  );

  Future<void> _createTaskResources() async {
    await customStatement('''CREATE TABLE IF NOT EXISTS task_resources (
      id TEXT PRIMARY KEY,
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      kind TEXT NOT NULL CHECK(kind IN ('managed','externalFile','externalFolder','url')),
      label TEXT NOT NULL CHECK(length(trim(label)) > 0),
      target TEXT,
      content BLOB,
      byte_size INTEGER,
      sha256 TEXT,
      original_name TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CHECK((kind='managed' AND target IS NULL AND content IS NOT NULL
        AND byte_size IS NOT NULL AND sha256 IS NOT NULL AND original_name IS NOT NULL)
        OR (kind!='managed' AND target IS NOT NULL AND content IS NULL))
    )''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS task_resources_task ON task_resources(task_id, created_at)',
    );
  }

  Future<void> _createNotifications() async {
    await customStatement('''CREATE TABLE IF NOT EXISTS notification_settings (
      id INTEGER PRIMARY KEY CHECK(id=1),
      due_reminders INTEGER NOT NULL DEFAULT 0 CHECK(due_reminders IN (0,1)),
      daily_summary INTEGER NOT NULL DEFAULT 0 CHECK(daily_summary IN (0,1)),
      local_minute INTEGER NOT NULL DEFAULT 540 CHECK(local_minute BETWEEN 0 AND 1439),
      updated_at TEXT NOT NULL
    )''');
    await customStatement(
      '''CREATE TABLE IF NOT EXISTS notification_deliveries (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL CHECK(kind IN ('due','summary')),
      local_day TEXT NOT NULL,
      delivered_at TEXT NOT NULL,
      UNIQUE(kind, local_day)
    )''',
    );
  }

  Future<void> _createTrash() async {
    await customStatement('''CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await customStatement('''CREATE TABLE IF NOT EXISTS projects (
      id TEXT PRIMARY KEY,
      category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
      name TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      UNIQUE(category_id, name))''');
    await customStatement('''CREATE TABLE IF NOT EXISTS fixed_events (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      notes TEXT NOT NULL DEFAULT '', starts_at TEXT NOT NULL,
      ends_at TEXT NOT NULL, created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL, CHECK(ends_at > starts_at))''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS fixed_events_start ON fixed_events(starts_at)',
    );
    for (final table in [
      'tasks',
      'projects',
      'categories',
      'fixed_events',
      'work_sessions',
    ]) {
      await _addColumnIfMissing(table, 'deleted_at', 'TEXT');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS ${table}_deleted_at ON $table(deleted_at)',
      );
    }
    await _addColumnIfMissing('recurrence_series', 'deleted_at', 'TEXT');
    await _addColumnIfMissing('recurrence_series', 'archived_at', 'TEXT');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS recurrence_series_deleted_at ON recurrence_series(deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS recurrence_series_archived_at ON recurrence_series(archived_at)',
    );
    await _addColumnIfMissing('tasks', 'archived_at', 'TEXT');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS tasks_archived_at ON tasks(archived_at)',
    );
    await customStatement('''
      CREATE TABLE IF NOT EXISTS deletion_tombstones (
        id TEXT PRIMARY KEY,
        entity_kind TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        deleted_at TEXT NOT NULL,
        purged_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String type,
  ) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    if (columns.any((row) => row.read<String>('name') == column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
  }

  Future<void> _upgradeRecurrenceVersions() async {
    await customStatement(
      'ALTER TABLE recurrence_series ADD COLUMN family_id TEXT',
    );
    await customStatement(
      'ALTER TABLE recurrence_series ADD COLUMN active_from_date TEXT',
    );
    await customStatement(
      'ALTER TABLE recurrence_series ADD COLUMN active_through_date TEXT',
    );
    await customStatement(
      'UPDATE recurrence_series SET family_id=id, active_from_date=start_date',
    );
    await customStatement(
      'CREATE INDEX recurrence_series_family ON recurrence_series(family_id,active_from_date)',
    );
  }

  Future<void> _createSeriesEditHistory() async {
    await customStatement('''
      CREATE TABLE series_edit_history (
        id TEXT PRIMARY KEY,
        family_id TEXT NOT NULL,
        source_task_id TEXT NOT NULL,
        new_series_id TEXT NOT NULL REFERENCES recurrence_series(id),
        scope TEXT NOT NULL,
        effective_date TEXT NOT NULL,
        details_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX series_edit_history_family ON series_edit_history(family_id,created_at)',
    );
  }

  Future<void> _createRecurrenceCollisionHistory() async {
    await customStatement('''
      CREATE TABLE recurrence_collision_history (
        id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL REFERENCES scheduling_operations(id),
        moved_task_id TEXT NOT NULL,
        existing_task_ids TEXT NOT NULL,
        planned_date TEXT NOT NULL,
        choice TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createHabits() async {
    await customStatement('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        notes TEXT NOT NULL DEFAULT '',
        kind TEXT NOT NULL CHECK(kind IN ('binary','minimum','maximum')),
        target REAL,
        unit TEXT NOT NULL DEFAULT '',
        schedule_kind TEXT NOT NULL CHECK(schedule_kind IN
          ('daily','weekly','weekdays','monthly','yearly')),
        start_date TEXT NOT NULL,
        interval INTEGER NOT NULL CHECK(interval > 0),
        weekdays TEXT NOT NULL DEFAULT '',
        end_date TEXT,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK((kind='binary' AND target IS NULL) OR
          (kind!='binary' AND target > 0))
      )
    ''');
    await customStatement('''
      CREATE TABLE habit_entries (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        local_date TEXT NOT NULL,
        value REAL NOT NULL CHECK(value >= 0),
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(habit_id,local_date)
      )
    ''');
    await customStatement(
      'CREATE INDEX habit_entries_date ON habit_entries(local_date,habit_id)',
    );
    await customStatement('''
      CREATE TABLE habit_rest_days (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        local_date TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        UNIQUE(habit_id,local_date)
      )
    ''');
    await customStatement('''
      CREATE TABLE habit_entry_history (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        local_date TEXT NOT NULL,
        before_value REAL,
        after_value REAL,
        before_notes TEXT,
        after_notes TEXT,
        changed_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createGoals() async {
    await customStatement('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        description TEXT NOT NULL DEFAULT '',
        target REAL NOT NULL CHECK(target > 0),
        unit TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        deadline_date TEXT,
        completed_at TEXT,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE goal_milestones (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        threshold REAL NOT NULL CHECK(threshold > 0),
        deadline_date TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE goal_progress_entries (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
        delta REAL NOT NULL CHECK(delta != 0),
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX goal_progress_entries_goal ON goal_progress_entries(goal_id,created_at)',
    );
    await customStatement(
      'CREATE INDEX goal_milestones_goal ON goal_milestones(goal_id,threshold)',
    );
    for (final pair in [
      ('task', 'tasks'),
      ('project', 'projects'),
      ('habit', 'habits'),
    ]) {
      await customStatement('''
        CREATE TABLE goal_${pair.$1}_links (
          goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
          ${pair.$1}_id TEXT NOT NULL REFERENCES ${pair.$2}(id) ON DELETE CASCADE,
          units REAL NOT NULL CHECK(units > 0),
          PRIMARY KEY(goal_id,${pair.$1}_id)
        )
      ''');
    }
  }

  Future<void> _createTimeTracking() async {
    await customStatement('''
      CREATE TABLE timer_runs (
        id TEXT PRIMARY KEY,
        task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
        state TEXT NOT NULL CHECK(state IN ('running','paused','stopped')),
        started_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        stopped_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement(
      "CREATE UNIQUE INDEX one_active_timer ON timer_runs((1)) WHERE state!='stopped'",
    );
    await customStatement('''
      CREATE TABLE time_entries (
        id TEXT PRIMARY KEY,
        task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
        session_id TEXT REFERENCES work_sessions(id) ON DELETE SET NULL,
        timer_run_id TEXT REFERENCES timer_runs(id) ON DELETE RESTRICT,
        source TEXT NOT NULL CHECK(source IN ('manual','timer')),
        starts_at TEXT NOT NULL,
        ends_at TEXT,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(ends_at IS NULL OR ends_at >= starts_at),
        CHECK((source='manual' AND timer_run_id IS NULL AND ends_at IS NOT NULL)
          OR (source='timer' AND timer_run_id IS NOT NULL))
      )
    ''');
    await customStatement(
      'CREATE INDEX time_entries_task ON time_entries(task_id,starts_at)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX time_entries_open_run ON time_entries(timer_run_id) WHERE ends_at IS NULL',
    );
    await customStatement('''
      CREATE TABLE time_entry_history (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        task_id TEXT,
        action TEXT NOT NULL,
        before_json TEXT,
        after_json TEXT,
        changed_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTemplates() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        kind TEXT NOT NULL CHECK(kind IN ('task','project','routine')),
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSavedViews() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS saved_views (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        filter_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createRecurrence() async {
    await customStatement('''
      CREATE TABLE recurrence_series (
        id TEXT PRIMARY KEY,
        family_id TEXT NOT NULL,
        active_from_date TEXT NOT NULL,
        active_through_date TEXT,
        kind TEXT NOT NULL CHECK(kind IN ('daily','weekly','weekdays','monthly','yearly','afterCompletion')),
        start_date TEXT NOT NULL,
        interval INTEGER NOT NULL CHECK(interval > 0),
        weekdays TEXT NOT NULL DEFAULT '',
        end_date TEXT,
        max_occurrences INTEGER CHECK(max_occurrences IS NULL OR max_occurrences > 0),
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        notes TEXT NOT NULL DEFAULT '',
        priority INTEGER NOT NULL DEFAULT 0 CHECK(priority BETWEEN 0 AND 3),
        category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT,
        project_id TEXT REFERENCES projects(id) ON DELETE RESTRICT,
        deadline_offset_days INTEGER,
        planned_duration_minutes INTEGER CHECK(planned_duration_minutes IS NULL OR planned_duration_minutes > 0),
        remaining_work_minutes INTEGER CHECK(remaining_work_minutes IS NULL OR remaining_work_minutes >= 0),
        scheduling_locked INTEGER NOT NULL DEFAULT 0 CHECK(scheduling_locked IN (0,1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX recurrence_series_family ON recurrence_series(family_id,active_from_date)',
    );
    await customStatement('''
      CREATE TABLE recurrence_occurrences (
        id TEXT PRIMARY KEY,
        series_id TEXT NOT NULL REFERENCES recurrence_series(id) ON DELETE CASCADE,
        ordinal INTEGER NOT NULL CHECK(ordinal >= 0),
        nominal_date TEXT NOT NULL,
        task_id TEXT UNIQUE REFERENCES tasks(id) ON DELETE SET NULL,
        disposition TEXT NOT NULL DEFAULT 'active'
          CHECK(disposition IN ('active','skipped','cancelled')),
        is_edited INTEGER NOT NULL DEFAULT 0 CHECK(is_edited IN (0,1)),
        is_rescheduled INTEGER NOT NULL DEFAULT 0 CHECK(is_rescheduled IN (0,1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(series_id, ordinal)
      )
    ''');
    await customStatement(
      'CREATE INDEX recurrence_occurrences_series_date ON recurrence_occurrences(series_id, nominal_date)',
    );
    await customStatement('''
      CREATE TRIGGER recurrence_task_schedule_updated
      AFTER UPDATE OF scheduled_date ON tasks
      WHEN OLD.scheduled_date IS NOT NEW.scheduled_date
      BEGIN
        UPDATE recurrence_occurrences
        SET is_rescheduled=(NEW.scheduled_date IS NOT nominal_date),
            updated_at=NEW.updated_at
        WHERE task_id=NEW.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER recurrence_task_content_updated
      AFTER UPDATE OF title,notes,priority,category_id,project_id,
        deadline_date,planned_duration_minutes,remaining_work_minutes,
        scheduling_locked ON tasks
      WHEN OLD.title IS NOT NEW.title OR OLD.notes IS NOT NEW.notes OR
        OLD.priority IS NOT NEW.priority OR
        OLD.category_id IS NOT NEW.category_id OR
        OLD.project_id IS NOT NEW.project_id OR
        OLD.deadline_date IS NOT NEW.deadline_date OR
        OLD.planned_duration_minutes IS NOT NEW.planned_duration_minutes OR
        OLD.remaining_work_minutes IS NOT NEW.remaining_work_minutes OR
        OLD.scheduling_locked IS NOT NEW.scheduling_locked
      BEGIN
        UPDATE recurrence_occurrences
        SET is_edited=1, updated_at=NEW.updated_at
        WHERE task_id=NEW.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER recurrence_task_cancelled
      AFTER UPDATE OF status ON tasks
      WHEN OLD.status IS NOT NEW.status AND
        (OLD.status='cancelled' OR NEW.status='cancelled')
      BEGIN
        UPDATE recurrence_occurrences
        SET disposition=CASE WHEN NEW.status='cancelled'
          THEN 'cancelled' ELSE 'active' END,
          updated_at=NEW.updated_at
        WHERE task_id=NEW.id;
      END
    ''');
  }

  Future<void> _createRelationships() async {
    await customStatement('''
      CREATE TABLE task_sequences (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL CHECK(length(trim(name)) > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE sequence_tasks (
        sequence_id TEXT NOT NULL REFERENCES task_sequences(id) ON DELETE CASCADE,
        task_id TEXT NOT NULL UNIQUE REFERENCES tasks(id) ON DELETE CASCADE,
        position INTEGER NOT NULL CHECK(position >= 0),
        PRIMARY KEY(sequence_id, task_id),
        UNIQUE(sequence_id, position)
      )
    ''');
    await customStatement('''
      CREATE TABLE task_dependencies (
        task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        prerequisite_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL,
        PRIMARY KEY(task_id, prerequisite_id),
        CHECK(task_id <> prerequisite_id)
      )
    ''');
    await customStatement(
      'CREATE INDEX task_dependencies_prerequisite ON task_dependencies(prerequisite_id)',
    );
  }

  Future<void> _createEvents() async {
    await customStatement('''
      CREATE TABLE fixed_events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        notes TEXT NOT NULL DEFAULT '',
        starts_at TEXT NOT NULL,
        ends_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(ends_at > starts_at)
      )
    ''');
    await customStatement(
      'CREATE INDEX fixed_events_start ON fixed_events(starts_at)',
    );
  }

  Future<void> _createSessions() async {
    await customStatement('''
      CREATE TABLE work_sessions (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
        starts_at TEXT NOT NULL,
        ends_at TEXT NOT NULL,
        outcome TEXT NOT NULL CHECK(outcome IN ('upcoming','inProgress','completed','partial','missed','skipped')),
        actual_started_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(ends_at > starts_at)
      )
    ''');
    await customStatement(
      'CREATE INDEX work_sessions_start ON work_sessions(starts_at)',
    );
    await customStatement(
      'CREATE INDEX work_sessions_task ON work_sessions(task_id)',
    );
  }

  Future<void> _createScheduling() async {
    await customStatement('''
      CREATE TABLE availability_windows (
        id TEXT PRIMARY KEY,
        weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7),
        start_minute INTEGER NOT NULL CHECK(start_minute BETWEEN 0 AND 1439),
        end_minute INTEGER NOT NULL CHECK(end_minute BETWEEN 1 AND 1440),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(end_minute > start_minute)
      )
    ''');
    await customStatement(
      'CREATE INDEX availability_windows_day ON availability_windows(weekday,start_minute)',
    );
    await customStatement('''
      CREATE TABLE availability_exceptions (
        id TEXT PRIMARY KEY,
        local_date TEXT NOT NULL,
        start_minute INTEGER,
        end_minute INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK((start_minute IS NULL AND end_minute IS NULL) OR
              (start_minute BETWEEN 0 AND 1439 AND end_minute BETWEEN 1 AND 1440 AND end_minute > start_minute))
      )
    ''');
    await customStatement(
      'CREATE INDEX availability_exceptions_date ON availability_exceptions(local_date,start_minute)',
    );
    await customStatement('''
      CREATE TABLE scheduling_operations (
        id TEXT PRIMARY KEY,
        operation_type TEXT NOT NULL,
        source TEXT NOT NULL CHECK(source IN ('manual','smartReschedule')),
        scope TEXT NOT NULL,
        created_at TEXT NOT NULL,
        reverts_operation_id TEXT REFERENCES scheduling_operations(id) ON DELETE SET NULL
      )
    ''');
    await customStatement(
      'CREATE INDEX scheduling_operations_created ON scheduling_operations(created_at DESC)',
    );
    await customStatement('''
      CREATE TABLE scheduling_changes (
        id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL REFERENCES scheduling_operations(id) ON DELETE CASCADE,
        target_kind TEXT NOT NULL CHECK(target_kind IN ('task','session')),
        target_id TEXT NOT NULL,
        before_date TEXT,
        after_date TEXT,
        before_starts_at TEXT,
        before_ends_at TEXT,
        after_starts_at TEXT,
        after_ends_at TEXT,
        before_updated_at TEXT,
        after_updated_at TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX scheduling_changes_operation ON scheduling_changes(operation_id)',
    );
    await customStatement(
      'CREATE INDEX scheduling_changes_target ON scheduling_changes(target_kind,target_id)',
    );
  }
}
