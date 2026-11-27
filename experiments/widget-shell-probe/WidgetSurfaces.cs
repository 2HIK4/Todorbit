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
        var s = configuration.Surface(name == "selectedToday" ? "selectedDate" : name);
        var hex = secondary ? s.PlaceholderColor : s.TextColor;
        var candidate = hex != null && System.Text.RegularExpressions.Regex.IsMatch(hex, "^#[0-9a-fA-F]{6}$") ? ColorTranslator.FromHtml(hex) : secondary ? palette.Muted : palette.Foreground;
        var fill = ComposedSurface(name);
        var background = Blend(palette.Background, fill, fill.A / 255f);
        if (name is "selectedNavigation" or "selectedDate" or "selectedToday" or "today")
        {
            // When an accent control sits on a translucent widget, do not wash its own hue out
            // with palette.Background (white in Light theme) before picking foreground contrast.
            var underlay = ComposedSurface(name == "selectedNavigation" ? "navigation" : "calendarCell");
            Color ownSurface;
            double ownAlpha;
            if (name == "selectedToday")
            {
                var sd = configuration.Surface("selectedDate").Resolve(palette.Accent);
                var td = configuration.Surface("today").Resolve(palette.Accent);
                var sa = sd.A / 255d;
                var ta = td.A / 255d;
                ownAlpha = sa + ta * (1d - sa);
                ownSurface = td.A > 0 ? Blend(sd, td, td.A / 255f) : sd;
            }
            else
            {
                ownSurface = s.Resolve(palette.Accent);
                ownAlpha = ownSurface.A / 255d;
            }
            // Do not insert a synthetic "selectedToday" key into configuration.Surfaces,
            // and only override on meaningful own opacity (>= ~25%) over a translucent underlay.
            if (underlay.A < 180 && ownAlpha >= 0.25d)
            {
                background = Color.FromArgb(255, ownSurface);
            }
        }
        // Explicit text colors/alpha are independent from surface opacity.
        // Choose once against the composed surface, rather than first choosing
        // against opaque accent and then conditionally correcting that choice.
        if (hex == null && name == "selectedNavigation")
          candidate = WidgetEditorStyle.Contrast(Color.Black, background) >= WidgetEditorStyle.Contrast(Color.White, background) ? Color.Black : Color.White;
        else if (hex == null && WidgetEditorStyle.Contrast(candidate, background) < 4.5)
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
