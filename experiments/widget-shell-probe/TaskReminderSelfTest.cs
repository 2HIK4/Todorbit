using Microsoft.Data.Sqlite;
using System.Text.Json;

internal static class TaskReminderSelfTest
{
    internal static void Verify()
    {
        var directory=Path.Combine(Path.GetTempPath(),"todorbit-task-reminder-"+Guid.NewGuid());
        Directory.CreateDirectory(directory);
        try
        {
            var file=Path.Combine(directory,"test.sqlite");
            using var db=new SqliteConnection($"Data Source={file}"); db.Open();
            using var sql=db.CreateCommand();
            sql.CommandText="""
              PRAGMA user_version=22;
              CREATE TABLE tasks(id TEXT PRIMARY KEY,title TEXT,status TEXT,deleted_at TEXT,archived_at TEXT,category_id TEXT,project_id TEXT,notification_json TEXT);
              CREATE TABLE categories(id TEXT,deleted_at TEXT);
              CREATE TABLE projects(id TEXT,deleted_at TEXT);
              CREATE TABLE recurrence_occurrences(task_id TEXT,series_id TEXT);
              CREATE TABLE recurrence_series(id TEXT,deleted_at TEXT,archived_at TEXT);
              CREATE TABLE task_parent_links(child_id TEXT,parent_id TEXT);
              CREATE TABLE work_sessions(id TEXT,task_id TEXT,starts_at TEXT,ends_at TEXT,outcome TEXT,deleted_at TEXT,archived_at TEXT);
              CREATE TABLE task_reminder_deliveries(task_id TEXT,trigger_at TEXT,delivered_at TEXT,PRIMARY KEY(task_id,trigger_at));
              """;
            sql.ExecuteNonQuery();
            var now=DateTime.Now;
            void Set(string mode,DateTime? at=null)
            {
                sql.Parameters.Clear();
                sql.CommandText="INSERT OR REPLACE INTO tasks(id,title,status,notification_json) VALUES('task','Explicit reminder','notStarted',$json)";
                sql.Parameters.AddWithValue("$json",JsonSerializer.Serialize(new {version=1,mode,at=at?.ToUniversalTime().ToString("O"),minutesBefore=15}));sql.ExecuteNonQuery();
            }
            using var repository=LifeManagerWidgetRepository.OpenForTest(file);
            Set("off");
            if(repository.ClaimTaskReminders(now).Count!=0) throw new InvalidOperationException("Task reminders are not off by default.");
            Set("custom",now.AddSeconds(-20));
            if(repository.ClaimTaskReminders(now).Count!=1 || repository.ClaimTaskReminders(now).Count!=0) throw new InvalidOperationException("Explicit reminder or duplicate claim failed.");
            Set("off");
            if(repository.ClaimTaskReminders(now.AddMinutes(1)).Count!=0) throw new InvalidOperationException("Disabled reminder fired.");
            Set("session");sql.Parameters.Clear();
            sql.CommandText="INSERT INTO work_sessions VALUES('session','task',$start,$end,'upcoming',NULL,NULL)";
            sql.Parameters.AddWithValue("$start",now.AddMinutes(15).ToUniversalTime().ToString("O"));
            sql.Parameters.AddWithValue("$end",now.AddMinutes(45).ToUniversalTime().ToString("O"));sql.ExecuteNonQuery();
            if(repository.ClaimTaskReminders(now).Count!=1) throw new InvalidOperationException("Relative session reminder failed.");
            sql.Parameters.Clear();sql.CommandText="UPDATE work_sessions SET starts_at=$start,ends_at=$end";
            sql.Parameters.AddWithValue("$start",now.AddMinutes(75).ToUniversalTime().ToString("O"));sql.Parameters.AddWithValue("$end",now.AddMinutes(105).ToUniversalTime().ToString("O"));sql.ExecuteNonQuery();
            if(repository.ClaimTaskReminders(now).Count!=0 || repository.ClaimTaskReminders(now.AddHours(1)).Count!=1) throw new InvalidOperationException("Rescheduling did not update the pending reminder.");
            Set("custom",now.AddMinutes(2));sql.Parameters.Clear();sql.CommandText="UPDATE tasks SET status='completed'";sql.ExecuteNonQuery();
            if(repository.ClaimTaskReminders(now.AddMinutes(2)).Count!=0) throw new InvalidOperationException("Completed task notified.");
        }
        finally { SqliteConnection.ClearAllPools(); Directory.Delete(directory,true); }
    }
}
