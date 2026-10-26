using System.Drawing.Drawing2D;

internal sealed partial class NativeDesktopWidgetHost
{
    private Size? previewSize;
    private NativeDesktopWidgetHost(LifeManagerWidgetRepository repository,
        WidgetConfiguration configuration, bool calendar, Size size, WidgetPalette palette)
    {
        this.repository = repository; this.configuration = configuration; this.calendar = calendar;
        this.palette = palette; settings = new WidgetSettings(); settingsStore = new WidgetSettingsStore();
        diagnostics = new WidgetRenderDiagnostics(false); unexpectedDestroy = () => { }; exit = () => { };
        previewSize = size;
        if (calendar) LoadCalendar(); else tasks = repository.LoadTasks(DateTime.Today);
    }
    /// Offscreen renderer: no HWND, Explorer attachment, focus or startup registration.
    internal static Bitmap RenderPreview(LifeManagerWidgetRepository repository,
        WidgetConfiguration config, bool calendar, Size size, WidgetPalette palette, float scale = 1)
    {
        using var host = new NativeDesktopWidgetHost(repository, config, calendar, size, palette);
        host.ValidateLayout();
        var bitmap = new Bitmap((int)(size.Width * scale), (int)(size.Height * scale), System.Drawing.Imaging.PixelFormat.Format32bppPArgb);
        using var g = Graphics.FromImage(bitmap);
        g.Clear(Color.Transparent); g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        g.ScaleTransform(scale, scale);
        host.PaintSurface(g, "shell", new RectangleF(0.5f, 0.5f, size.Width - 1, size.Height - 1), palette.Background);
        host.DrawWidget(g);
        return bitmap;
    }
    private void ValidateLayout()
    {
        var client = new RectangleF(0, 0, LogicalClientWidth, LogicalClientHeight);
        if (calendar)
        {
            if (MonthToday.Bottom > CalendarGrid.Top - 20 || !client.Contains(AgendaRect))
                throw new InvalidOperationException("Calendar controls overlap or leave the widget.");
        }
        else
        {
            if (!client.Contains(TaskArea) || TaskArea.IntersectsWith(AddRect))
                throw new InvalidOperationException("Task content collides with Quick Add.");
            foreach (var view in VisibleViews) if (!client.Contains(ViewRect(view)) || ViewRect(view).IntersectsWith(AddRect) || ViewRect(view).IntersectsWith(TaskArea))
                throw new InvalidOperationException("Task navigation clips or overlaps content.");
            if (tasks.Count > 0 && !TaskArea.Contains(TaskRowRect(0)))
                throw new InvalidOperationException("Compact task row leaves the content panel.");
        }
    }
}
