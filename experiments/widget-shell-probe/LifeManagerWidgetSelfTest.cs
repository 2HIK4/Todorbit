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
        var original = tasks[0];
        var categories = repository.LoadCategories();
        var projects = repository.LoadProjects();
        if (categories.Count != 1 || projects.Count != 1 ||
            projects[0].ParentId != categories[0].Id) {
          throw new InvalidOperationException("Task editor choices did not load.");
        }
        repository.UpdateTask(id, new WidgetTaskUpdate(
          "Edited title", "Widget notes", "inProgress", 3,
          categories[0].Id, projects[0].Id, "2026-10-18", "2026-10-20",
          original.UpdatedAt));
        var edited = repository.LoadTask(id);
        if (edited == null || edited.Title != "Edited title" ||
            edited.Notes != "Widget notes" || edited.Status != "inProgress" ||
            edited.Priority != 3 || edited.DeadlineDate != "2026-10-20" ||
            edited.CategoryId != categories[0].Id ||
            edited.ProjectId != projects[0].Id) {
          throw new InvalidOperationException("Task editing was not persisted.");
        }
        try {
          repository.UpdateTask(id, new WidgetTaskUpdate(
            "Lost update", "", "notStarted", 0, null, null,
            null, null, original.UpdatedAt));
          throw new InvalidOperationException("A stale edit silently overwrote a task.");
        } catch (InvalidOperationException error)
            when (error.Message.StartsWith("This task changed")) { }
        var inboxId = repository.AddTask("Inbox task", today, WidgetTaskView.Inbox);
        if (repository.LoadTasks(today, WidgetTaskView.Inbox)
            .All(item => item.Id != inboxId)) {
          throw new InvalidOperationException("Inbox Quick Add semantics failed.");
        }
        var upcomingId = repository.AddTask(
          "Upcoming task", today, WidgetTaskView.Upcoming);
        if (repository.LoadTasks(today, WidgetTaskView.Upcoming)
            .All(item => item.Id != upcomingId)) {
          throw new InvalidOperationException("Upcoming view filtering failed.");
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
        reader.Close();
        using var history = verification.CreateCommand();
        history.CommandText =
          "SELECT COUNT(*) FROM scheduling_operations WHERE source='manual'";
        if (Convert.ToInt32(history.ExecuteScalar()) != 1) {
          throw new InvalidOperationException(
            "Widget scheduling edit was not added to schedule history.");
        }
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = """
          PRAGMA user_version = 5;
          CREATE TABLE task_dependencies(
            task_id TEXT NOT NULL,
            prerequisite_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY(task_id,prerequisite_id)
          );
          """;
        command.ExecuteNonQuery();
      }
      using (var upgradedRepository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        if (upgradedRepository.LoadTask(id)?.Status != "completed") {
          throw new InvalidOperationException(
            "Widget could not read a schema v5 task.");
        }
        var blockerId = upgradedRepository.AddTask(
          "Prerequisite", new DateTime(2026, 10, 25));
        var dependentId = upgradedRepository.AddTask(
          "Dependent", new DateTime(2026, 10, 17));
        using (var link = new SqliteConnection(
            $"Data Source={databasePath};Pooling=False")) {
          link.Open();
          using var command = link.CreateCommand();
          command.CommandText = """
            INSERT INTO task_dependencies(task_id,prerequisite_id,created_at)
            VALUES($task,$prerequisite,'2026-10-17T00:00:00Z')
            """;
          command.Parameters.AddWithValue("$task", dependentId);
          command.Parameters.AddWithValue("$prerequisite", blockerId);
          command.ExecuteNonQuery();
        }
        var dependent = upgradedRepository.LoadTask(dependentId)!;
        var update = new WidgetTaskUpdate("Dependent", "", "notStarted", 0,
          null, null, "2026-10-20", null, dependent.UpdatedAt);
        try {
          upgradedRepository.UpdateTask(dependentId, update);
          throw new InvalidOperationException(
            "Unreviewed prerequisite conflict was accepted.");
        } catch (DependencyReviewRequiredException conflict)
            when (conflict.Conflicts.Single().Id == blockerId) { }
        upgradedRepository.UpdateTask(dependentId, update with {
          ReviewedPrerequisiteIds = [blockerId],
        });
        if (upgradedRepository.LoadTask(dependentId)?.ScheduledDate !=
            "2026-10-20") {
          throw new InvalidOperationException(
            "Reviewed prerequisite override was not saved.");
        }
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = """
          CREATE TABLE recurrence_series(
            id TEXT PRIMARY KEY, kind TEXT NOT NULL, start_date TEXT NOT NULL,
            interval INTEGER NOT NULL, weekdays TEXT NOT NULL, end_date TEXT,
            max_occurrences INTEGER, title TEXT NOT NULL, notes TEXT NOT NULL,
            priority INTEGER NOT NULL, category_id TEXT, project_id TEXT,
            deadline_offset_days INTEGER, planned_duration_minutes INTEGER,
            remaining_work_minutes INTEGER, scheduling_locked INTEGER NOT NULL,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          );
          CREATE TABLE recurrence_occurrences(
            id TEXT PRIMARY KEY, series_id TEXT NOT NULL, ordinal INTEGER NOT NULL,
            nominal_date TEXT NOT NULL, task_id TEXT UNIQUE,
            disposition TEXT NOT NULL DEFAULT 'active',
            is_edited INTEGER NOT NULL DEFAULT 0,
            is_rescheduled INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
            UNIQUE(series_id,ordinal)
          );
          PRAGMA user_version = 6;
          """;
        command.ExecuteNonQuery();
      }
      using (var v6Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        var today = DateTime.Now.Date;
        var recurringId = v6Repository.AddTask("Every three days", today);
        using (var link = new SqliteConnection(
            $"Data Source={databasePath};Pooling=False")) {
          link.Open();
          using var command = link.CreateCommand();
          command.CommandText = """
            INSERT INTO recurrence_series(
              id,kind,start_date,interval,weekdays,end_date,max_occurrences,
              title,notes,priority,category_id,project_id,deadline_offset_days,
              planned_duration_minutes,remaining_work_minutes,scheduling_locked,
              created_at,updated_at)
            VALUES('series','afterCompletion',$today,3,'',NULL,3,
              'Every three days','',0,NULL,NULL,NULL,NULL,NULL,0,$now,$now);
            INSERT INTO recurrence_occurrences(
              id,series_id,ordinal,nominal_date,task_id,created_at,updated_at)
            VALUES('first','series',0,$today,$task,$now,$now);
            """;
          command.Parameters.AddWithValue("$today",
            today.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture));
          command.Parameters.AddWithValue("$task", recurringId);
          command.Parameters.AddWithValue("$now", DateTime.UtcNow.ToString("O"));
          command.ExecuteNonQuery();
        }
        v6Repository.CompleteTask(recurringId);
        string completedBefore, completedAfter;
        using (var check = new SqliteConnection(
            $"Data Source={databasePath};Mode=ReadOnly;Pooling=False")) {
          check.Open();
          using var command = check.CreateCommand();
          command.CommandText =
            "SELECT completed_at FROM tasks WHERE id=$id";
          command.Parameters.AddWithValue("$id", recurringId);
          completedBefore = (string)command.ExecuteScalar()!;
        }
        var completedTask = v6Repository.LoadTask(recurringId)!;
        v6Repository.UpdateTask(recurringId, new WidgetTaskUpdate(
          completedTask.Title, "Updated note", "completed",
          completedTask.Priority, completedTask.CategoryId,
          completedTask.ProjectId, completedTask.ScheduledDate,
          completedTask.DeadlineDate, completedTask.UpdatedAt));
        using (var check = new SqliteConnection(
            $"Data Source={databasePath};Mode=ReadOnly;Pooling=False")) {
          check.Open();
          using var command = check.CreateCommand();
          command.CommandText =
            "SELECT completed_at FROM tasks WHERE id=$id";
          command.Parameters.AddWithValue("$id", recurringId);
          completedAfter = (string)command.ExecuteScalar()!;
        }
        if (completedAfter != completedBefore) {
          throw new InvalidOperationException(
            "Editing a completed occurrence changed its completion time.");
        }
        var nextDay = today.AddDays(3);
        var next = v6Repository.LoadTasks(nextDay)
          .Where(task => task.Title == "Every three days").ToList();
        if (next.Count != 1 ||
            next[0].ScheduledDate != nextDay.ToString("yyyy-MM-dd",
              System.Globalization.CultureInfo.InvariantCulture)) {
          throw new InvalidOperationException(
            "Schema v6 completion did not create the next occurrence.");
        }
        v6Repository.UpdateTask(next[0].Id, new WidgetTaskUpdate(
          next[0].Title, next[0].Notes, "completed", next[0].Priority,
          next[0].CategoryId, next[0].ProjectId, next[0].ScheduledDate,
          next[0].DeadlineDate, next[0].UpdatedAt));
        var third = v6Repository.LoadTasks(nextDay)
          .Where(task => task.Title == "Every three days").ToList();
        if (third.Count != 1 || third[0].Id == next[0].Id) {
          throw new InvalidOperationException(
            "Schema v6 editor completion did not advance the series.");
        }
        v6Repository.CompleteTask(third[0].Id);
        if (v6Repository.LoadTasks(nextDay)
            .Any(task => task.Title == "Every three days")) {
          throw new InvalidOperationException(
            "Schema v6 completion exceeded the series count limit.");
        }
      }
      VerifySettingsRoundTrip(directory);
      VerifyAppearanceRoundTrip(directory);
      VerifySingleInstanceMutex();
      VerifyCommandPipe();
      VerifyExplorerRecoveryPolicy();
      VerifyGeometry();
    } finally {
      SqliteConnection.ClearAllPools();
      if (Directory.Exists(directory)) Directory.Delete(directory, true);
    }
  }

  private static void VerifyAppearanceRoundTrip(string directory) {
    var path = Path.Combine(directory, "appearance.json");
    var store = new AppearanceSettingsStore(path);
    var settings = store.Load(WidgetThemePreference.Dark);
    if (settings.Theme != WidgetThemePreference.Dark) {
      throw new InvalidOperationException("Legacy appearance was not migrated.");
    }
    settings.Theme = WidgetThemePreference.Light;
    store.Save(settings);
    if (store.Load().Theme != WidgetThemePreference.Light) {
      throw new InvalidOperationException("Shared appearance did not round-trip.");
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

  private static void VerifyGeometry() {
    if (WidgetGeometry.ResizeEdgeAt(1, 1, 400, 500) !=
        (WidgetResizeEdge.Left | WidgetResizeEdge.Top) ||
        WidgetGeometry.ResizeEdgeAt(399, 499, 400, 500) !=
        (WidgetResizeEdge.Right | WidgetResizeEdge.Bottom)) {
      throw new InvalidOperationException("Resize edge hit testing failed.");
    }
    if (WidgetGeometry.LogicalSize(100, 1200) != new Size(340, 900) ||
        WidgetGeometry.Scale(new Size(400, 500), 1.5f) != new Size(600, 750)) {
      throw new InvalidOperationException("Resize or DPI sizing bounds failed.");
    }
    var clamped = WidgetGeometry.ClampToWorkingArea(
      new Rectangle(-800, 900, 400, 500), new Rectangle(0, 0, 1920, 1040));
    if (clamped != new Rectangle(0, 540, 400, 500)) {
      throw new InvalidOperationException("Monitor placement clamping failed.");
    }
  }

  private static void CreateDatabase(string path) {
    using var connection = new SqliteConnection($"Data Source={path}");
    connection.Open();
    using var command = connection.CreateCommand();
    command.CommandText = """
      PRAGMA user_version = 4;
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL REFERENCES categories(id),
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 0,
        category_id TEXT REFERENCES categories(id),
        project_id TEXT REFERENCES projects(id),
        scheduled_date TEXT,
        deadline_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        planned_duration_minutes INTEGER,
        remaining_work_minutes INTEGER,
        scheduling_locked INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE scheduling_operations (
        id TEXT PRIMARY KEY,
        operation_type TEXT NOT NULL,
        source TEXT NOT NULL,
        scope TEXT NOT NULL,
        created_at TEXT NOT NULL,
        reverts_operation_id TEXT
      );
      CREATE TABLE scheduling_changes (
        id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL REFERENCES scheduling_operations(id),
        target_kind TEXT NOT NULL,
        target_id TEXT NOT NULL,
        before_date TEXT,
        after_date TEXT,
        before_starts_at TEXT,
        before_ends_at TEXT,
        after_starts_at TEXT,
        after_ends_at TEXT,
        before_updated_at TEXT,
        after_updated_at TEXT
      );
      INSERT INTO categories VALUES(
        'category-1','Personal','2026-10-17T00:00:00Z','2026-10-17T00:00:00Z');
      INSERT INTO projects VALUES(
        'project-1','category-1','Home','2026-10-17T00:00:00Z','2026-10-17T00:00:00Z');
      """;
    command.ExecuteNonQuery();
  }
}
