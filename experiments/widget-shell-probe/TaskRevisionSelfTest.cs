using System.Globalization;
using Microsoft.Data.Sqlite;

internal static partial class LifeManagerWidgetSelfTest {
  private static string ReadTaskRevision(LifeManagerWidgetRepository repository, string id) {
    using var connection = new SqliteConnection($"Data Source={repository.DatabasePath};Mode=ReadOnly;Pooling=False");
    connection.Open();
    using var command = connection.CreateCommand();
    command.CommandText = "SELECT updated_at FROM tasks WHERE id=$id";
    command.Parameters.AddWithValue("$id", id);
    return (string)command.ExecuteScalar()!;
  }

  private static void TestTaskRevisionSafety(string directory) {
    var frozen = new DateTime(2030, 1, 1, 0, 0, 0, DateTimeKind.Utc);
    var revision = frozen.ToString("yyyy-MM-dd'T'HH:mm:ss.ffffff'Z'", CultureInfo.InvariantCulture);
    for (var i = 0; i < 100; i++) {
      var next = LifeManagerWidgetRepository.NextTaskRevision(revision, frozen.AddTicks(1));
      if (DateTime.Parse(next, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind) <=
          DateTime.Parse(revision, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind)) {
        throw new InvalidOperationException("Frozen/sub-microsecond task revisions collided.");
      }
      revision = next;
    }
    var path = Path.Combine(directory, "revision-safety.sqlite");
    var futureRevision = DateTime.UtcNow.AddYears(10).ToString(
      "yyyy-MM-dd'T'HH:mm:ss.ffffff'Z'", CultureInfo.InvariantCulture);
    CreateDatabase(path);
    using var first = LifeManagerWidgetRepository.OpenForTest(path);
    using var second = LifeManagerWidgetRepository.OpenForTest(path);
    var day = new DateTime(2026, 10, 31);
    var id = first.AddTask("Original", day);
    using (var seed = new SqliteConnection($"Data Source={path};Pooling=False")) {
      seed.Open();
      using var command = seed.CreateCommand();
      command.CommandText = "UPDATE tasks SET updated_at=$future WHERE id=$id";
      command.Parameters.AddWithValue("$future", futureRevision);
      command.Parameters.AddWithValue("$id", id);
      command.ExecuteNonQuery();
    }
    var original = first.LoadTasks(day).Single(t => t.Id == id);
    WidgetTaskUpdate Edit(WidgetTask task, string title, string status = "notStarted") =>
      new(title, task.Notes, status, task.Priority, task.CategoryId, task.ProjectId,
        task.ScheduledDate, task.DeadlineDate, task.UpdatedAt);
    second.UpdateTask(id, Edit(original, "Edited elsewhere"));
    var edited = second.LoadTasks(day).Single(t => t.Id == id);
    if (DateTime.Parse(edited.UpdatedAt, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind) <=
        DateTime.Parse(original.UpdatedAt, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind)) {
      throw new InvalidOperationException("Native edit did not advance past a future persisted revision.");
    }
    try {
      first.CompleteTask(id, original.UpdatedAt);
      throw new InvalidOperationException("Stale native completion was accepted.");
    } catch (InvalidOperationException error) when (error.Message.StartsWith("The task was already changed")) { }
    try {
      first.UpdateTask(id, Edit(original, "Lost update"));
      throw new InvalidOperationException("Stale native editor was accepted.");
    } catch (InvalidOperationException error) when (error.Message.StartsWith("This task changed")) { }
    first.CompleteTask(id, edited.UpdatedAt);
    var doneRevision = ReadTaskRevision(first, id);
    second.CompleteTask(id, edited.UpdatedAt); // Another widget delivered the same command.
    if (ReadTaskRevision(first, id) != doneRevision) throw new InvalidOperationException("Duplicate completion wrote again.");
    first.UpdateTask(id, Edit(edited with { UpdatedAt = doneRevision }, "Edited elsewhere"));
    try {
      second.CompleteTask(id, edited.UpdatedAt);
      throw new InvalidOperationException("Delayed command completed a reopened task.");
    } catch (InvalidOperationException error) when (error.Message.StartsWith("The task was already changed")) { }
    using (var delete = new SqliteConnection($"Data Source={path};Pooling=False")) {
      delete.Open();
      using var command = delete.CreateCommand();
      command.CommandText = "DELETE FROM tasks WHERE id=$id";
      command.Parameters.AddWithValue("$id", id);
      command.ExecuteNonQuery();
    }
    try {
      second.CompleteTask(id, doneRevision);
      throw new InvalidOperationException("Deleted native task was completed.");
    } catch (InvalidOperationException error) when (error.Message.StartsWith("The task was already changed")) { }
    Console.WriteLine("Task revision safety: frozen clock, stale edit/completion, independent connections, duplicate widgets, reopen and deletion passed.");
  }
}
