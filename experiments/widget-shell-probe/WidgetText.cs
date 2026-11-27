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
        if (name is "taskRow" or "calendarCell" or "selectedDate" or "selectedToday" or "today") Add("content", palette.Panel);
        if (name is "selectedDate" or "selectedToday" or "today") Add("calendarCell", palette.Panel);
        if (name is "navigationButton" or "selectedNavigation") Add("navigation", palette.Background);
        if (name == "selectedToday") { Add("selectedDate", palette.Accent); Add("today", palette.Accent); }
        else Add(name, name == "taskRow" ? palette.Row : name is "selectedDate" or "today" or "selectedNavigation" ? palette.Accent : name is "header" or "navigation" ? palette.Background : palette.Panel);
        return result;
    }
    private bool NeedsTextBacking(string surface, Color candidate)
    {
        var composed = ComposedSurface(surface);
        if (composed.A >= 245) return false;
        var onDark = Blend(Color.Black, composed, composed.A / 255f);
        var onLight = Blend(Color.White, composed, composed.A / 255f);
        return composed.A < 140 || WidgetEditorStyle.Contrast(candidate, onDark) < 4.5 || WidgetEditorStyle.Contrast(candidate, onLight) < 4.5;
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
        // Restrained directional drop shadow (light text) or subtle soft glow (dark text)
        // preserves glyph stems on layered transparent surfaces without opaque boxes or heavy outlines.
        using var defaultFormat = new StringFormat();
        var actual = format ?? defaultFormat;
        var foreground = ink is SolidBrush brush ? brush.Color : palette.Foreground;
        var alphaScale = candidate.A / 255f;
        var lightInk = WidgetEditorStyle.Contrast(foreground, Color.Black) >= WidgetEditorStyle.Contrast(foreground, Color.White);
        if (lightInk)
        {
            using var primaryShadow = new SolidBrush(Color.FromArgb((int)(135 * alphaScale), Color.Black));
            using var softShadow = new SolidBrush(Color.FromArgb((int)(60 * alphaScale), Color.Black));
            var drop = bounds; drop.Offset(0, 1);
            graphics.DrawString(text, font, primaryShadow, drop, actual);
            var diagonal = bounds; diagonal.Offset(1, 1);
            graphics.DrawString(text, font, softShadow, diagonal, actual);
        }
        else
        {
            using var primaryLift = new SolidBrush(Color.FromArgb((int)(96 * alphaScale), Color.White));
            using var softLift = new SolidBrush(Color.FromArgb((int)(44 * alphaScale), Color.White));
            var drop = bounds; drop.Offset(0, 1);
            graphics.DrawString(text, font, primaryLift, drop, actual);
            var diagonal = bounds; diagonal.Offset(1, 1);
            graphics.DrawString(text, font, softLift, diagonal, actual);
        }
        using var readable = new SolidBrush(foreground);
        graphics.DrawString(text, font, readable, bounds, actual);
    }
}
