using Microsoft.Data.Sqlite;

internal static class LifeManagerWidgetSelfTest {
  internal static void Run() {
    var directory = Path.Combine(Path.GetTempPath(),
      $"life-manager-widget-test-{Guid.NewGuid()}");
    Directory.CreateDirectory(directory);
    var databasePath = Path.Combine(directory, "test.sqlite");
    try {
      CreateDatabase(databasePath);
      string id;
      using (var repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        var today = new DateTime(2026, 10, 17);
        id = repository.AddTask("Persistence test", today);
        if (!Guid.TryParse(id, out _)) {
          throw new InvalidOperationException("Task ID is not a stable UUID.");
        }
        var tasks = repository.LoadTasks(today);
        if (tasks.Count != 1 || tasks[0].Id != id ||
            tasks[0].Title != "Persistence test") {
          throw new InvalidOperationException("Created task was not reloaded.");
        }
        repository.CompleteTask(id);
        if (repository.LoadTasks(today).Count != 0) {
          throw new InvalidOperationException("Completed task remained visible.");
        }
      }
      using (var verification = new SqliteConnection(
          $"Data Source={databasePath};Mode=ReadOnly;Pooling=False")) {
        verification.Open();
        using var command = verification.CreateCommand();
        command.CommandText =
          "SELECT status, completed_at FROM tasks WHERE id=$id";
        command.Parameters.AddWithValue("$id", id);
        using var reader = command.ExecuteReader();
        if (!reader.Read() || reader.GetString(0) != "completed" ||
            reader.IsDBNull(1)) {
          throw new InvalidOperationException(
            "Completion was not persisted correctly.");
        }
      }
    } finally {
      SqliteConnection.ClearAllPools();
      if (Directory.Exists(directory)) Directory.Delete(directory, true);
    }
  }

  private static void CreateDatabase(string path) {
    using var connection = new SqliteConnection($"Data Source={path}");
    connection.Open();
    using var command = connection.CreateCommand();
    command.CommandText = """
      PRAGMA user_version = 3;
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 0,
        category_id TEXT,
        project_id TEXT,
        scheduled_date TEXT,
        deadline_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT
      );
      """;
    command.ExecuteNonQuery();
  }
}
