using Microsoft.Data.Sqlite;

internal static partial class LifeManagerWidgetSelfTest
{
    /// Actual HWND lifecycle using disposable data. No simulated mouse/keyboard input.
    internal static bool TestWidgetLifecycle()
    {
        var root = Path.Combine(Path.GetTempPath(), "todorbit-lifecycle-" + Guid.NewGuid());
        Directory.CreateDirectory(root);
        using var profile = new WidgetTestProfile(root);
        try
        {
            TestCalendarProjection(root);
            Directory.CreateDirectory(AppDataPaths.ActiveDirectory);
            var target = Path.Combine(AppDataPaths.ActiveDirectory, "life_manager.sqlite");
            File.Copy(Path.Combine(root, "calendar-projection.sqlite"), target);
            using var repository = LifeManagerWidgetRepository.OpenForTest(target);
            using (var context = new NativeWidgetApplicationContext(repository, null, false, "background"))
            {
                Require(context.VisibleWidgets == (false, false), "Background startup unexpectedly showed a widget.");
                context.ExecuteCommand("show");
                context.ExecuteCommand("calendar-show");
                if (context.VisibleWidgets != (true, true))
                {
                    Console.WriteLine("Lifecycle check unavailable: this session could not attach both Explorer child windows.");
                    return false;
                }
                TestLivePreviewRouting(context);
                context.ExecuteCommand("hide");
                Require(context.VisibleWidgets == (false, true), "Hiding Tasks also hid Calendar.");
                context.ExecuteCommand("calendar-hide");
                Require(context.VisibleWidgets == (false, false), "Calendar hide left a visible widget.");
                context.ExecuteCommand("calendar-show");
                WidgetConfiguration.Update(true, new WidgetSettings(), c => { c.ShowTitle = false; c.ShowOpenButton = false; });
                context.ExecuteCommand("reload-configuration");
                Require(context.VisibleWidgets == (false, true), "Reload changed independent visibility.");
            }
            Application.DoEvents();
            using (var reopened = new NativeWidgetApplicationContext(repository, null, false, "restore"))
            {
                Require(reopened.VisibleWidgets == (false, true), "Restart did not restore independent visibility.");
                reopened.ExecuteCommand("show");
                Require(reopened.VisibleWidgets == (true, true), "Tasks could not be reopened beside Calendar.");
            }
            Console.WriteLine("Two-widget native lifecycle passed: simultaneous HWNDs, independent hide/show, reload and restart. Physical input/Win+D/DPI are not tested.");
            return true;
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            Directory.Delete(root, true);
        }
    }

    private static void TestLivePreviewRouting(NativeWidgetApplicationContext context)
    {
        var options = new System.Text.Json.JsonSerializerOptions {
            PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase,
        };
        var path = WidgetConfiguration.PathFor(true);
        var savedBytes = File.ReadAllBytes(path);
        var saved = WidgetConfiguration.Load(true, new WidgetSettings());
        var draft = WidgetConfiguration.Parse(System.Text.Json.JsonSerializer.Serialize(saved, options));
        draft.CalendarPresentation = "fullMonth";
        draft.ShowTitle = !saved.ShowTitle;
        draft.Surface("shell").Opacity = 36;
        var session = Guid.NewGuid().ToString();
        string Command(long sequence, bool end = false) => "preview-configuration " +
            System.Text.Json.JsonSerializer.Serialize(new {
                session, sequence, end, kind = "calendar", baseline = saved, configuration = draft,
            }, options);
        WidgetConfiguration Displayed(string field)
        {
            var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic;
            var host = typeof(NativeWidgetApplicationContext).GetField(field, flags)!.GetValue(context)!;
            return (WidgetConfiguration)typeof(NativeDesktopWidgetHost).GetField("configuration", flags)!.GetValue(host)!;
        }
        var tasksTitle = Displayed("host").ShowTitle;
        context.ExecuteCommand(Command(1));
        Require(Displayed("calendarHost").CalendarPresentation == "fullMonth" &&
            Displayed("calendarHost").Surface("shell").Opacity == 36,
            "Live draft did not reach the actual Calendar HWND");
        Require(Displayed("host").ShowTitle == tasksTitle, "Calendar preview changed Tasks");
        Require(File.ReadAllBytes(path).SequenceEqual(savedBytes), "Preview wrote saved configuration");
        context.ExecuteCommand(Command(2, true));
        Require(Displayed("calendarHost").ShowTitle == saved.ShowTitle &&
            Displayed("calendarHost").CalendarPresentation == saved.CalendarPresentation,
            "Rollback did not restore actual Calendar HWND settings");
        context.ExecuteCommand(Command(3));
        Require(Displayed("calendarHost").CalendarPresentation == saved.CalendarPresentation,
            "Delayed preview revived a cancelled session");
    }
}
