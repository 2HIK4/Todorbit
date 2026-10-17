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
  private const int MaximumSchemaVersion = 5;
  private readonly SqliteConnection connection;
  private readonly int schemaVersion;
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

  internal IReadOnlyList<WidgetTask> LoadTasks(
      DateTime localToday, WidgetTaskView view = WidgetTaskView.Today) {
    using var command = connection.CreateCommand();
    command.CommandText = """
      SELECT id, title, notes, status, priority, category_id, project_id,
        scheduled_date, deadline_date, updated_at
      FROM tasks
      WHERE status NOT IN ('completed', 'cancelled')
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
      """;
    command.Parameters.AddWithValue("$id", id);
    using var reader = command.ExecuteReader();
    return reader.Read() ? ReadTask(reader) : null;
  }

  internal IReadOnlyList<WidgetChoice> LoadCategories() => LoadChoices(
    "SELECT id, name, NULL FROM categories ORDER BY name COLLATE NOCASE");

  internal IReadOnlyList<WidgetChoice> LoadProjects() => LoadChoices(
    "SELECT id, name, category_id FROM projects ORDER BY name COLLATE NOCASE");

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
    using (var previousCommand = connection.CreateCommand()) {
      previousCommand.Transaction = transaction;
      previousCommand.CommandText =
        "SELECT scheduled_date FROM tasks WHERE id=$id AND updated_at=$expected";
      previousCommand.Parameters.AddWithValue("$id", id);
      previousCommand.Parameters.AddWithValue("$expected", update.ExpectedUpdatedAt);
      var value = previousCommand.ExecuteScalar();
      previousScheduledDate = value is null or DBNull ? null : (string)value;
    }
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
      """;
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
      """;
    command.Parameters.AddWithValue("$now", now);
    command.Parameters.AddWithValue("$id", id);
    if (command.ExecuteNonQuery() != 1) {
      throw new InvalidOperationException(
        "The task was already changed or no longer exists.");
    }
    transaction.Commit();
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
