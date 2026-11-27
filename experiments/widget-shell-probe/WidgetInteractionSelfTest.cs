internal static partial class LifeManagerWidgetSelfTest
{
    private static void CaptureTooltipPreviews(string output)
    {
        foreach (var scale in new[] { 1f, 1.25f, 1.5f, 2f })
        foreach (var light in new[] { false, true })
        {
            using var tooltip = new WidgetTooltipWindow();
            tooltip.Configure("Wednesday, 14 October 2026 · 3 scheduled items", light ? WidgetPalette.Light : WidgetPalette.Dark, scale, new Rectangle(0, 0, 1920, 1080));
            using var image = new Bitmap(tooltip.Width, tooltip.Height);
            tooltip.DrawToBitmap(image, tooltip.ClientRectangle);
            image.Save(Path.Combine(output, $"tooltip-{(light ? "light" : "dark")}-{scale * 100:0}.png"));
        }
    }

    private static void TestWidgetInteractions(string directory)
    {
        WidgetEdgeSnapSelfTest.Run();
        using var profile = new WidgetTestProfile(Path.Combine(directory, "interaction-profile"));
        var path = Path.Combine(directory, "interaction.sqlite");
        CreateDatabase(path);
        using var repository = LifeManagerWidgetRepository.OpenForTest(path);
        repository.AddTask("An interactive task", DateTime.Today);
        NativeDesktopWidgetHost.VerifyInteractionRegions(repository);
        var clamped = WidgetTooltip.Clamp(new Rectangle(990, 790, 220, 60), new Rectangle(0, 0, 1000, 800));
        Require(clamped.Right <= 1000 && clamped.Bottom <= 800, "Tooltip leaves the working area.");
        foreach (var scale in new[] { 1f, 1.25f, 1.5f, 2f })
        foreach (var light in new[] { false, true })
        {
            using var tooltip = new WidgetTooltipWindow();
            var palette = light ? WidgetPalette.Light : WidgetPalette.Dark;
            tooltip.Configure("Wednesday, 14 October 2026 · 3 scheduled items", palette, scale, new Rectangle(0, 0, 1920, 1080));
            Require(tooltip.Region != null && !tooltip.Region.IsVisible(0, 0) && tooltip.Region.IsVisible(tooltip.Width / 2, tooltip.Height / 2), "Tooltip corners are not rounded.");
            Require(tooltip.Height >= 26 * scale && tooltip.Width <= 350 * scale, "Tooltip text or padding does not follow the owner DPI.");
            using var image = new Bitmap(tooltip.Width, tooltip.Height);
            tooltip.DrawToBitmap(image, tooltip.ClientRectangle);
            Require(image.GetPixel(tooltip.Width / 2, 3).ToArgb() == palette.Panel.ToArgb(), "Tooltip surface does not follow the active theme.");
            var style = Native.GetWindowLongPtr(tooltip.Handle, -20).ToInt64();
            Require((style & 0x08000020) == 0x08000020, "Tooltip can activate or intercept pointer input.");
        }
    }
}

internal sealed partial class NativeDesktopWidgetHost
{
    internal static void VerifyInteractionRegions(LifeManagerWidgetRepository repository)
    {
        foreach (var position in new[] { "top", "left", "right", "bottom" })
        foreach (var title in new[] { false, true })
        {
            var config = new WidgetConfiguration { NavigationPosition = position, ShowTitle = title, ShowOpenButton = title };
            using var host = new NativeDesktopWidgetHost(repository, config, false, new Size(376, 460), WidgetPalette.Dark);
            static PointF Center(RectangleF bounds) => new(bounds.X + bounds.Width / 2, bounds.Y + bounds.Height / 2);
            if (host.HitTest(Center(host.AddRect)).Target != HitTarget.Add ||
                host.HitTest(Center(host.ViewRect(WidgetTaskView.Today))).Target != HitTarget.ViewToday ||
                host.HitTest(Center(host.TaskRowRect(0))).Target != HitTarget.TaskRow ||
                host.HitTest(Center(host.CheckboxRect(0))).Target != HitTarget.TaskCheckbox)
                throw new InvalidOperationException("An interactive task region can initiate dragging.");
            if (host.HitTest(new PointF(host.TaskArea.X + 2, host.TaskArea.Bottom - 8)).Target != HitTarget.None)
                throw new InvalidOperationException("Unoccupied content background cannot be dragged.");
        }

        var saved = new WidgetConfiguration { ShowTitle = false, LayoutLocked = true };
        saved.Surface("shell").Opacity = 80; saved.Save(false);
        var preview = WidgetConfiguration.Load(false, new WidgetSettings());
        preview.TextScale = 1.6f; preview.Surface("shell").Opacity = 17;
        preview.ShowTitle = true; preview.ShowOpenButton = false;
        using var editorHost = new NativeDesktopWidgetHost(repository, preview, false, new Size(376, 460), WidgetPalette.Dark);
        using var menu = editorHost.CreateContextMenu();
        var titleItem = menu.Items.OfType<ToolStripMenuItem>().Single(i => i.Text == "Show Title");
        var openItem = menu.Items.OfType<ToolStripMenuItem>().Single(i => i.Text == "Show Open App Button");
        var lockItem = menu.Items.OfType<ToolStripMenuItem>().Single(i => i.Text == "Lock Layout");
        if (!menu.ShowCheckMargin || titleItem.Checked || !openItem.Checked || !lockItem.Checked ||
            menu.Items.OfType<ToolStripMenuItem>().Single(i => i.Text == "Move widget to center").Enabled)
            throw new InvalidOperationException("Context-menu checks or disabled layout commands do not match their settings.");
        titleItem.PerformClick();
        var after = WidgetConfiguration.Load(false, new WidgetSettings());
        if (!after.ShowTitle || after.TextScale != 1 || after.Surface("shell").Opacity != 80)
            throw new InvalidOperationException("A context-menu toggle persisted an unrelated unsaved preview.");

        var transparent = new WidgetConfiguration();
        foreach (var layer in transparent.Surfaces.Values) layer.Opacity = 0;
        using var textHost = new NativeDesktopWidgetHost(repository, transparent, false, new Size(376, 460), WidgetPalette.Dark);
        using var image = new Bitmap(160, 44);
        using var graphics = Graphics.FromImage(image);
        using var font = new Font("Segoe UI", 13, FontStyle.Regular, GraphicsUnit.Pixel);
        using var ink = new SolidBrush(WidgetPalette.Dark.Foreground);
        graphics.Clear(Color.Transparent);
        textHost.DrawText(graphics, "Wednesday", font, ink, new RectangleF(8, 8, 140, 28), surface: "shell");
        if (image.GetPixel(8, 8).A != 0)
            throw new InvalidOperationException("Text protection painted an opaque label rectangle.");

        // Light theme translucent selectedNavigation & selectedToday must pick white ink on dark teal accent, not black ink.
        var lightTranslucent = new WidgetConfiguration();
        lightTranslucent.Surface("shell").Opacity = 20;
        lightTranslucent.Surface("content").Opacity = 35;
        lightTranslucent.Surface("selectedNavigation").Opacity = 30;
        lightTranslucent.Surface("selectedDate").Opacity = 30;
        using var lightHost = new NativeDesktopWidgetHost(repository, lightTranslucent, false, new Size(376, 460), WidgetPalette.Light);
        var navInk = lightHost.SurfaceText("selectedNavigation");
        var dateInk = lightHost.SurfaceText("selectedToday");
        if (lightTranslucent.Surfaces.ContainsKey("selectedToday"))
            throw new InvalidOperationException("SurfaceText(\"selectedToday\") mutated configuration.Surfaces.");
        if (navInk.R < 220 || navInk.G < 220 || navInk.B < 220 || dateInk.R < 220 || dateInk.G < 220 || dateInk.B < 220)
            throw new InvalidOperationException("Light theme translucent accent surface selected dark text instead of crisp white.");

        // Ultra-low (5%) accent opacity on translucent Light underlay must not falsely force opaque accent white text.
        lightTranslucent.Surface("selectedNavigation").Opacity = 5;
        var lowOpacityNav = lightHost.SurfaceText("selectedNavigation");
        if (lowOpacityNav.R > 80 || lowOpacityNav.G > 80 || lowOpacityNav.B > 80)
            throw new InvalidOperationException("5% accent opacity override wrongly selected white text on translucent light surface.");

        // Continuous pixel scrolling on Tasks widget: fractional wheel deltas scroll smoothly & clip hit testing.
        for (var i = 0; i < 16; i++) repository.AddTask($"Scrollable task {i}", DateTime.Today);
        using var scrollHost = new NativeDesktopWidgetHost(repository, new WidgetConfiguration(), false, new Size(376, 460), WidgetPalette.Dark);
        if (scrollHost.MaxTaskScrollPixels <= 0)
            throw new InvalidOperationException("Expected populated task list to overflow viewport.");
        scrollHost.ScrollWheelAt(new PointF(scrollHost.TaskArea.X + 20, scrollHost.TaskArea.Y + 20), -30, scrollLinesOverride: 3, reducedMotionOverride: true);
        if (Math.Abs(scrollHost.taskScrollPixels - 12f) > 0.1f)
            throw new InvalidOperationException($"Expected 12px continuous scroll on delta=-30 (3 lines), got {scrollHost.taskScrollPixels}.");
        // Verify custom OS MouseWheelScrollLines (1 line and -1 page scroll)
        scrollHost.ScrollWheelAt(new PointF(scrollHost.TaskArea.X + 20, scrollHost.TaskArea.Y + 20), -120, scrollLinesOverride: 1, reducedMotionOverride: true);
        if (Math.Abs(scrollHost.taskScrollPixels - 28f) > 0.1f)
            throw new InvalidOperationException($"Expected +16px on 1-line OS wheel preference, got {scrollHost.taskScrollPixels}.");
        // Task 0 is partially scrolled above TaskViewport.Top; hitting above TaskViewport.Top must never hit Task 0.
        var aboveViewport = new PointF(scrollHost.TaskArea.X + 40, scrollHost.TaskArea.Y + 1);
        if (scrollHost.HitTest(aboveViewport).Target == HitTarget.TaskRow)
            throw new InvalidOperationException("Clipped task row above TaskViewport leaked hit testing.");

        // Partially visible row (< 4px remaining in viewport) + focus ring must never throw ArgumentException.
        var tinyClipOffset = scrollHost.TaskRowRect(0).Height - 2f + 28f;
        scrollHost.ScrollByPixels(tinyClipOffset);
        using (var focusBmp = new Bitmap(376, 460))
        using (var focusG = Graphics.FromImage(focusBmp))
        {
            var smallBounds = new RectangleF(10, 10, 100, 2);
            DrawRoundedRectangle(focusG, Pens.White, smallBounds, 4);
            var actions = scrollHost.AccessibleActions();
            if (actions.Count < 16)
                throw new InvalidOperationException("Offscreen task items must remain reachable in AccessibleActions.");
        }

        // Scroll to bottom, then verify SetView resets scroll to top cleanly.
        scrollHost.ScrollByPixels(10000f);
        if (Math.Abs(scrollHost.taskScrollPixels - scrollHost.MaxTaskScrollPixels) > 0.5f)
            throw new InvalidOperationException("Task scroll did not clamp cleanly to MaxTaskScrollPixels.");
        scrollHost.SetView(WidgetTaskView.All);
        if (scrollHost.taskScrollPixels != 0f)
            throw new InvalidOperationException("SetView did not reset continuous task scroll to 0.");

        // Offscreen UIA/Tab focus must scroll the target row into TaskViewport.
        scrollHost.SetView(WidgetTaskView.Today);
        scrollHost.ScrollTaskRowIntoView(scrollHost.tasks.Count - 1);
        var lastRow = scrollHost.TaskRowRect(scrollHost.tasks.Count - 1);
        if (lastRow.Bottom > scrollHost.TaskViewport.Bottom + 0.5f)
            throw new InvalidOperationException("ScrollTaskRowIntoView failed to bring offscreen row into viewport.");
    }
}

internal static partial class LifeManagerWidgetSelfTest
{
    internal static void RunScrollBenchmark()
    {
        var tempRoot = Path.Combine(Path.GetTempPath(), "todorbit-scroll-bench-" + Guid.NewGuid());
        Directory.CreateDirectory(tempRoot);
        try
        {
            var dbPath = Path.Combine(tempRoot, "bench.sqlite");
            CreateDatabase(dbPath);
            using var repo = LifeManagerWidgetRepository.OpenForTest(dbPath);
            for (var i = 0; i < 60; i++) repo.AddTask($"Benchmark task {i:00}", DateTime.Today);

            // Measure offscreen continuous scroll frame cost across 60 frames
            var sw = System.Diagnostics.Stopwatch.StartNew();
            var hostConfig = new WidgetConfiguration();
            for (var frame = 0; frame < 60; frame++)
            {
                using var bmp = NativeDesktopWidgetHost.RenderPreview(repo, hostConfig, false, new Size(376, 460), WidgetPalette.Dark, 1f);
            }
            sw.Stop();
            var avgFrameMs = sw.Elapsed.TotalMilliseconds / 60.0;

            // Measure live host wheel responsiveness & idle timer behavior (WindowsFormsSynchronizationContext)
            using var profile = new WidgetTestProfile(Path.Combine(tempRoot, "profile"));
            var settingsStore = new WidgetSettingsStore();
            var settings = new WidgetSettings { View = WidgetTaskView.Today };
            NativeDesktopWidgetHost? liveHost = null;
            try
            {
                liveHost = new NativeDesktopWidgetHost(repo, null, WidgetPalette.Dark, settings, settingsStore, diagnosticsEnabled: true, unexpectedDestroy: () => { }, exit: () => { });
            }
            catch (InvalidOperationException)
            {
                liveHost = null;
            }
            var timerField = typeof(NativeDesktopWidgetHost).GetField("scrollAnimationTimer", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
            var proc = System.Diagnostics.Process.GetCurrentProcess();
            var cpuBefore = proc.TotalProcessorTime;
            if (liveHost != null)
            {
                var timer = (System.Windows.Forms.Timer?)timerField!.GetValue(liveHost);
                var wheelPos = new PointF(180f, 220f);
                var paintsBefore = liveHost.PaintCount;
                // Smooth wheel scroll (animated on HWND)
                liveHost.ScrollWheelAt(wheelPos, -120, scrollLinesOverride: 3, reducedMotionOverride: false);
                var activeDuringScroll = timer?.Enabled == true;
                var settleSw = System.Diagnostics.Stopwatch.StartNew();
                while (timer?.Enabled == true && settleSw.ElapsedMilliseconds < 2000)
                {
                    Application.DoEvents();
                    Thread.Sleep(4);
                }
                settleSw.Stop();
                var paintsDuringScroll = liveHost.PaintCount - paintsBefore;
                var idleAfterSettle = timer?.Enabled == false;
                var paintsAtSettle = liveHost.PaintCount;
                Thread.Sleep(250);
                Application.DoEvents();
                var idlePaints250ms = liveHost.PaintCount - paintsAtSettle;
                var stillIdle = timer?.Enabled == false;
                var cpuDeltaMs = (proc.TotalProcessorTime - cpuBefore).TotalMilliseconds;
                var memMb = proc.WorkingSet64 / (1024.0 * 1024.0);
                Console.WriteLine($"LIVE_HWND_SCROLL: avg_preview_frame_ms={avgFrameMs:F2} active_during_scroll={activeDuringScroll} settle_ms={settleSw.ElapsedMilliseconds} paints_during_scroll={paintsDuringScroll} idle_after_settle={idleAfterSettle} still_idle_250ms={stillIdle} idle_paints_250ms={idlePaints250ms} cpu_ms={cpuDeltaMs:F2} working_set_mb={memMb:F1}");
                liveHost.Dispose();
                if (!activeDuringScroll || !idleAfterSettle || !stillIdle || idlePaints250ms != 0)
                    throw new InvalidOperationException($"Live HWND scroll timer/idle check failed: idlePaints250ms={idlePaints250ms}");
            }
            else
            {
                Console.WriteLine($"OFFSCREEN_SCROLL_ONLY: avg_preview_frame_ms={avgFrameMs:F2} working_set_mb={proc.WorkingSet64 / (1024.0 * 1024.0):F1}");
            }
        }
        finally
        {
            Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
            Directory.Delete(tempRoot, true);
        }
    }
}
