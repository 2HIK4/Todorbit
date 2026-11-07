using System.Globalization;
using System.Text.Json;

internal sealed record WidgetCalendarItem(DateTime Day, string Kind, string Title,
  string? TaskId, string Time = "", bool Cancelled = false, DateTime? StartsAt = null, string Id = "", string? NominalDate = null,
  int? ColorValue = null, string? IconName = null);

internal sealed partial class LifeManagerWidgetRepository
{
    /// Read-only calendar projection. Planned days, sessions and fixed events stay distinct.
    /// Event recurrence uses the same date matcher as the native reminder service.
    internal IReadOnlyList<WidgetCalendarItem> LoadCalendarItems(DateTime first, DateTime through, bool forNotifications = false)
    {
        if(!forNotifications || privacy?.SuppressLockedNotifications()==true) privacy?.RequireUnlocked();
        RefreshSchemaVersion();
        if (through <= first || (through - first).TotalDays > 62) throw new ArgumentOutOfRangeException(nameof(through));
        var result = new List<WidgetCalendarItem>();
        var active = schemaVersion >= 13 ? ActiveTaskClause : "";
        if (schemaVersion >= 18) active += ActiveParentClause;
        using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT id,title,scheduled_date FROM tasks WHERE scheduled_date >= $first AND scheduled_date < $end AND status NOT IN ('completed','cancelled')" + active;
            command.Parameters.AddWithValue("$first", first.ToString("yyyy-MM-dd"));
            command.Parameters.AddWithValue("$end", through.ToString("yyyy-MM-dd"));
            using var r = command.ExecuteReader();
            while (r.Read()) result.Add(new(DateTime.ParseExact(r.GetString(2), "yyyy-MM-dd", CultureInfo.InvariantCulture), "Task", r.GetString(1), r.GetString(0), Id:r.GetString(0)));
        }
        if (schemaVersion < 20) return result;
        var eventColumns = CalendarColumns("fixed_events");
        var categoryColors = new Dictionary<string, int>();
        if (CalendarColumns("categories").Contains("event_color"))
        {
            using var colors = connection.CreateCommand();
            colors.CommandText = "SELECT id,event_color FROM categories WHERE event_color IS NOT NULL AND deleted_at IS NULL";
            using var reader = colors.ExecuteReader();
            while (reader.Read()) categoryColors[reader.GetString(0)] = unchecked((int)reader.GetInt64(1));
        }
        int? EffectiveColor(int? explicitColor, string? category) => explicitColor ??
            (category != null && categoryColors.TryGetValue(category, out var color) ? color : null);
        using (var command = connection.CreateCommand())
        {
            command.CommandText = """
        SELECT w.task_id,t.title,w.starts_at,w.ends_at,w.id FROM work_sessions w JOIN tasks t ON t.id=w.task_id
        LEFT JOIN recurrence_occurrences o ON o.task_id=t.id
        LEFT JOIN recurrence_series s ON s.id=o.series_id
        LEFT JOIN categories c ON c.id=t.category_id LEFT JOIN projects p ON p.id=t.project_id
        WHERE w.deleted_at IS NULL AND t.deleted_at IS NULL AND t.archived_at IS NULL
          AND (s.id IS NULL OR (s.deleted_at IS NULL AND s.archived_at IS NULL))
          AND (c.id IS NULL OR c.deleted_at IS NULL) AND (p.id IS NULL OR p.deleted_at IS NULL)
          AND julianday(w.ends_at)>julianday($first) AND julianday(w.starts_at)<julianday($end)
        """;
            command.Parameters.AddWithValue("$first", first.ToUniversalTime().ToString("O"));
            command.Parameters.AddWithValue("$end", through.ToUniversalTime().ToString("O"));
            using var r = command.ExecuteReader();
            while (r.Read()) AddSpan(result, first, through, Local(r.GetString(2)), Local(r.GetString(3)), "Session", r.GetString(1), r.GetString(0), id:r.GetString(4));
        }
        var changes = new Dictionary<(string, string), EventReminderChange>();
        using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT event_id,nominal_date,cancelled,payload_json FROM event_occurrence_changes";
            using var r = command.ExecuteReader();
            while (r.Read()) changes[(r.GetString(0), r.GetString(1))] = new(r.GetString(0), r.GetString(1), r.GetInt32(2) == 1, r.IsDBNull(3) ? null : r.GetString(3));
        }
        using (var command = connection.CreateCommand())
        {
            command.CommandText = $"""
        SELECT e.id,e.title,starts_at,ends_at,recurrence_kind,recurrence_interval,
          COALESCE(recurrence_weekdays,''),recurrence_until,active_from_date,active_through_date,all_day,
          {(eventColumns.Contains("color_value") ? "e.color_value" : "NULL")},
          {(eventColumns.Contains("icon_name") ? "e.icon_name" : "NULL")},e.category_id
        FROM fixed_events e LEFT JOIN categories c ON c.id=e.category_id
        WHERE e.deleted_at IS NULL AND (c.id IS NULL OR c.deleted_at IS NULL)
          {(eventColumns.Contains("project_id") ? "AND (e.project_id IS NULL OR EXISTS(SELECT 1 FROM projects p WHERE p.id=e.project_id AND p.deleted_at IS NULL))" : "")}
        """;
            using var r = command.ExecuteReader();
            while (r.Read())
            {
                var start = Local(r.GetString(2)); var end = Local(r.GetString(3));
                var duration = end - start; var allDay = r.GetInt32(10) == 1;
                var explicitColor = r.IsDBNull(11) ? (int?)null : unchecked((int)r.GetInt64(11));
                var icon = r.IsDBNull(12) ? null : r.GetString(12);
                var category = r.IsDBNull(13) ? null : r.GetString(13);
                var color = EffectiveColor(explicitColor, category);
                var template = new EventReminderTemplate(r.GetString(0), r.GetString(1), start, null,
                  r.IsDBNull(4) ? null : r.GetString(4), r.GetInt32(5), r.GetString(6),
                  r.IsDBNull(7) ? null : r.GetString(7), r.IsDBNull(8) ? null : r.GetString(8), r.IsDBNull(9) ? null : r.GetString(9));
                var lower = first.AddDays(-Math.Ceiling(Math.Max(0, duration.TotalDays)));
                if (lower < start.Date) lower = start.Date;
                for (var day = lower; day < through; day = day.AddDays(1))
                {
                    if (!MatchesEventDate(template, day)) continue;
                    var nominal = day.ToString("yyyy-MM-dd");
                    if (changes.TryGetValue((template.Id, nominal), out var change))
                    {
                        if (change.Cancelled && change.Payload == null) AddSpan(result, first, through, day + start.TimeOfDay, day + start.TimeOfDay + duration, "Event", template.Title, null, allDay, true,id:template.Id,nominal:nominal,color:color,icon:icon);
                        // Overrides are evaluated separately, including moves into this range.
                        continue;
                    }
                    AddSpan(result, first, through, day + start.TimeOfDay, day + start.TimeOfDay + duration, "Event", template.Title, null, allDay,id:template.Id,nominal:nominal,color:color,icon:icon);
                }
                foreach (var change in changes.Values.Where(c => c.EventId == template.Id && c.Payload != null))
                {
                    if (template.ActiveFrom != null && string.CompareOrdinal(change.NominalDate, template.ActiveFrom) < 0 || template.ActiveThrough != null && string.CompareOrdinal(change.NominalDate, template.ActiveThrough) > 0) continue;
                    using var json = JsonDocument.Parse(change.Payload!); var data = json.RootElement;
                    var movedStart = data.TryGetProperty("startsAt", out var sv) ? Local(sv.GetString()!) : DateTime.ParseExact(change.NominalDate, "yyyy-MM-dd", CultureInfo.InvariantCulture) + start.TimeOfDay;
                    var movedEnd = data.TryGetProperty("endsAt", out var ev) ? Local(ev.GetString()!) : movedStart + duration;
                    var title = data.TryGetProperty("title", out var tv) ? tv.GetString() ?? template.Title : template.Title;
                    var fullDay = data.TryGetProperty("allDay", out var av) ? av.GetBoolean() : allDay;
                    var changedColor = data.TryGetProperty("colorValue", out var cv) ?
                        (cv.ValueKind == JsonValueKind.Number ? unchecked((int)cv.GetInt64()) : (int?)null) : explicitColor;
                    var changedCategory = data.TryGetProperty("categoryId", out var cat) ?
                        (cat.ValueKind == JsonValueKind.String ? cat.GetString() : null) : category;
                    var changedIcon = data.TryGetProperty("iconName", out var iv) ?
                        (iv.ValueKind == JsonValueKind.String ? iv.GetString() : null) : icon;
                    AddSpan(result, first, through, movedStart, movedEnd, "Event", title, null, fullDay, change.Cancelled,id:template.Id,nominal:change.NominalDate,color:EffectiveColor(changedColor, changedCategory),icon:changedIcon);
                }
            }
        }
        return result.OrderBy(i => i.Day).ThenBy(i => i.StartsAt ?? i.Day).ThenBy(i => i.Title).ToList();
    }
    private static DateTime Local(string date) => DateTimeOffset.Parse(date, CultureInfo.InvariantCulture).LocalDateTime;
    private HashSet<string> CalendarColumns(string table)
    {
        using var command = connection.CreateCommand();
        command.CommandText = $"PRAGMA table_info({table})";
        using var reader = command.ExecuteReader();
        var columns = new HashSet<string>();
        while (reader.Read()) columns.Add(reader.GetString(1));
        return columns;
    }
    private static void AddSpan(List<WidgetCalendarItem> items, DateTime first, DateTime through,
        DateTime start, DateTime end, string kind, string title, string? taskId, bool allDay = false, bool cancelled = false, string id = "", string? nominal = null, int? color = null, string? icon = null)
    {
        for (var day = start.Date < first ? first : start.Date; day < through && day < end; day = day.AddDays(1))
            items.Add(new(day, kind, title, taskId, allDay ? "All day · " : start.ToString("t") + " · ", cancelled, start,id,nominal,color,icon));
    }
}
