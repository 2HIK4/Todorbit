using System.Globalization;
using Microsoft.Data.Sqlite;

internal sealed record WidgetTask(
  string Id, string Title, string Notes, string Status, int Priority,
  string? CategoryId, string? ProjectId, string? ScheduledDate,
  string? DeadlineDate, string UpdatedAt);
internal sealed record WidgetChoice(string Id, string Name, string? ParentId = null);
internal sealed record WidgetTaskUpdate(
  string Title, string Notes, string Status, int Priority,
  string? CategoryId, string? ProjectId, string? ScheduledDate,
  string? DeadlineDate, string ExpectedUpdatedAt,
  IReadOnlyCollection<string>? ReviewedPrerequisiteIds = null);
internal sealed record WidgetDependencyConflict(string Id, string Title);
internal sealed class DependencyReviewRequiredException(
    IReadOnlyList<WidgetDependencyConflict> conflicts)
    : Exception("The planned day is before unfinished prerequisites.") {
  internal IReadOnlyList<WidgetDependencyConflict> Conflicts { get; } = conflicts;
}

internal sealed class LifeManagerWidgetRepository : IDisposable {
  private const int MinimumSchemaVersion = 4;
  private const int MaximumSchemaVersion = 15;
  private const string ActiveTaskClause = """
     AND deleted_at IS NULL AND archived_at IS NULL
     AND (category_id IS NULL OR EXISTS
       (SELECT 1 FROM categories c WHERE c.id=tasks.category_id AND c.deleted_at IS NULL))
     AND (project_id IS NULL OR EXISTS
       (SELECT 1 FROM projects p WHERE p.id=tasks.project_id AND p.deleted_at IS NULL))
     AND NOT EXISTS (SELECT 1 FROM recurrence_occurrences o
       JOIN recurrence_series s ON s.id=o.series_id
       WHERE o.task_id=tasks.id AND (s.deleted_at IS NOT NULL OR s.archived_at IS NOT NULL))
    """;
  private readonly SqliteConnection connection;
  private int schemaVersion;
  internal string DatabasePath { get; }

  private LifeManagerWidgetRepository(string databasePath) {
    DatabasePath = Path.GetFullPath(databasePath);
    var builder = new SqliteConnectionStringBuilder {
      DataSource = databasePath,
      Mode = SqliteOpenMode.ReadWrite,
      Cache = SqliteCacheMode.Shared,
      Pooling = true,
    };
    connection = new SqliteConnection(builder.ConnectionString);
    connection.Open();
    ExecuteNonQuery("PRAGMA foreign_keys = ON");
    ExecuteNonQuery("PRAGMA busy_timeout = 5000");
    using var versionCommand = connection.CreateCommand();
    versionCommand.CommandText = "PRAGMA user_version";
    var version = Convert.ToInt32(versionCommand.ExecuteScalar(),
      CultureInfo.InvariantCulture);
    schemaVersion = version;
    if (version < MinimumSchemaVersion || version > MaximumSchemaVersion) {
      throw new InvalidOperationException(
        $"The Life Manager database schema is {version}; widget support requires schema {MinimumSchemaVersion}–{MaximumSchemaVersion}. Open the main app to migrate it first.");
    }
  }

  internal static LifeManagerWidgetRepository OpenDefault() {
    var appData = Environment.GetFolderPath(
      Environment.SpecialFolder.ApplicationData);
    var databasePath = Path.Combine(appData, "Life Manager",
      "life_manager.sqlite");
    if (!File.Exists(databasePath)) {
      throw new FileNotFoundException(
        "The Life Manager database does not exist. Open the main app first.",
        databasePath);
    }
    return new LifeManagerWidgetRepository(databasePath);
  }

  internal static LifeManagerWidgetRepository OpenForTest(string databasePath) =>
    new(databasePath);

  // Claim before showing a tray balloon so a restart or a second timer tick
  // cannot repeat it. A notification can be claimed only for the current day.
  internal IReadOnlyList<string> ClaimDailyNotifications(DateTime localNow) {
    RefreshSchemaVersion();
    if (schemaVersion < 14) return [];
    using var settingsCommand = connection.CreateCommand();
    settingsCommand.CommandText = "SELECT due_reminders,daily_summary,local_minute FROM notification_settings WHERE id=1";
    using var settings = settingsCommand.ExecuteReader();
    if (!settings.Read()) return [];
    var dueEnabled = settings.GetInt32(0) == 1;
    var summaryEnabled = settings.GetInt32(1) == 1;
    var minute = settings.GetInt32(2);
    settings.Close();
    if (!dueEnabled && !summaryEnabled) return [];
    var elapsed = (int)localNow.TimeOfDay.TotalMinutes - minute;
    if (elapsed < 0 || elapsed >= 60) return [];
    var day = localNow.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    using var transaction = connection.BeginTransaction();
    var results = new List<string>();
    var due = CountActiveTasks("deadline_date <= $day", day, transaction);
    if (dueEnabled && due > 0 && Claim("due", day, transaction)) {
      results.Add($"{due} open task{(due == 1 ? "" : "s")} due or overdue.");
    }
    if (summaryEnabled && Claim("summary", day, transaction)) {
      var planned = CountActiveTasks("scheduled_date = $day", day, transaction);
      results.Add($"Today: {planned} planned task{(planned == 1 ? "" : "s")}, {due} due or overdue.");
    }
    transaction.Commit();
    return results;
  }

  private void RefreshSchemaVersion() {
    using var command = connection.CreateCommand();
    command.CommandText = "PRAGMA user_version";
    var version = Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture);
    if (version is >= MinimumSchemaVersion and <= MaximumSchemaVersion)
      schemaVersion = version;
  }

  private int CountActiveTasks(string condition, string day,
      SqliteTransaction transaction) {
    using var command = connection.CreateCommand();
    command.Transaction = transaction;
    command.CommandText = "SELECT COUNT(*) FROM tasks WHERE status NOT IN ('completed','cancelled') AND " +
      condition + ActiveTaskClause;
    command.Parameters.AddWithValue("$day", day);
    return Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture);
  }

  private bool Claim(string kind, string day, SqliteTransaction transaction) {
    using var command = connection.CreateCommand();
    command.Transaction = transaction;
    command.CommandText = "INSERT OR IGNORE INTO notification_deliveries(id,kind,local_day,delivered_at) VALUES($id,$kind,$day,$at)";
    command.Parameters.AddWithValue("$id", Guid.NewGuid().ToString());
    command.Parameters.AddWithValue("$kind", kind);
    command.Parameters.AddWithValue("$day", day);
    command.Parameters.AddWithValue("$at", UtcNowString());
    return command.ExecuteNonQuery() == 1;
  }

  internal IReadOnlyList<WidgetTask> LoadTasks(
      DateTime localToday, WidgetTaskView view = WidgetTaskView.Today) {
    using var command = connection.CreateCommand();
    command.CommandText = """
      SELECT id, title, notes, status, priority, category_id, project_id,
        scheduled_date, deadline_date, updated_at
      FROM tasks
      WHERE status NOT IN ('completed', 'cancelled')
      """ + (schemaVersion >= 13 ? ActiveTaskClause : "") + """
        AND (($view = 'today' AND scheduled_date = $today) OR
          ($view = 'inbox' AND category_id IS NULL AND project_id IS NULL) OR
          ($view = 'all') OR
          ($view = 'upcoming' AND scheduled_date > $today))
      ORDER BY priority DESC, scheduled_date ASC, created_at DESC
      LIMIT 20
      """;
    command.Parameters.AddWithValue("$today",
      localToday.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
    command.Parameters.AddWithValue("$view",
      view.ToString().ToLowerInvariant());
    using var reader = command.ExecuteReader();
    var tasks = new List<WidgetTask>();
    while (reader.Read()) {
      tasks.Add(ReadTask(reader));
    }
    return tasks;
  }

  internal WidgetTask? LoadTask(string id) {
    using var command = connection.CreateCommand();
    command.CommandText = """
      SELECT id, title, notes, status, priority, category_id, project_id,
        scheduled_date, deadline_date, updated_at
      FROM tasks WHERE id=$id
      """ + (schemaVersion >= 13 ? ActiveTaskClause : "");
    command.Parameters.AddWithValue("$id", id);
    using var reader = command.ExecuteReader();
    return reader.Read() ? ReadTask(reader) : null;
  }

  internal IReadOnlyList<WidgetChoice> LoadCategories() => LoadChoices(
    "SELECT id, name, NULL FROM categories " +
    (schemaVersion >= 13 ? "WHERE deleted_at IS NULL " : "") +
    "ORDER BY name COLLATE NOCASE");

  internal IReadOnlyList<WidgetChoice> LoadProjects() => LoadChoices(
    "SELECT id, name, category_id FROM projects " +
    (schemaVersion >= 13 ? "WHERE deleted_at IS NULL AND EXISTS " +
      "(SELECT 1 FROM categories c WHERE c.id=projects.category_id AND c.deleted_at IS NULL) " : "") +
    "ORDER BY name COLLATE NOCASE");

  internal string AddTask(string title, DateTime localToday,
      WidgetTaskView view = WidgetTaskView.Today) {
    var cleaned = title.Trim();
    if (cleaned.Length == 0) {
      throw new ArgumentException("Task title is required.", nameof(title));
    }
    var id = Guid.NewGuid().ToString();
    var now = UtcNowString();
    using var transaction = connection.BeginTransaction();
    using var command = connection.CreateCommand();
    command.Transaction = transaction;
    command.CommandText = """
      INSERT INTO tasks(
        id,title,notes,status,priority,category_id,project_id,
        scheduled_date,deadline_date,created_at,updated_at,completed_at)
      VALUES($id,$title,'','notStarted',0,NULL,NULL,$scheduled,NULL,$now,$now,NULL)
      """;
    command.Parameters.AddWithValue("$id", id);
    command.Parameters.AddWithValue("$title", cleaned);
    var scheduled = view switch {
      WidgetTaskView.Today => localToday,
      WidgetTaskView.Upcoming => localToday.AddDays(1),
      _ => (DateTime?)null,
    };
    command.Parameters.AddWithValue("$scheduled", scheduled is null
      ? DBNull.Value
      : scheduled.Value.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
    command.Parameters.AddWithValue("$now", now);
    command.ExecuteNonQuery();
    transaction.Commit();
    return id;
  }

  internal void UpdateTask(string id, WidgetTaskUpdate update) {
    var title = update.Title.Trim();
    if (title.Length == 0) throw new ArgumentException("Task title is required.");
    if (update.Priority is < 0 or > 3) {
      throw new ArgumentOutOfRangeException(nameof(update.Priority));
    }
    var validStatuses = new HashSet<string>(StringComparer.Ordinal) {
      "notStarted", "inProgress", "waiting", "onHold", "completed", "cancelled",
    };
    if (!validStatuses.Contains(update.Status)) {
      throw new ArgumentException("Unsupported task status.");
    }
    var now = UtcNowString();
    var completedAt = update.Status == "completed" ? now : null;
    using var transaction = connection.BeginTransaction();
    string? previousScheduledDate = null;
    string? previousStatus = null;
    using (var previousCommand = connection.CreateCommand()) {
      previousCommand.Transaction = transaction;
      previousCommand.CommandText =
        "SELECT scheduled_date,status,completed_at FROM tasks WHERE id=$id AND updated_at=$expected" +
        (schemaVersion >= 13 ? ActiveTaskClause : "");
      previousCommand.Parameters.AddWithValue("$id", id);
      previousCommand.Parameters.AddWithValue("$expected", update.ExpectedUpdatedAt);
      using var reader = previousCommand.ExecuteReader();
      if (reader.Read()) {
        previousScheduledDate = reader.IsDBNull(0) ? null : reader.GetString(0);
        previousStatus = reader.GetString(1);
        if (previousStatus == "completed" && update.Status == "completed" &&
            !reader.IsDBNull(2)) completedAt = reader.GetString(2);
      }
    }
    if (schemaVersion >= 6 && previousStatus == "completed" &&
        update.Status != "completed") CheckRecurringReopen(id, transaction);
    using var command = connection.CreateCommand();
    command.Transaction = transaction;
    if (schemaVersion >= 5 && update.ScheduledDate != null &&
        !String.Equals(previousScheduledDate, update.ScheduledDate,
          StringComparison.Ordinal)) {
      var unreviewed = new List<WidgetDependencyConflict>();
      using var prerequisites = connection.CreateCommand();
      prerequisites.Transaction = transaction;
      prerequisites.CommandText = """
        SELECT p.id,p.title,p.status,p.scheduled_date
        FROM task_dependencies d JOIN tasks p ON p.id=d.prerequisite_id
        WHERE d.task_id=$id
        """;
      prerequisites.Parameters.AddWithValue("$id", id);
      using var reader = prerequisites.ExecuteReader();
      while (reader.Read()) {
        var prerequisiteId = reader.GetString(0);
        var plannedDay = reader.IsDBNull(3) ? null : reader.GetString(3);
        if (reader.GetString(2) == "completed" ||
            (plannedDay != null &&
              String.CompareOrdinal(update.ScheduledDate, plannedDay) > 0)) {
          continue;
        }
        if (update.ReviewedPrerequisiteIds?.Contains(prerequisiteId) != true) {
          unreviewed.Add(new WidgetDependencyConflict(
            prerequisiteId, reader.GetString(1)));
        }
      }
      if (unreviewed.Count != 0) {
        throw new DependencyReviewRequiredException(unreviewed);
      }
    }
    command.CommandText = """
      UPDATE tasks SET title=$title,notes=$notes,status=$status,priority=$priority,
        category_id=$category,project_id=$project,scheduled_date=$scheduled,
        deadline_date=$deadline,updated_at=$now,completed_at=$completed
      WHERE id=$id AND updated_at=$expected
      """ + (schemaVersion >= 13 ? ActiveTaskClause : "");
    command.Parameters.AddWithValue("$title", title);
    command.Parameters.AddWithValue("$notes", update.Notes.Trim());
    command.Parameters.AddWithValue("$status", update.Status);
    command.Parameters.AddWithValue("$priority", update.Priority);
    command.Parameters.AddWithValue("$category", DbValue(update.CategoryId));
    command.Parameters.AddWithValue("$project", DbValue(update.ProjectId));
    command.Parameters.AddWithValue("$scheduled", DbValue(update.ScheduledDate));
    command.Parameters.AddWithValue("$deadline", DbValue(update.DeadlineDate));
    command.Parameters.AddWithValue("$now", now);
    command.Parameters.AddWithValue("$completed", DbValue(completedAt));
    command.Parameters.AddWithValue("$id", id);
    command.Parameters.AddWithValue("$expected", update.ExpectedUpdatedAt);
    if (command.ExecuteNonQuery() != 1) {
      throw new InvalidOperationException(
        "This task changed in another window or no longer exists. Reopen it before saving.");
    }
    if (!String.Equals(previousScheduledDate, update.ScheduledDate,
        StringComparison.Ordinal)) {
      var operationId = Guid.NewGuid().ToString();
      using var operation = connection.CreateCommand();
      operation.Transaction = transaction;
      operation.CommandText = """
        INSERT INTO scheduling_operations(
          id,operation_type,source,scope,created_at,reverts_operation_id)
        VALUES($id,'move','manual',$scope,$now,NULL)
        """;
      operation.Parameters.AddWithValue("$id", operationId);
      operation.Parameters.AddWithValue("$scope", $"widget:task:{id}");
      operation.Parameters.AddWithValue("$now", now);
      operation.ExecuteNonQuery();
      using var change = connection.CreateCommand();
      change.Transaction = transaction;
      change.CommandText = """
        INSERT INTO scheduling_changes(
          id,operation_id,target_kind,target_id,before_date,after_date,
          before_starts_at,before_ends_at,after_starts_at,after_ends_at,
          before_updated_at,after_updated_at)
        VALUES($id,$operation,'task',$target,$before,$after,
          NULL,NULL,NULL,NULL,$beforeUpdated,$afterUpdated)
        """;
      change.Parameters.AddWithValue("$id", Guid.NewGuid().ToString());
      change.Parameters.AddWithValue("$operation", operationId);
      change.Parameters.AddWithValue("$target", id);
      change.Parameters.AddWithValue("$before", DbValue(previousScheduledDate));
      change.Parameters.AddWithValue("$after", DbValue(update.ScheduledDate));
      change.Parameters.AddWithValue("$beforeUpdated", update.ExpectedUpdatedAt);
      change.Parameters.AddWithValue("$afterUpdated", now);
      change.ExecuteNonQuery();
    }
    if (schemaVersion >= 6 && previousStatus != "completed" &&
        update.Status == "completed") {
      AdvanceCompletionSeries(id, now, transaction);
    }
    transaction.Commit();
  }

  internal void CompleteTask(string id) {
    var now = UtcNowString();
    using var transaction = connection.BeginTransaction();
    using var command = connection.CreateCommand();
    command.Transaction = transaction;
    command.CommandText = """
      UPDATE tasks
      SET status='completed', completed_at=$now, updated_at=$now
      WHERE id=$id AND status NOT IN ('completed', 'cancelled')
      """ + (schemaVersion >= 13 ? ActiveTaskClause : "");
    command.Parameters.AddWithValue("$now", now);
    command.Parameters.AddWithValue("$id", id);
    if (command.ExecuteNonQuery() != 1) {
      throw new InvalidOperationException(
        "The task was already changed or no longer exists.");
    }
    if (schemaVersion >= 6) AdvanceCompletionSeries(id, now, transaction);
    transaction.Commit();
  }

  private void CheckRecurringReopen(string id, SqliteTransaction transaction) {
    using var command = connection.CreateCommand();
    command.Transaction = transaction;
    command.CommandText = schemaVersion >= 7 ? """
      SELECT 1 FROM recurrence_occurrences current
      JOIN recurrence_series s ON s.id=current.series_id
      JOIN recurrence_series later_s ON later_s.family_id=s.family_id
      JOIN recurrence_occurrences later ON later.series_id=later_s.id
      WHERE current.task_id=$id AND s.kind='afterCompletion'
        AND (later_s.created_at>s.created_at OR
          (later_s.id=s.id AND later.ordinal>current.ordinal)) LIMIT 1
      """ : """
      SELECT 1 FROM recurrence_occurrences current
      JOIN recurrence_series s ON s.id=current.series_id
      JOIN recurrence_occurrences later ON later.series_id=s.id
      WHERE current.task_id=$id AND s.kind='afterCompletion'
        AND later.ordinal>current.ordinal LIMIT 1
      """;
    command.Parameters.AddWithValue("$id", id);
    if (command.ExecuteScalar() != null) {
      throw new InvalidOperationException(
        "A later occurrence already exists. Resolve it before reopening this task.");
    }
  }

  private void AdvanceCompletionSeries(
      string id, string now, SqliteTransaction transaction) {
    string seriesId, title, notes, nextDate;
    string? categoryId, projectId, deadlineDate, endDate, activeThrough;
    int ordinal, interval, priority;
    int? maxOccurrences, deadlineOffset, plannedMinutes, remainingMinutes;
    bool locked;
    using (var command = connection.CreateCommand()) {
      command.Transaction = transaction;
      command.CommandText = """
        SELECT s.id,o.ordinal,s.interval,s.end_date,s.max_occurrences,
          s.title,s.notes,s.priority,s.category_id,s.project_id,
          s.deadline_offset_days,s.planned_duration_minutes,
          s.remaining_work_minutes,s.scheduling_locked
        """ + (schemaVersion >= 7 ? ",s.active_through_date " : " ") + """
        FROM recurrence_occurrences o JOIN recurrence_series s ON s.id=o.series_id
        WHERE o.task_id=$id AND s.kind='afterCompletion'
        """;
      command.Parameters.AddWithValue("$id", id);
      using var reader = command.ExecuteReader();
      if (!reader.Read()) return;
      seriesId = reader.GetString(0);
      ordinal = reader.GetInt32(1) + 1;
      interval = reader.GetInt32(2);
      endDate = reader.IsDBNull(3) ? null : reader.GetString(3);
      maxOccurrences = reader.IsDBNull(4) ? null : reader.GetInt32(4);
      title = reader.GetString(5);
      notes = reader.GetString(6);
      priority = reader.GetInt32(7);
      categoryId = reader.IsDBNull(8) ? null : reader.GetString(8);
      projectId = reader.IsDBNull(9) ? null : reader.GetString(9);
      deadlineOffset = reader.IsDBNull(10) ? null : reader.GetInt32(10);
      plannedMinutes = reader.IsDBNull(11) ? null : reader.GetInt32(11);
      remainingMinutes = reader.IsDBNull(12) ? null : reader.GetInt32(12);
      locked = reader.GetInt32(13) == 1;
      activeThrough = schemaVersion >= 7 && !reader.IsDBNull(14)
        ? reader.GetString(14) : null;
    }
    if (maxOccurrences != null && ordinal >= maxOccurrences) return;
    var nextDay = DateTime.Now.Date.AddDays(interval);
    nextDate = nextDay.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    if (endDate != null &&
        String.CompareOrdinal(nextDate, endDate) > 0) return;
    if (activeThrough != null &&
        String.CompareOrdinal(nextDate, activeThrough) > 0) return;
    deadlineDate = deadlineOffset == null ? null :
      nextDay.AddDays(deadlineOffset.Value)
        .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    using (var existing = connection.CreateCommand()) {
      existing.Transaction = transaction;
      existing.CommandText = """
        SELECT 1 FROM recurrence_occurrences
        WHERE series_id=$series AND ordinal=$ordinal LIMIT 1
        """;
      existing.Parameters.AddWithValue("$series", seriesId);
      existing.Parameters.AddWithValue("$ordinal", ordinal);
      if (existing.ExecuteScalar() != null) return;
    }
    var taskId = Guid.NewGuid().ToString();
    using (var task = connection.CreateCommand()) {
      task.Transaction = transaction;
      task.CommandText = """
        INSERT INTO tasks(id,title,notes,status,priority,category_id,
          project_id,scheduled_date,deadline_date,created_at,updated_at,
          completed_at,planned_duration_minutes,remaining_work_minutes,
          scheduling_locked)
        VALUES($id,$title,$notes,'notStarted',$priority,$category,$project,
          $scheduled,$deadline,$now,$now,NULL,$planned,$remaining,$locked)
        """;
      task.Parameters.AddWithValue("$id", taskId);
      task.Parameters.AddWithValue("$title", title);
      task.Parameters.AddWithValue("$notes", notes);
      task.Parameters.AddWithValue("$priority", priority);
      task.Parameters.AddWithValue("$category", DbValue(categoryId));
      task.Parameters.AddWithValue("$project", DbValue(projectId));
      task.Parameters.AddWithValue("$scheduled", nextDate);
      task.Parameters.AddWithValue("$deadline", DbValue(deadlineDate));
      task.Parameters.AddWithValue("$now", now);
      task.Parameters.AddWithValue("$planned", (object?)plannedMinutes ?? DBNull.Value);
      task.Parameters.AddWithValue("$remaining", (object?)remainingMinutes ?? DBNull.Value);
      task.Parameters.AddWithValue("$locked", locked ? 1 : 0);
      task.ExecuteNonQuery();
    }
    using var occurrence = connection.CreateCommand();
    occurrence.Transaction = transaction;
    occurrence.CommandText = """
      INSERT INTO recurrence_occurrences(
        id,series_id,ordinal,nominal_date,task_id,created_at,updated_at)
      VALUES($id,$series,$ordinal,$date,$task,$now,$now)
      """;
    occurrence.Parameters.AddWithValue("$id", Guid.NewGuid().ToString());
    occurrence.Parameters.AddWithValue("$series", seriesId);
    occurrence.Parameters.AddWithValue("$ordinal", ordinal);
    occurrence.Parameters.AddWithValue("$date", nextDate);
    occurrence.Parameters.AddWithValue("$task", taskId);
    occurrence.Parameters.AddWithValue("$now", now);
    occurrence.ExecuteNonQuery();
  }

  private IReadOnlyList<WidgetChoice> LoadChoices(string sql) {
    using var command = connection.CreateCommand();
    command.CommandText = sql;
    using var reader = command.ExecuteReader();
    var values = new List<WidgetChoice>();
    while (reader.Read()) values.Add(new WidgetChoice(
      reader.GetString(0), reader.GetString(1),
      reader.IsDBNull(2) ? null : reader.GetString(2)));
    return values;
  }

  private static WidgetTask ReadTask(SqliteDataReader reader) => new(
    reader.GetString(0), reader.GetString(1), reader.GetString(2),
    reader.GetString(3), reader.GetInt32(4),
    reader.IsDBNull(5) ? null : reader.GetString(5),
    reader.IsDBNull(6) ? null : reader.GetString(6),
    reader.IsDBNull(7) ? null : reader.GetString(7),
    reader.IsDBNull(8) ? null : reader.GetString(8), reader.GetString(9));

  private static object DbValue(string? value) =>
    string.IsNullOrWhiteSpace(value) ? DBNull.Value : value;

  private void ExecuteNonQuery(string sql) {
    using var command = connection.CreateCommand();
    command.CommandText = sql;
    command.ExecuteNonQuery();
  }

  private static string UtcNowString() => DateTime.UtcNow.ToString(
    "yyyy-MM-dd'T'HH:mm:ss.ffffff'Z'", CultureInfo.InvariantCulture);

  public void Dispose() => connection.Dispose();
}
