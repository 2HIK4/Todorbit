using Microsoft.Data.Sqlite;

internal static class LifeManagerWidgetSelfTest {
  internal static void Run() {
    var directory = Path.Combine(Path.GetTempPath(),
      $"life-manager-widget-test-{Guid.NewGuid()}");
    Directory.CreateDirectory(directory);
    var databasePath = Path.Combine(directory, "test.sqlite");
    try {
      TestIsolatedAppData(directory);
      TestPrivacy(directory);
      CreateDatabase(databasePath);
      string id, inboxId;
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
        inboxId = repository.AddTask("Inbox task", today, WidgetTaskView.Inbox);
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
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = """
          ALTER TABLE recurrence_series ADD COLUMN family_id TEXT;
          ALTER TABLE recurrence_series ADD COLUMN active_from_date TEXT;
          ALTER TABLE recurrence_series ADD COLUMN active_through_date TEXT;
          UPDATE recurrence_series SET family_id=id,active_from_date=start_date;
          PRAGMA user_version = 7;
          """;
        command.ExecuteNonQuery();
      }
      using (var v7Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        var today = DateTime.Now.Date;
        var day = today.ToString("yyyy-MM-dd",
          System.Globalization.CultureInfo.InvariantCulture);
        var taskId = v7Repository.AddTask("Superseded recurrence", today);
        using (var link = new SqliteConnection(
            $"Data Source={databasePath};Pooling=False")) {
          link.Open();
          using var command = link.CreateCommand();
          command.CommandText = """
            INSERT INTO recurrence_series(
              id,family_id,active_from_date,active_through_date,
              kind,start_date,interval,weekdays,end_date,max_occurrences,
              title,notes,priority,category_id,project_id,deadline_offset_days,
              planned_duration_minutes,remaining_work_minutes,scheduling_locked,
              created_at,updated_at)
            VALUES('superseded','family',$day,$day,'afterCompletion',$day,1,
              '',NULL,NULL,'Superseded recurrence','',0,NULL,NULL,NULL,
              NULL,NULL,0,$now,$now);
            INSERT INTO recurrence_occurrences(
              id,series_id,ordinal,nominal_date,task_id,created_at,updated_at)
            VALUES('superseded-first','superseded',0,$day,$task,$now,$now);
            """;
          command.Parameters.AddWithValue("$day", day);
          command.Parameters.AddWithValue("$task", taskId);
          command.Parameters.AddWithValue("$now", DateTime.UtcNow.ToString("O"));
          command.ExecuteNonQuery();
        }
        v7Repository.CompleteTask(taskId);
        using var check = new SqliteConnection(
          $"Data Source={databasePath};Mode=ReadOnly;Pooling=False");
        check.Open();
        using var query = check.CreateCommand();
        query.CommandText =
          "SELECT COUNT(*) FROM recurrence_occurrences WHERE series_id='superseded'";
        if (Convert.ToInt32(query.ExecuteScalar()) != 1) {
          throw new InvalidOperationException(
            "Schema v7 completion generated after a series boundary.");
        }
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = "PRAGMA user_version = 8";
        command.ExecuteNonQuery();
      }
      using (var v8Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        if (v8Repository.LoadTask(id)?.Status != "completed") {
          throw new InvalidOperationException(
            "Widget could not read a schema v8 task.");
        }
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = "PRAGMA user_version = 9";
        command.ExecuteNonQuery();
      }
      using (var v9Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        if (v9Repository.LoadTask(id)?.Status != "completed") {
          throw new InvalidOperationException(
            "Widget could not read a schema v9 task.");
        }
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = "PRAGMA user_version = 10";
        command.ExecuteNonQuery();
      }
      using (var v10Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        if (v10Repository.LoadTask(id)?.Status != "completed") {
          throw new InvalidOperationException(
            "Widget could not read a schema v10 task.");
        }
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = "PRAGMA user_version = 11";
        command.ExecuteNonQuery();
      }
      using (var v11Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        if (v11Repository.LoadTask(id)?.Status != "completed") {
          throw new InvalidOperationException(
            "Widget could not read a schema v11 task.");
        }
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = "PRAGMA user_version = 12";
        command.ExecuteNonQuery();
      }
      using (var v12Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        if (v12Repository.LoadTask(id)?.Status != "completed") {
          throw new InvalidOperationException(
            "Widget could not read a schema v12 task.");
        }
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = """
          ALTER TABLE tasks ADD COLUMN deleted_at TEXT;
          ALTER TABLE tasks ADD COLUMN archived_at TEXT;
          ALTER TABLE projects ADD COLUMN deleted_at TEXT;
          ALTER TABLE categories ADD COLUMN deleted_at TEXT;
          ALTER TABLE recurrence_series ADD COLUMN deleted_at TEXT;
          ALTER TABLE recurrence_series ADD COLUMN archived_at TEXT;
          PRAGMA user_version = 13;
          """;
        command.ExecuteNonQuery();
      }
      using (var v13Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        var today = new DateTime(2026, 10, 17);
        if (v13Repository.LoadTask(inboxId) == null) {
          throw new InvalidOperationException("Widget could not read a schema v13 task.");
        }
        using var mutation = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False");
        mutation.Open();
        using var command = mutation.CreateCommand();
        command.CommandText = "UPDATE tasks SET archived_at='2026-10-18T00:00:00.000Z' WHERE id=$id";
        command.Parameters.AddWithValue("$id", inboxId);
        command.ExecuteNonQuery();
        if (v13Repository.LoadTask(inboxId) != null ||
            v13Repository.LoadTasks(today, WidgetTaskView.Inbox)
              .Any(task => task.Id == inboxId)) {
          throw new InvalidOperationException("Archived task remained in widget.");
        }
        command.CommandText = "UPDATE categories SET deleted_at='2026-10-18T00:00:00.000Z'";
        command.Parameters.Clear();
        command.ExecuteNonQuery();
        if (v13Repository.LoadCategories().Count != 0 ||
            v13Repository.LoadProjects().Count != 0 ||
            v13Repository.LoadTask(id) != null) {
          throw new InvalidOperationException("Trashed category remained in widget.");
        }
      }
      using var survivor = LifeManagerWidgetRepository.OpenForTest(databasePath);
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = """
          CREATE TABLE notification_settings (
            id INTEGER PRIMARY KEY CHECK(id=1), due_reminders INTEGER NOT NULL,
            daily_summary INTEGER NOT NULL, local_minute INTEGER NOT NULL,
            updated_at TEXT NOT NULL);
          CREATE TABLE notification_deliveries (
            id TEXT PRIMARY KEY, kind TEXT NOT NULL, local_day TEXT NOT NULL,
            delivered_at TEXT NOT NULL, UNIQUE(kind,local_day));
          UPDATE categories SET deleted_at=NULL;
          UPDATE tasks SET archived_at=NULL WHERE id=$inbox;
          UPDATE tasks SET status='notStarted', deadline_date='2026-10-18'
            WHERE id=$id;
          INSERT INTO notification_settings VALUES
            (1,1,1,540,'2026-10-18T00:00:00Z');
          PRAGMA user_version=14;
          """;
        command.Parameters.AddWithValue("$id", id);
        command.Parameters.AddWithValue("$inbox", inboxId);
        command.ExecuteNonQuery();
      }
      using (var v14Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        var before = new DateTime(2026, 10, 18, 8, 59, 0);
        var due = new DateTime(2026, 10, 18, 9, 1, 0);
        if (v14Repository.ClaimDailyNotifications(before).Count != 0)
          throw new InvalidOperationException("Reminder fired early.");
        var messages = survivor.ClaimDailyNotifications(due);
        if (messages.Count != 2 || !messages[0].Contains("1 open task"))
          throw new InvalidOperationException("A companion opened before migration did not detect v14 notifications.");
        if (v14Repository.ClaimDailyNotifications(due).Count != 0)
          throw new InvalidOperationException("Reminder was duplicated.");
        using var mutation = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False");
        mutation.Open();
        using var change = mutation.CreateCommand();
        change.CommandText = "UPDATE categories SET deleted_at='2026-10-18T12:00:00Z'";
        change.ExecuteNonQuery();
        var nextDay = v14Repository.ClaimDailyNotifications(
          new DateTime(2026, 10, 19, 9, 1, 0));
        if (nextDay.Count != 1 || !nextDay[0].Contains("0 due or overdue"))
          throw new InvalidOperationException("Trashed tasks appeared in reminders.");
        change.CommandText = "UPDATE notification_settings SET daily_summary=0,due_reminders=0";
        change.ExecuteNonQuery();
        if (v14Repository.ClaimDailyNotifications(
            new DateTime(2026, 10, 20, 9, 1, 0)).Count != 0)
          throw new InvalidOperationException("Disabled reminders were delivered.");
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = "CREATE TABLE task_resources (id TEXT PRIMARY KEY, task_id TEXT NOT NULL); PRAGMA user_version=15;";
        command.ExecuteNonQuery();
      }
      using (var v15Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        if (v15Repository.LoadTask(inboxId) == null)
          throw new InvalidOperationException("Widget could not read a schema v15 task.");
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = """
          CREATE TABLE event_occurrence_changes(event_id TEXT, nominal_date TEXT);
          CREATE TABLE entity_icons(kind TEXT, entity_id TEXT, icon_key TEXT);
          CREATE TABLE task_parent_links(child_id TEXT, parent_id TEXT);
          CREATE TABLE task_checklist(id TEXT, task_id TEXT);
          PRAGMA user_version=18;
          """;
        command.ExecuteNonQuery();
      }
      using (var v18Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        var today = new DateTime(2026, 10, 21);
        var parent = v18Repository.AddTask("Parent", today);
        var child = v18Repository.AddTask("Child", today);
        using var mutation = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False");
        mutation.Open();
        using var change = mutation.CreateCommand();
        change.CommandText = "INSERT INTO task_parent_links VALUES($child,$parent)";
        change.Parameters.AddWithValue("$child", child);
        change.Parameters.AddWithValue("$parent", parent);
        change.ExecuteNonQuery();
        change.CommandText = "UPDATE tasks SET deleted_at='2026-10-21T10:00:00Z' WHERE id=$parent";
        change.ExecuteNonQuery();
        if (v18Repository.LoadTask(child) != null)
          throw new InvalidOperationException("A trashed parent exposed its subtask.");
        change.CommandText = "UPDATE tasks SET deleted_at=NULL WHERE id=$parent";
        change.ExecuteNonQuery();
        if (v18Repository.LoadTask(child) == null)
          throw new InvalidOperationException("Restoring a parent did not reveal its subtask.");
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = """
          CREATE TABLE progressive_plans(family_id TEXT PRIMARY KEY, end_action TEXT, updated_at TEXT);
          CREATE TABLE progressive_plan_steps(id TEXT PRIMARY KEY, family_id TEXT, position INTEGER, title TEXT);
          CREATE TABLE progressive_plan_assignments(occurrence_id TEXT PRIMARY KEY, step_index INTEGER, title TEXT);
          PRAGMA user_version=19;
          """;
        command.ExecuteNonQuery();
      }
      using (var v19Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        if (v19Repository.LoadTask(inboxId) == null)
          throw new InvalidOperationException("Widget could not read a schema v19 task.");
      }
      using (var upgrade = new SqliteConnection(
          $"Data Source={databasePath};Pooling=False")) {
        upgrade.Open();
        using var command = upgrade.CreateCommand();
        command.CommandText = """
          CREATE TABLE fixed_events(id TEXT PRIMARY KEY, title TEXT NOT NULL,
            starts_at TEXT NOT NULL, reminder_minutes INTEGER,
            recurrence_kind TEXT, recurrence_interval INTEGER NOT NULL DEFAULT 1,
            recurrence_weekdays TEXT, recurrence_until TEXT,
            active_from_date TEXT, active_through_date TEXT, deleted_at TEXT);
          CREATE TABLE event_reminder_deliveries(id TEXT PRIMARY KEY,
            event_id TEXT, nominal_date TEXT, starts_at TEXT,
            delivered_at TEXT, UNIQUE(event_id,nominal_date,starts_at));
          ALTER TABLE event_occurrence_changes ADD COLUMN cancelled INTEGER NOT NULL DEFAULT 0;
          ALTER TABLE event_occurrence_changes ADD COLUMN payload_json TEXT;
          PRAGMA user_version=20;
          """;
        command.ExecuteNonQuery();
        command.CommandText = """
          INSERT INTO fixed_events(id,title,starts_at,reminder_minutes)
          VALUES($id,'Lecture',$start,15)
          """;
        command.Parameters.AddWithValue("$id", Guid.NewGuid().ToString());
        command.Parameters.AddWithValue("$start",
          DateTimeOffset.Now.AddMinutes(14).ToUniversalTime().ToString("O"));
        command.ExecuteNonQuery();
        var lectureStart = DateTime.Now.AddMinutes(14);
        var lectureDay = lectureStart.ToString("yyyy-MM-dd");
        var weekday = ((int)lectureStart.DayOfWeek + 6) % 7 + 1;
        command.CommandText = """
          INSERT INTO fixed_events(id,title,starts_at,reminder_minutes,
            recurrence_kind,recurrence_weekdays,recurrence_until)
          VALUES($weekly,'Weekly lecture',$start,15,'weekdays',$days,$until)
          """;
        command.Parameters.Clear();
        command.Parameters.AddWithValue("$weekly", Guid.NewGuid().ToString());
        command.Parameters.AddWithValue("$start",
          lectureStart.ToUniversalTime().ToString("O"));
        command.Parameters.AddWithValue("$days", $"[{weekday}]");
        command.Parameters.AddWithValue("$until", lectureDay);
        command.ExecuteNonQuery();
        var cancelledId = Guid.NewGuid().ToString();
        command.Parameters.Clear();
        command.CommandText = """
          INSERT INTO fixed_events(id,title,starts_at,reminder_minutes,
            recurrence_kind,recurrence_weekdays,recurrence_until)
          VALUES($cancelled,'Cancelled lecture',$start,15,'weekdays',$days,$until)
          """;
        command.Parameters.AddWithValue("$cancelled", cancelledId);
        command.Parameters.AddWithValue("$start",
          lectureStart.ToUniversalTime().ToString("O"));
        command.Parameters.AddWithValue("$days", $"[{weekday}]");
        command.Parameters.AddWithValue("$until", lectureDay);
        command.ExecuteNonQuery();
        command.Parameters.Clear();
        command.CommandText = """
          INSERT INTO event_occurrence_changes(event_id,nominal_date,cancelled)
          VALUES($event,$day,1)
          """;
        command.Parameters.AddWithValue("$event", cancelledId);
        command.Parameters.AddWithValue("$day", lectureDay);
        command.ExecuteNonQuery();
      }
      using (var v20Repository =
          LifeManagerWidgetRepository.OpenForTest(databasePath)) {
        var now = DateTime.Now;
        if (v20Repository.ClaimEventReminders(now).Count != 2)
          throw new InvalidOperationException("One-off/weekly reminder or cancellation failed.");
        if (v20Repository.ClaimEventReminders(now).Count != 0)
          throw new InvalidOperationException("Event reminder fired twice.");
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

  private static void TestIsolatedAppData(string directory) {
    var previous = Environment.GetEnvironmentVariable("APPDATA");
    try {
      Environment.SetEnvironmentVariable("APPDATA", directory);
      var portable = AppDataPaths.PortableDirectoryIn(directory, AppContext.BaseDirectory);
      var expected = portable ?? Path.Combine(directory, "TodoPilot");
      if (AppDataPaths.ActiveDirectory != expected) {
        throw new InvalidOperationException("Native APPDATA override was ignored.");
      }
      var settings = new WidgetSettingsStore();
      settings.Save(new WidgetSettings { View = WidgetTaskView.Upcoming });
      if (!File.Exists(Path.Combine(expected, "widget-settings.json"))) {
        throw new InvalidOperationException("Widget settings escaped isolated APPDATA.");
      }
      File.WriteAllText(Path.Combine(expected, "privacy-settings.json"),
        "{\"enabled\":true}");
      if (!PrivacyState.OpenDefault().IsLocked()) {
        throw new InvalidOperationException("Privacy state escaped isolated APPDATA.");
      }
      var legacy = Path.Combine(directory, "Life Manager");
      Directory.CreateDirectory(legacy);
      File.WriteAllText(Path.Combine(legacy, "life_manager.sqlite"), "test marker only");
      if (AppDataPaths.ActiveDirectory != expected) {
        throw new InvalidOperationException("Legacy database was selected automatically.");
      }
      var marker = Path.Combine(directory, "TodoPilot", "legacy-profile.json");
      Directory.CreateDirectory(Path.GetDirectoryName(marker)!);
      File.WriteAllText(marker, "{\"profile\":\"todopilot-upgrade-v1\"}");
      if (AppDataPaths.ActiveDirectory != (portable == null ? legacy : expected)) {
        throw new InvalidOperationException(portable == null
          ? "Upgrade marker was ignored."
          : "Portable widget selected the installed upgrade profile.");
      }
      File.WriteAllText(marker, "{\"profile\":\"unrelated\"}");
      if (AppDataPaths.ActiveDirectory != expected) {
        throw new InvalidOperationException("Invalid upgrade marker selected legacy data.");
      }
      var portableOne = Path.Combine(directory, "portable one");
      var portableTwo = Path.Combine(directory, "portable two");
      Directory.CreateDirectory(portableOne);
      Directory.CreateDirectory(portableTwo);
      File.WriteAllText(Path.Combine(portableOne, "PORTABLE-MODE"), "TodoPilot portable profile");
      File.WriteAllText(Path.Combine(portableTwo, "PORTABLE-MODE"), "TodoPilot portable profile");
      var firstProfile = AppDataPaths.PortableDirectoryIn(directory, portableOne);
      var secondProfile = AppDataPaths.PortableDirectoryIn(directory, portableTwo);
      if (firstProfile == null || secondProfile == null || firstProfile == secondProfile ||
          firstProfile != AppDataPaths.PortableDirectoryIn(directory, portableOne)) {
        throw new InvalidOperationException("Portable widget profiles are not location-specific.");
      }
      if (AppDataPaths.ChannelSuffixFor(firstProfile) ==
          AppDataPaths.ChannelSuffixFor(secondProfile)) {
        throw new InvalidOperationException("Portable widget command channels are shared.");
      }
    } finally {
      Environment.SetEnvironmentVariable("APPDATA", previous);
    }
  }

  private static void TestPrivacy(string directory) {
    var state = new PrivacyState(directory, System.Diagnostics.Process.GetCurrentProcess().ProcessName);
    var policy = Path.Combine(directory, "privacy-settings.json");
    if (state.IsLocked()) throw new InvalidOperationException("Default privacy should be off.");
    File.WriteAllText(policy, "{\"enabled\":true}");
    if (!state.IsLocked()) throw new InvalidOperationException("Missing unlock session exposed tasks.");
    File.WriteAllText(Path.Combine(directory, "privacy-session.json"),
      $"{{\"pid\":{Environment.ProcessId},\"expiresUtc\":\"{DateTimeOffset.UtcNow.AddSeconds(4):O}\"}}");
    if (state.IsLocked()) throw new InvalidOperationException("Valid live session stayed locked.");
    File.WriteAllText(Path.Combine(directory, "privacy-session.json"),
      "{\"pid\":1,\"expiresUtc\":\"2000-01-01T00:00:00Z\"}");
    if (!state.IsLocked()) throw new InvalidOperationException("Expired session exposed tasks.");
    File.WriteAllText(policy, "{broken");
    if (!state.IsLocked()) throw new InvalidOperationException("Corrupt privacy policy exposed tasks.");
    File.WriteAllText(policy, "{\"enabled\":false}");
    if (state.IsLocked()) throw new InvalidOperationException("Disabled privacy stayed locked.");
  }

  private static void VerifyAppearanceRoundTrip(string directory) {
    var path = Path.Combine(directory, "appearance.json");
    var store = new AppearanceSettingsStore(path);
    var settings = store.Load(WidgetThemePreference.Dark);
    if (settings.Theme != WidgetThemePreference.Dark) {
      throw new InvalidOperationException("Legacy appearance was not migrated.");
    }
    settings.Theme = WidgetThemePreference.Light;
    settings.WidgetOpacity = 35;
    settings.Customization = new WidgetCustomization {
      Version = 1,
      Light = new Dictionary<string, string> {
        ["background"] = "#F8F7FC", ["surface"] = "#FFFFFF",
        ["accent"] = "#123456", ["primaryText"] = "#211B35",
        ["secondaryText"] = "#665F78", ["border"] = "#DCD7E9",
      },
    };
    store.Save(settings);
    if (store.Load().Theme != WidgetThemePreference.Light ||
        store.Load().WidgetOpacity != 35 ||
        WidgetPalette.FromCustom(store.Load().Customization?.Light,
          WidgetPalette.Light).Accent != Color.FromArgb(0x12, 0x34, 0x56)) {
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
      LayoutLocked = true,
      BackgroundOpacity = 30,
    };
    store.Save(expected);
    var actual = store.Load();
    if (actual.X != expected.X || actual.Width != expected.Width ||
        actual.Theme != expected.Theme || actual.View != expected.View ||
        actual.MonitorDeviceName != expected.MonitorDeviceName ||
        !actual.LayoutLocked || actual.BackgroundOpacity != 30) {
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
    if (WidgetGeometry.LogicalSize(100, 1200) != new Size(260, 1200) ||
        WidgetGeometry.Scale(new Size(400, 500), 1.5f) != new Size(600, 750)) {
      throw new InvalidOperationException("Resize or DPI sizing bounds failed.");
    }
    var start = new Rectangle(120, 90, 400, 300);
    if (WidgetGeometry.MoveOrResize(start, 75, -20, true,
        WidgetResizeEdge.None, 260, 230) !=
        new Rectangle(195, 70, 400, 300) ||
        WidgetGeometry.MoveOrResize(start, 60, 40, false,
          WidgetResizeEdge.Left | WidgetResizeEdge.Top, 260, 230) !=
        new Rectangle(180, 130, 340, 260) ||
        WidgetGeometry.MoveOrResize(start, 500, 500, false,
          WidgetResizeEdge.Left | WidgetResizeEdge.Top, 260, 230) !=
        new Rectangle(260, 160, 260, 230)) {
      throw new InvalidOperationException("Drag or corner resize geometry failed.");
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
