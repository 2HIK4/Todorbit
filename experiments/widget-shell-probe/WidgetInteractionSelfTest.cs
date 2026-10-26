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
    }
}
