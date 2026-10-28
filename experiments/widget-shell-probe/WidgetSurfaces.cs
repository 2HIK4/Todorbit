using System.Diagnostics;
using System.Drawing.Drawing2D;

internal sealed partial class NativeDesktopWidgetHost
{
    internal void ReloadConfiguration()
    {
        configuration = WidgetConfiguration.Load(calendar, settings);
        RestorePreviewIfActive();
        quickAdd?.Close();
        Reposition();
        RefreshTasks();
    }
    private void OpenWidgetSettings()
    {
        RunAction(() =>
        {
            Process.Start(WidgetSettingsActivation(ResolveMainApp(), calendar));
        });
    }
    internal static ProcessStartInfo WidgetSettingsActivation(string executable, bool calendar)
    {
        var start = new ProcessStartInfo(executable) { UseShellExecute = false };
        start.ArgumentList.Add("--edit-widget"); start.ArgumentList.Add(calendar ? "calendar" : "tasks");
        return start;
    }
    private void PaintSurface(Graphics graphics, string name, RectangleF bounds, Color fallback, Color? borderFallback = null)
    {
        var surface = configuration.Surface(name);
        var fill = surface.Resolve(fallback);
        // One alpha step retains right-click/move hit testing on a transparent shell.
        if (name == "shell" && fill.A == 0) fill = Color.FromArgb(1, fill);
        using var brush = new SolidBrush(fill);
        FillRoundedRectangle(graphics, brush, bounds, surface.Radius);
        if (surface.Border && surface.Thickness > 0)
        {
            var thickness = float.IsFinite(surface.Thickness) ? Math.Clamp(surface.Thickness, 0, 8) : 1;
            using var pen = new Pen(surface.Resolve(borderFallback ?? palette.Border, true), thickness);
            // Keep the entire stroke inside its surface at all DPI scales.
            bounds.Inflate(-thickness / 2, -thickness / 2);
            DrawRoundedRectangle(graphics, pen, bounds, float.IsFinite(surface.Radius) ? Math.Clamp(surface.Radius, 0, 32) : 8);
        }
    }
    private Color SurfaceText(string name, bool secondary = false)
    {
        var s = configuration.Surface(name);
        var hex = secondary ? s.PlaceholderColor : s.TextColor;
        var candidate = hex != null && System.Text.RegularExpressions.Regex.IsMatch(hex, "^#[0-9a-fA-F]{6}$") ? ColorTranslator.FromHtml(hex) : secondary ? palette.Muted : palette.Foreground;
        var fill = ComposedSurface(name);
        var background = Blend(palette.Background, fill, fill.A / 255f);
        // Explicit text colors/alpha are independent from surface opacity.
        if (hex == null && name == "selectedNavigation") candidate = WidgetEditorStyle.OnAccent(palette);
        if (hex == null && WidgetEditorStyle.Contrast(candidate, background) < 4.5)
          candidate = WidgetEditorStyle.Contrast(Color.Black, background) > WidgetEditorStyle.Contrast(Color.White, background) ? Color.Black : Color.White;
        return Color.FromArgb((int)Math.Round(s.TextOpacity * 2.55), candidate);
    }
    private static HitTarget ViewTarget(WidgetTaskView view) => view switch
    {
        WidgetTaskView.Today => HitTarget.ViewToday,
        WidgetTaskView.Inbox => HitTarget.ViewInbox,
        WidgetTaskView.All => HitTarget.ViewAll,
        _ => HitTarget.ViewUpcoming,
    };
    private static void DrawViewIcon(Graphics g, WidgetTaskView view, RectangleF b, Color color)
    {
        using var p = new Pen(color, 1.6f) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
        if (view is WidgetTaskView.Today or WidgetTaskView.Upcoming)
        {
            g.DrawRectangle(p, b.X + 1, b.Y + 3, b.Width - 2, b.Height - 4);
            g.DrawLine(p, b.X + 1, b.Y + 7, b.Right - 1, b.Y + 7);
            g.DrawLine(p, b.X + 5, b.Y + 1, b.X + 5, b.Y + 4); g.DrawLine(p, b.Right - 5, b.Y + 1, b.Right - 5, b.Y + 4);
            if (view == WidgetTaskView.Upcoming) g.DrawLines(p, new PointF[] { new(b.X + 6, b.Y + 9), new(b.X + 10, b.Y + 11), new(b.X + 6, b.Y + 13) });
            else g.DrawRectangle(p, b.X + 6, b.Y + 10, 3, 3);
        }
        else if (view == WidgetTaskView.Inbox)
        {
            g.DrawLines(p, new PointF[] { new(b.X + 1, b.Y + 4), new(b.Right - 1, b.Y + 4), new(b.Right - 1, b.Bottom - 2), new(b.X + 1, b.Bottom - 2), new(b.X + 1, b.Y + 4) });
            g.DrawLines(p, new PointF[] { new(b.X + 1, b.Y + 10), new(b.X + 5, b.Y + 10), new(b.X + 7, b.Y + 12), new(b.X + 10, b.Y + 12), new(b.X + 12, b.Y + 10), new(b.Right - 1, b.Y + 10) });
        }
        else
        {
            for (var i = 0; i < 3; i++) { g.DrawRectangle(p, b.X + 1, b.Y + 2 + i * 5, 2, 2); g.DrawLine(p, b.X + 6, b.Y + 3 + i * 5, b.Right - 1, b.Y + 3 + i * 5); }
        }
    }
}
