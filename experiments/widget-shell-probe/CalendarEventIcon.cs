using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;

/// Uses the same bounded icon registry/glyphs as Flutter, independently of OS fonts.
internal static class CalendarEventIcon
{
    // Retain both font bytes and collection for the process lifetime (GDI+ owns neither).
    private static readonly PrivateFontCollection Fonts = new();
    private static readonly IntPtr FontMemory;

    static CalendarEventIcon()
    {
        using var stream = typeof(CalendarEventIcon).Assembly.GetManifestResourceStream("Todorbit.EventIcons")!;
        using var buffer = new MemoryStream();
        stream.CopyTo(buffer);
        var bytes = buffer.ToArray();
        FontMemory = Marshal.AllocHGlobal(bytes.Length);
        Marshal.Copy(bytes, 0, FontMemory, bytes.Length);
        Fonts.AddMemoryFont(FontMemory, bytes.Length);
    }

    internal static string Glyph(string? key) => EventIconGlyphs.Values.GetValueOrDefault(key ?? "__event", EventIconGlyphs.Values["__event"]);

    internal static Color? Backing(Color color, Color background) => WidgetEditorStyle.Contrast(color, background) >= 3
        ? null : WidgetEditorStyle.Contrast(color, Color.Black) >= WidgetEditorStyle.Contrast(color, Color.White) ? Color.Black : Color.White;

    internal static void Draw(Graphics graphics, WidgetCalendarItem item, RectangleF bounds, Color fallback, Color background)
    {
        var color = item.ColorValue is { } value ? Color.FromArgb(value) : fallback;
        if (Backing(color, background) is { } backing)
        {
            using var fill = new SolidBrush(backing);
            var disc = bounds; disc.Inflate(2, 2);
            graphics.FillEllipse(fill, disc);
        }
        using var path = new GraphicsPath();
        path.AddString(Glyph(item.IconName), Fonts.Families[0], (int)FontStyle.Regular, 24, PointF.Empty, StringFormat.GenericTypographic);
        var ink = path.GetBounds();
        var scale = Math.Min(bounds.Width / ink.Width, bounds.Height / ink.Height);
        using var transform = new Matrix(scale, 0, 0, scale,
            bounds.X + (bounds.Width - ink.Width * scale) / 2 - ink.X * scale,
            bounds.Y + (bounds.Height - ink.Height * scale) / 2 - ink.Y * scale);
        path.Transform(transform);
        using var brush = new SolidBrush(color);
        graphics.FillPath(brush, path);
    }
}
