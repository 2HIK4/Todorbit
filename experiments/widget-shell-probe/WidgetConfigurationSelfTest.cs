using Microsoft.Data.Sqlite;

internal static partial class LifeManagerWidgetSelfTest
{
    internal static void CaptureWidgetPreviews(string output)
    {
        output = Path.GetFullPath(output); Directory.CreateDirectory(output);
        var profile = Path.Combine(Path.GetTempPath(), "todorbit-render-" + Guid.NewGuid());
        Directory.CreateDirectory(profile);
        var previous = Environment.GetEnvironmentVariable("APPDATA");
        try
        {
            Environment.SetEnvironmentVariable("APPDATA", profile);
            TestCalendarProjection(profile);
            using var repo = LifeManagerWidgetRepository.OpenForTest(Path.Combine(profile, "calendar-projection.sqlite"));
            repo.AddTask("Review the weekly plan", DateTime.Today);
            repo.AddTask("Prepare meeting notes", DateTime.Today);
            foreach (var light in new[] { false, true }) foreach (var calendar in new[] { false, true }) foreach (var dpi in new[] { 1f, 1.25f, 1.5f, 2f })
            {
                var config = new WidgetConfiguration();
                if (!calendar) { config.NavigationDisplay = "both"; config.NavigationPosition = "left"; }
                using var bitmap = NativeDesktopWidgetHost.RenderPreview(repo, config, calendar, new Size(376, 460), light ? WidgetPalette.Light : WidgetPalette.Dark, dpi);
                bitmap.Save(Path.Combine(output, $"{(calendar ? "calendar" : "tasks")}-{(light ? "light" : "dark")}-{dpi * 100:0}.png"));
            }
            foreach (var position in new[] { "top", "left", "right", "bottom" }) foreach (var mode in new[] { "text", "icons", "both" }) foreach (var header in new[] { true, false })
            {
                var config = new WidgetConfiguration { NavigationPosition = position, NavigationDisplay = mode, ShowTitle = header, ShowOpenButton = header };
                using var bitmap = NativeDesktopWidgetHost.RenderPreview(repo, config, false, new Size(260, 230), WidgetPalette.Dark);
                bitmap.Save(Path.Combine(output, $"compact-{position}-{mode}-{header}.png"));
            }
            foreach (var calendar in new[] { false, true })
            {
                var transparent = new WidgetConfiguration();
                foreach (var layer in transparent.Surfaces.Values) layer.Opacity = 0;
                using var image = NativeDesktopWidgetHost.RenderPreview(repo, transparent, calendar, new Size(376, 460), WidgetPalette.Dark);
                image.Save(Path.Combine(output, $"{(calendar ? "calendar" : "tasks")}-transparent.png"));
            }
        }
        finally
        {
            Environment.SetEnvironmentVariable("APPDATA", previous);
            SqliteConnection.ClearAllPools(); Directory.Delete(profile, true);
        }
    }
    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }
    private static void TestWidgetConfiguration(string directory)
    {
        var previous = Environment.GetEnvironmentVariable("APPDATA");
        try
        {
            Environment.SetEnvironmentVariable("APPDATA", Path.Combine(directory, "configuration-profile"));
            var legacy = new WidgetSettings { BackgroundOpacity = 35, LayoutLocked = true, Width = 432 };
            var tasks = WidgetConfiguration.Load(false, legacy);
            var calendar = WidgetConfiguration.Load(true, new WidgetSettings());
            Require(tasks.Enabled && tasks.Surface("shell").Opacity == 35 && tasks.LayoutLocked, "Legacy widget configuration was not preserved.");
            Require(!calendar.Enabled && !calendar.LayoutLocked, "Calendar must start independently disabled.");
            tasks.ShowTitle = false; tasks.ShowOpenButton = false; tasks.Views = []; tasks.NavigationPosition = "right"; tasks.NavigationDisplay = "icons";
            tasks.Surface("shell").BorderOpacity = 25; tasks.Save(false);
            calendar.Enabled = true; calendar.Save(true);
            var loaded = WidgetConfiguration.Load(false, legacy);
            Require(!loaded.HasHeader && loaded.Views.Count == 0 && loaded.NavigationPosition == "right" && loaded.NavigationDisplay == "icons", "Hidden header/navigation did not round trip.");
            Require(loaded.Surface("shell").BorderOpacity == 25 && WidgetConfiguration.Load(true, legacy).Enabled, "Independent widget settings were overwritten.");
            Require(legacy.Width == 432, "Configuration migration changed device geometry.");
            Require(NativeDesktopWidgetHost.WidgetSettingsActivation("Todorbit.exe", true).ArgumentList.SequenceEqual(new[] { "--edit-widget", "calendar" }), "Calendar edit route selected the wrong widget.");
            Require(NativeDesktopWidgetHost.WidgetSettingsActivation("Todorbit.exe", false).ArgumentList.SequenceEqual(new[] { "--edit-widget", "tasks" }), "Tasks edit route selected the wrong widget.");
            foreach (var scale in new[] { 1f, 1.25f, 1.5f, 2f }) Require(WidgetGeometry.Scale(new Size(300, 360), scale).Width == (int)(300 * scale), "DPI geometry changed.");
            Require(CalendarWidgetDates.GridStart(new DateTime(2026, 11, 1), 7) == new DateTime(2026, 11, 1), "Sunday week start failed.");
            Require(CalendarWidgetDates.GridStart(new DateTime(2026, 11, 1), 1) == new DateTime(2026, 10, 26), "Monday week start failed.");
            Require(CalendarWidgetDates.GridStart(new DateTime(2028, 2, 1), 7).AddDays(41) >= new DateTime(2028, 2, 29), "Leap month grid failed.");
        }
        finally { Environment.SetEnvironmentVariable("APPDATA", previous); }
    }
    private static void TestCalendarProjection(string directory)
    {
        using var isolated = new WidgetTestProfile(Path.Combine(directory, "calendar-profile"));
        var file = Path.Combine(directory, "calendar-projection.sqlite");
        CreateDatabase(file);
        using (var connection = new SqliteConnection($"Data Source={file};Pooling=False"))
        {
            connection.Open(); using var c = connection.CreateCommand();
            c.CommandText = """
        ALTER TABLE tasks ADD COLUMN deleted_at TEXT;
        ALTER TABLE tasks ADD COLUMN archived_at TEXT;
        ALTER TABLE categories ADD COLUMN deleted_at TEXT;
        ALTER TABLE projects ADD COLUMN deleted_at TEXT;
        CREATE TABLE recurrence_series(id TEXT,deleted_at TEXT,archived_at TEXT);
        CREATE TABLE recurrence_occurrences(task_id TEXT,series_id TEXT);
        CREATE TABLE task_parent_links(child_id TEXT,parent_id TEXT);
        CREATE TABLE work_sessions(task_id TEXT,starts_at TEXT,ends_at TEXT,deleted_at TEXT);
        CREATE TABLE fixed_events(id TEXT,title TEXT,starts_at TEXT,ends_at TEXT,recurrence_kind TEXT,
          recurrence_interval INTEGER,recurrence_weekdays TEXT,recurrence_until TEXT,
          active_from_date TEXT,active_through_date TEXT,all_day INTEGER,deleted_at TEXT,category_id TEXT);
        CREATE TABLE event_occurrence_changes(event_id TEXT,nominal_date TEXT,cancelled INTEGER,payload_json TEXT);
        PRAGMA user_version=21;
        """;
            c.ExecuteNonQuery();
            var start = new DateTimeOffset(2026, 10, 26, 10, 0, 0, DateTimeOffset.Now.Offset).ToUniversalTime();
            c.CommandText = """
        INSERT INTO fixed_events VALUES('daily','Recurring event',$start,$end,'daily',1,'',NULL,NULL,NULL,0,NULL,NULL);
        INSERT INTO event_occurrence_changes VALUES('daily','2026-10-27',1,NULL);
        INSERT INTO event_occurrence_changes VALUES('daily','2026-10-28',0,$payload);
        """;
            c.Parameters.AddWithValue("$start", start.ToString("O")); c.Parameters.AddWithValue("$end", start.AddHours(1).ToString("O"));
            c.Parameters.AddWithValue("$payload", System.Text.Json.JsonSerializer.Serialize(new { title = "Moved event", startsAt = start.AddDays(4).ToString("O"), endsAt = start.AddDays(4).AddHours(1).ToString("O") }));
            c.ExecuteNonQuery();
        }
        using (var repo = LifeManagerWidgetRepository.OpenForTest(file))
        {
            var date = new DateTime(2026, 10, 26);
            var id = repo.AddTask("Planned task", date);
            using (var connection = new SqliteConnection($"Data Source={file};Pooling=False"))
            {
                connection.Open(); using var command = connection.CreateCommand();
                var start = new DateTimeOffset(2026, 10, 26, 9, 0, 0, DateTimeOffset.Now.Offset).ToUniversalTime();
                command.CommandText = "INSERT INTO work_sessions VALUES($task,$start,$end,NULL)";
                command.Parameters.AddWithValue("$task", id); command.Parameters.AddWithValue("$start", start.ToString("O")); command.Parameters.AddWithValue("$end", start.AddMinutes(30).ToString("O"));
                command.ExecuteNonQuery();
                command.Parameters.Clear();
                command.CommandText = "INSERT INTO event_occurrence_changes VALUES('daily','2026-10-29',1,$payload)";
                command.Parameters.AddWithValue("$payload", System.Text.Json.JsonSerializer.Serialize(new { title = "Cancelled moved event", startsAt = start.AddDays(5).ToString("O"), endsAt = start.AddDays(5).AddHours(1).ToString("O") }));
                command.ExecuteNonQuery();
            }
            var list = repo.LoadCalendarItems(date, date.AddDays(7));
            Require(list.Count(i => i.Kind == "Task" && i.TaskId == id) == 1, "Planned task not projected independently.");
            Require(list.Any(i => i.Day == date.AddDays(1) && i.Cancelled), "Cancelled recurrence disappeared.");
            Require(!list.Any(i => i.Day == date.AddDays(2) && i.Kind == "Event"), "Moved occurrence duplicated its nominal date.");
            Require(list.Any(i => i.Day == date.AddDays(4) && i.Title == "Moved event"), "Moved occurrence was not loaded.");
            Require(list.Count(i => i.Kind == "Event") == 7, "Event recurrence range incorrect.");
            Require(list.Any(i => i.Day == date.AddDays(5) && i.Cancelled && i.Title == "Cancelled moved event"), "Cancelling a moved event reverted its date/title.");
            Require(!list.Any(i => i.Day == date.AddDays(3) && i.Kind == "Event"), "Cancelled moved occurrence duplicated its nominal date.");
            Require(list.Where(i => i.Day == date && i.Kind != "Task").Select(i => i.Kind).SequenceEqual(new[] { "Session", "Event" }), "Agenda did not sort scheduled instants chronologically.");
            Directory.CreateDirectory(AppDataPaths.ActiveDirectory);
            File.WriteAllText(Path.Combine(AppDataPaths.ActiveDirectory,"appearance-settings.json"),"{\"firstWeekday\":\"invalid\"}");
            File.WriteAllText(Path.Combine(AppDataPaths.ActiveDirectory,"calendar-settings.json"),"{interrupted");
            using(var image=NativeDesktopWidgetHost.RenderPreview(repo,new WidgetConfiguration(),true,new Size(300,360),WidgetPalette.Dark)) {
                Require(image.Width==300,"Invalid optional calendar preferences blocked rendering.");
            }
            var transparent = new WidgetConfiguration();
            transparent.Surface("shell").Opacity = 0;
            using (var image = NativeDesktopWidgetHost.RenderPreview(repo, transparent, false, new Size(376, 460), WidgetPalette.Dark))
            {
                Require(image.GetPixel(10, 150).A <= 1, "Shell opacity affected an unrelated surface.");
                Require(image.GetPixel(20, 150).A == 255, "Content panel did not retain independent opacity.");
            }
            var whiteShell = new WidgetConfiguration(); whiteShell.Surface("shell").Color = "#FFFFFF";
            using (var image = NativeDesktopWidgetHost.RenderPreview(repo, whiteShell, false, new Size(376, 460), WidgetPalette.Dark))
            {
                var darkPixels = 0;
                for (var y = 16; y < 42; y++) for (var x = 16; x < 125; x++) { var pixel = image.GetPixel(x, y); if (pixel.R < 80 && pixel.G < 80 && pixel.B < 80) darkPixels++; }
                Require(darkPixels > 20, "Header text did not adapt to a light custom shell.");
            }
            foreach (var position in new[] { "top", "left", "right", "bottom" }) foreach (var mode in new[] { "text", "icons", "both" }) foreach (var header in new[] { true, false })
            {
                var config = new WidgetConfiguration { NavigationPosition = position, NavigationDisplay = mode, ShowTitle = header, ShowOpenButton = header };
                using var image = NativeDesktopWidgetHost.RenderPreview(repo, config, false, new Size(260, 230), WidgetPalette.Dark);
            }
            foreach (var calendar in new[] { false, true }) foreach (var position in new[] { "top", "left", "right", "bottom" }) foreach (var mode in new[] { "text", "icons", "both" })
            {
                var config = new WidgetConfiguration { TextScale = 1.6f, NavigationPosition = position, NavigationDisplay = mode };
                using var image = NativeDesktopWidgetHost.RenderPreview(repo, config, calendar, WidgetGeometry.MinimumSize(calendar, 1.6f), WidgetPalette.Dark);
            }
            foreach (var scale in new[] { 1f, 1.25f, 1.5f, 2f }) foreach (var light in new[] { false, true })
            {
                using var image = NativeDesktopWidgetHost.RenderPreview(repo, new WidgetConfiguration(), true, new Size(300, 360), light ? WidgetPalette.Light : WidgetPalette.Dark, scale);
            }

        }
    }
}

internal sealed class WidgetTestProfile : IDisposable
{
    private readonly string? roaming = Environment.GetEnvironmentVariable("APPDATA");
    private readonly string? local = Environment.GetEnvironmentVariable("LOCALAPPDATA");
    internal WidgetTestProfile(string directory)
    {
        Directory.CreateDirectory(directory);
        Environment.SetEnvironmentVariable("APPDATA", Path.GetFullPath(directory));
        Environment.SetEnvironmentVariable("LOCALAPPDATA", Path.Combine(Path.GetFullPath(directory), "local"));
    }
    public void Dispose()
    {
        Environment.SetEnvironmentVariable("APPDATA", roaming);
        Environment.SetEnvironmentVariable("LOCALAPPDATA", local);
    }
}
