internal static class CalendarEventIconSelfTest
{
    internal static void Verify()
    {
        if (CalendarEventIcon.Glyph("unknown") != CalendarEventIcon.Glyph(null))
            throw new InvalidOperationException("Unknown icons must use the event glyph.");
        var signatures = new HashSet<string>();
        foreach (var key in EventIconGlyphs.Values.Keys)
        {
            using var image = new Bitmap(48, 48);
            using var graphics = Graphics.FromImage(image);
            graphics.Clear(Color.White);
            var rose = Color.FromArgb(0xB6, 0x53, 0x72);
            CalendarEventIcon.Draw(graphics, new(DateTime.Today, "Event", key, null, ColorValue: rose.ToArgb(), IconName: key), new(8, 8, 32, 32), Color.White, Color.White);
            var pixels = new List<byte>(); var colored = 0;
            for (var y = 0; y < 48; y++) for (var x = 0; x < 48; x++)
            {
                var pixel = image.GetPixel(x, y);
                if (pixel.ToArgb() == rose.ToArgb()) colored++;
                pixels.AddRange(BitConverter.GetBytes(pixel.ToArgb()));
            }
            if (colored < 10 || !signatures.Add(Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(pixels.ToArray()))))
                throw new InvalidOperationException($"Missing, white or duplicate event glyph: {key}");
        }
        foreach (var background in new[] { Color.White, Color.Black, WidgetPalette.Light.Panel, WidgetPalette.Dark.Panel, Color.Teal })
        foreach (var color in new[] { Color.White, Color.Black, Color.FromArgb(0xB6, 0x53, 0x72) })
            if (WidgetEditorStyle.Contrast(color, CalendarEventIcon.Backing(color, background) ?? background) < 3)
                throw new InvalidOperationException("Configured event tint loses contrast.");
    }

    internal static void Capture(string output)
    {
        foreach (var light in new[] { false, true })
        {
            var palette = light ? WidgetPalette.Light : WidgetPalette.Dark;
            using var image = new Bitmap(640, 240);
            using var graphics = Graphics.FromImage(image);
            graphics.Clear(palette.Panel);
            using var font = new Font("Segoe UI", 11, GraphicsUnit.Pixel);
            using var ink = new SolidBrush(palette.Foreground);
            var n = 0;
            foreach (var key in EventIconGlyphs.Values.Keys)
            {
                var x = n % 8 * 80; var y = n / 8 * 60; n++;
                CalendarEventIcon.Draw(graphics, new(DateTime.Today, "Event", key, null, ColorValue: Color.FromArgb(0xB6, 0x53, 0x72).ToArgb(), IconName: key), new(x + 27, y + 4, 26, 26), palette.Accent, palette.Panel);
                graphics.DrawString(key, font, ink, x + 4, y + 34);
            }
            image.Save(Path.Combine(output, $"event-icons-{(light ? "light" : "dark")}.png"));
        }
    }
}
