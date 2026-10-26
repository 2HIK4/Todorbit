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
        if (name == "navigationButton") Add("navigation", palette.Background);
        if (name == "selectedToday") { Add("selectedDate", palette.Accent); Add("today", palette.Accent); }
        else Add(name, name is "selectedDate" or "today" ? palette.Accent : name is "header" or "navigation" ? palette.Background : palette.Panel);
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
        // A tight, opaque label backing provides contrast against unknown wallpaper.
        // It changes neither the configured surface alpha nor the content alpha.
        using var defaultFormat = new StringFormat();
        var actual = format ?? defaultFormat;
        var size = graphics.MeasureString(text, font, bounds.Size, actual);
        var width = Math.Min(bounds.Width, size.Width); var height = Math.Min(bounds.Height, size.Height);
        var x = bounds.X + (actual.Alignment == StringAlignment.Center ? (bounds.Width - width) / 2 : actual.Alignment == StringAlignment.Far ? bounds.Width - width : 0);
        var y = bounds.Y + (actual.LineAlignment == StringAlignment.Center ? (bounds.Height - height) / 2 : actual.LineAlignment == StringAlignment.Far ? bounds.Height - height : 0);
        var backing = RectangleF.Intersect(bounds, new RectangleF(x - 2, y - 1, width + 4, height + 2));
        using var background = new SolidBrush(palette.Panel);
        FillRoundedRectangle(graphics, background, backing, 2);
        var foreground = ink is SolidBrush brush ? brush.Color : palette.Foreground;
        if (WidgetEditorStyle.Contrast(foreground, palette.Panel) < 4.5)
            foreground = WidgetEditorStyle.Contrast(Color.White, palette.Panel) > WidgetEditorStyle.Contrast(Color.Black, palette.Panel) ? Color.White : Color.Black;
        using var readable = new SolidBrush(foreground);
        graphics.DrawString(text, font, readable, bounds, actual);
    }
}
