using System.Globalization;
using System.Text.Json;

internal sealed partial class LifeManagerWidgetRepository
{
    // Shares the companion's existing 30-second notification timer and privacy gate.
    internal IReadOnlyList<string> ClaimTaskReminders(DateTime localNow)
    {
        RefreshSchemaVersion();
        if (schemaVersion < 22) return [];
        var now = localNow.ToUniversalTime();
        var candidates = new List<(string Id, string Title, DateTime Trigger)>();
        using var transaction = connection.BeginTransaction();
        using (var query = connection.CreateCommand())
        {
            query.Transaction = transaction;
            query.CommandText = """
              SELECT tasks.id,tasks.title,tasks.notification_json,
                (SELECT MIN(w.starts_at) FROM work_sessions w WHERE w.task_id=tasks.id
                  AND w.deleted_at IS NULL AND w.archived_at IS NULL AND w.outcome='upcoming'
                  AND julianday(w.ends_at)>julianday($now))
              FROM tasks WHERE json_extract(notification_json,'$.mode') != 'off' AND tasks.status NOT IN ('completed','cancelled')
              """ + ActiveTaskClause + ActiveParentClause;
            query.Parameters.AddWithValue("$now", now.ToString("O"));
            using var rows = query.ExecuteReader();
            while (rows.Read())
            {
                using var json = JsonDocument.Parse(rows.GetString(2));
                var config = json.RootElement;
                var mode = config.GetProperty("mode").GetString();
                if (mode == "off") continue;
                DateTime trigger;
                if (mode == "custom" && config.TryGetProperty("at", out var at) && at.ValueKind == JsonValueKind.String)
                    trigger = DateTimeOffset.Parse(at.GetString()!, CultureInfo.InvariantCulture).UtcDateTime;
                else if (mode == "session" && !rows.IsDBNull(3))
                {
                    var offset = config.TryGetProperty("minutesBefore", out var minutes) ? minutes.GetInt32() : 0;
                    trigger = DateTimeOffset.Parse(rows.GetString(3), CultureInfo.InvariantCulture).UtcDateTime.AddMinutes(-Math.Clamp(offset,0,10080));
                }
                else continue;
                if (trigger <= now && trigger > now.AddMinutes(-5)) candidates.Add((rows.GetString(0),rows.GetString(1),trigger));
            }
        }
        var messages = new List<string>();
        foreach (var item in candidates)
        {
            using var claim = connection.CreateCommand();
            claim.Transaction = transaction;
            claim.CommandText = "INSERT OR IGNORE INTO task_reminder_deliveries(task_id,trigger_at,delivered_at) VALUES($id,$at,$now)";
            claim.Parameters.AddWithValue("$id",item.Id);
            claim.Parameters.AddWithValue("$at",item.Trigger.ToString("O"));
            claim.Parameters.AddWithValue("$now",now.ToString("O"));
            if (claim.ExecuteNonQuery() == 1) messages.Add("Task: " + item.Title);
        }
        transaction.Commit();
        return messages;
    }
}
