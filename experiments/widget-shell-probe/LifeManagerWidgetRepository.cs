using System.Globalization;
using Microsoft.Data.Sqlite;

internal sealed record WidgetTask(string Id, string Title);

internal sealed class LifeManagerWidgetRepository : IDisposable {
  private const int SupportedSchemaVersion = 3;
  private readonly SqliteConnection connection;

  private LifeManagerWidgetRepository(string databasePath) {
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
    if (version != SupportedSchemaVersion) {
      throw new InvalidOperationException(
        $"The Life Manager database schema is {version}; widget support requires schema {SupportedSchemaVersion}. Open the main app to migrate it first.");
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

  internal IReadOnlyList<WidgetTask> LoadTasks(DateTime localToday) {
    using var command = connection.CreateCommand();
    command.CommandText = """
      SELECT id, title
      FROM tasks
      WHERE status NOT IN ('completed', 'cancelled')
        AND (scheduled_date = $today OR
          (category_id IS NULL AND project_id IS NULL))
      ORDER BY priority DESC, scheduled_date ASC, created_at DESC
      LIMIT 20
      """;
    command.Parameters.AddWithValue("$today",
      localToday.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
    using var reader = command.ExecuteReader();
    var tasks = new List<WidgetTask>();
    while (reader.Read()) {
      tasks.Add(new WidgetTask(reader.GetString(0), reader.GetString(1)));
    }
    return tasks;
  }

  internal string AddTask(string title, DateTime localToday) {
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
    command.Parameters.AddWithValue("$scheduled",
      localToday.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture));
    command.Parameters.AddWithValue("$now", now);
    command.ExecuteNonQuery();
    transaction.Commit();
    return id;
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

  private void ExecuteNonQuery(string sql) {
    using var command = connection.CreateCommand();
    command.CommandText = sql;
    command.ExecuteNonQuery();
  }

  private static string UtcNowString() => DateTime.UtcNow.ToString(
    "yyyy-MM-dd'T'HH:mm:ss.ffffff'Z'", CultureInfo.InvariantCulture);

  public void Dispose() => connection.Dispose();
}
