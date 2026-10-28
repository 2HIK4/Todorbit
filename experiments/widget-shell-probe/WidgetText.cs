internal sealed partial class NativeDesktopWidgetHost
{
    private Color ComposedSurface(string name)
    {
        if (name == "opaque") return palette.Row;
        var result = Color.Transparent;
        void Add(string key, Color fallback)
        {
            var top = configuration.Surface(key).Resolve(fallback);
            var ta = top.A / 255d; var ba = result.A / 255d; var alpha = ta + ba * (1 - ta);
            if (alpha <= 0) { result = Color.Transparent; return; }
            int Mix(int t, int b) => (int)Math.Round((t * ta + b * ba * (1 - ta)) / alpha);
            result = Color.FromArgb((int)Math.Round(alpha * 255), Mix(top.R, result.R), Mix(top.G, result.G), Mix(top.B, result.B));
        }
        Add("shell", palette.Background);
        if (name == "shell") return result;
        if (name is "calendarCell" or "selectedDate" or "selectedToday" or "today") Add("content", palette.Panel);
        if (name is "selectedDate" or "selectedToday" or "today") Add("calendarCell", palette.Panel);
        if (name is "navigationButton" or "selectedNavigation") Add("navigation", palette.Background);
        if (name == "selectedToday") { Add("selectedDate", palette.Accent); Add("today", palette.Accent); }
        else Add(name, name is "selectedDate" or "today" or "selectedNavigation" ? palette.Accent : name is "header" or "navigation" ? palette.Background : palette.Panel);
        return result;
    }
    private bool NeedsTextBacking(string surface, Color candidate)
    {
        var composed = ComposedSurface(surface);
        var onDark = Blend(Color.Black, composed, composed.A / 255f);
        var onLight = Blend(Color.White, composed, composed.A / 255f);
        return composed.A < 90 || WidgetEditorStyle.Contrast(candidate, onDark) < 4.5 || WidgetEditorStyle.Contrast(candidate, onLight) < 4.5;
    }
    private void DrawText(Graphics graphics, string text, Font font, Brush ink,
        RectangleF bounds, StringFormat? format = null, string surface = "content")
    {
        var candidate = ink is SolidBrush solid ? solid.Color : palette.Foreground;
        var needsBacking = NeedsTextBacking(surface, candidate);
        if (!configuration.ProtectText || !needsBacking || surface == "opaque")
        {
            if (format == null) graphics.DrawString(text, font, ink, bounds);
            else graphics.DrawString(text, font, ink, bounds, format);
            return;
        }
        // A restrained halo follows the glyphs instead of painting opaque label
        // rectangles. Surface opacity stays exactly as configured.
        using var defaultFormat = new StringFormat();
        var actual = format ?? defaultFormat;
        var foreground = ink is SolidBrush brush ? brush.Color : palette.Foreground;
        var haloColor = WidgetEditorStyle.Contrast(foreground, Color.Black) >= WidgetEditorStyle.Contrast(foreground, Color.White) ? Color.Black : Color.White;
        using var halo = new SolidBrush(Color.FromArgb((int)(180 * candidate.A / 255f), haloColor));
        foreach (var offset in new[] { new PointF(-1, 0), new PointF(1, 0), new PointF(0, -1), new PointF(0, 1) })
        {
            var shadow = bounds; shadow.Offset(offset);
            graphics.DrawString(text, font, halo, shadow, actual);
        }
        using var readable = new SolidBrush(foreground);
        graphics.DrawString(text, font, readable, bounds, actual);
    }
}
