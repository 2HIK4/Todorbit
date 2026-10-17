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
      VerifySettingsRoundTrip(directory);
      VerifySingleInstanceMutex();
      VerifyCommandPipe();
      VerifyExplorerRecoveryPolicy();
    } finally {
      SqliteConnection.ClearAllPools();
      if (Directory.Exists(directory)) Directory.Delete(directory, true);
    }
  }

  private static void VerifySettingsRoundTrip(string directory) {
    var path = Path.Combine(directory, "settings.json");
    var store = new WidgetSettingsStore(path);
    var expected = new WidgetSettings {
      X = -1200,
      Y = 80,
      Width = 444,
      Height = 612,
      MonitorDeviceName = @"\\.\DISPLAY2",
      Theme = WidgetThemePreference.Light,
      View = WidgetTaskView.Inbox,
    };
    store.Save(expected);
    var actual = store.Load();
    if (actual.X != expected.X || actual.Width != expected.Width ||
        actual.Theme != expected.Theme || actual.View != expected.View ||
        actual.MonitorDeviceName != expected.MonitorDeviceName) {
      throw new InvalidOperationException("Widget settings did not round-trip.");
    }
  }

  private static void VerifySingleInstanceMutex() {
    var name = $"Local\\LifeManagerWidgetSelfTest-{Guid.NewGuid()}";
    using var first = new Mutex(true, name, out var firstOwns);
    var secondOwns = Task.Run(() => {
      using var second = new Mutex(true, name, out var owns);
      if (owns) second.ReleaseMutex();
      return owns;
    }).GetAwaiter().GetResult();
    if (!firstOwns || secondOwns) {
      throw new InvalidOperationException("Single-instance mutex admitted a duplicate.");
    }
    first.ReleaseMutex();
  }

  private static void VerifyCommandPipe() {
    SynchronizationContext.SetSynchronizationContext(new SynchronizationContext());
    var pipe = $"LifeManager.Widget.SelfTest.{Guid.NewGuid()}";
    using var received = new ManualResetEventSlim();
    string? actual = null;
    using var server = new WidgetCommandServer(command => {
      actual = command;
      received.Set();
    }, pipe);
    if (!WidgetCommandServer.TrySend("refresh", 2000, pipe) ||
        !received.Wait(TimeSpan.FromSeconds(2)) || actual != "refresh") {
      throw new InvalidOperationException("Widget command pipe did not synchronize.");
    }
  }

  private static void VerifyExplorerRecoveryPolicy() {
    var policy = new ExplorerRecoveryPolicy(maximumAttempts: 3);
    for (var index = 0; index < 3; index++) {
      if (!policy.CanRetry) {
        throw new InvalidOperationException("Explorer recovery stopped too early.");
      }
      policy.RecordFailure();
    }
    if (policy.CanRetry) {
      throw new InvalidOperationException("Explorer recovery is not bounded.");
    }
    policy.Reset();
    if (!policy.CanRetry || policy.Attempts != 0) {
      throw new InvalidOperationException("Explorer recovery did not reset after success.");
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
