using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

/// A delayed tooltip with a rounded, nonactivating, click-through surface.
internal sealed class WidgetTooltip : IDisposable
{
    internal const int DelayMilliseconds = 600;
    private readonly System.Windows.Forms.Timer delay = new() { Interval = DelayMilliseconds };
    private readonly System.Windows.Forms.Timer dismiss = new();
    private WidgetTooltipWindow? popup;
    private IWin32Window? owner;
    private string text = "";
    private Point location;
    private int duration;
    internal WidgetPalette Palette { get; set; } = WidgetPalette.Dark;

    internal WidgetTooltip()
    {
        delay.Tick += (_, _) =>
        {
            delay.Stop();
            if (owner is null || owner.Handle == 0 || !Native.IsWindow(owner.Handle) || !Native.IsWindowVisible(owner.Handle)) return;
            if (!Native.GetWindowRect(owner.Handle, out var window)) return;
            var anchor = new Point(window.Left + location.X, window.Top + location.Y);
            var area = Screen.FromPoint(anchor).WorkingArea;
            var dpi = GetDpiForWindow(owner.Handle);
            // Explorer children may inherit the shell's DPI. Use the host's
            // monitor scale, which also supplies these physical anchor pixels.
            var scale = owner is NativeDesktopWidgetHost widget ? widget.TooltipScale : dpi == 0 ? 1 : dpi / 96f;
            popup ??= new WidgetTooltipWindow();
            popup.Configure(text, Palette, scale, area);
            popup.Bounds = Clamp(new Rectangle(anchor, popup.Size), area);
            popup.Show(); // ShowWithoutActivation and WS_EX_NOACTIVATE preserve focus.
            dismiss.Interval = Math.Max(1, duration); dismiss.Start();
        };
        dismiss.Tick += (_, _) => { dismiss.Stop(); popup?.Hide(); };
    }

    internal static Rectangle Clamp(Rectangle bounds, Rectangle area) => new(
        Math.Clamp(bounds.X, area.Left, Math.Max(area.Left, area.Right - bounds.Width)),
        Math.Clamp(bounds.Y, area.Top, Math.Max(area.Top, area.Bottom - bounds.Height)),
        Math.Min(bounds.Width, area.Width), Math.Min(bounds.Height, area.Height));

    internal void Show(string value, IWin32Window window, Point point, int milliseconds)
    {
        Hide(window);
        text = value; owner = window; location = point; duration = milliseconds;
        delay.Start();
    }

    internal void Hide(IWin32Window window)
    {
        delay.Stop(); dismiss.Stop(); popup?.Hide(); owner = null;
    }

    public void Dispose() { delay.Dispose(); dismiss.Dispose(); popup?.Dispose(); }

    [DllImport("user32.dll")]
    private static extern uint GetDpiForWindow(nint window);
}

internal sealed class WidgetTooltipWindow : Form
{
    private WidgetPalette palette = WidgetPalette.Dark;
    private Font? textFont;
    private string label = "";
    private float scale = 1;
    internal WidgetTooltipWindow()
    {
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false; TopMost = true;
        StartPosition = FormStartPosition.Manual;
        DoubleBuffered = true;
        AccessibleRole = AccessibleRole.ToolTip;
    }
    protected override bool ShowWithoutActivation => true;
    protected override CreateParams CreateParams
    {
        get
        {
            var value = base.CreateParams;
            value.ExStyle |= 0x08000000 | 0x00000080 | 0x00000020;
            return value;
        }
    }
    protected override void WndProc(ref Message message)
    {
        if (message.Msg == 0x0084) { message.Result = -1; return; } // HTTRANSPARENT
        if (message.Msg == 0x0021) { message.Result = 3; return; } // MA_NOACTIVATE
        base.WndProc(ref message);
    }
    internal void Configure(string value, WidgetPalette colors, float dpiScale, Rectangle workingArea)
    {
        label = value; palette = colors; scale = dpiScale;
        AccessibleName = value;
        textFont?.Dispose(); textFont = new Font("Segoe UI", 13 * scale, FontStyle.Regular, GraphicsUnit.Pixel);
        var horizontal = (int)Math.Ceiling(10 * scale);
        var vertical = (int)Math.Ceiling(7 * scale);
        var width = Math.Max(1, Math.Min((int)(320 * scale), workingArea.Width - horizontal * 2));
        var measured = TextRenderer.MeasureText(value, textFont, new Size(width, 0), TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix);
        Size = new Size(Math.Min(workingArea.Width, measured.Width + horizontal * 2), Math.Min(workingArea.Height, measured.Height + vertical * 2));
        BackColor = palette.Panel;
        using var path = Outline(new RectangleF(0, 0, Width, Height), 6 * scale);
        var previous = Region; Region = new Region(path); previous?.Dispose();
        Invalidate();
    }
    protected override void OnPaint(PaintEventArgs args)
    {
        args.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using var border = new Pen(palette.Border, scale);
        using var path = Outline(new RectangleF(scale / 2, scale / 2, Width - scale, Height - scale), 6 * scale);
        args.Graphics.DrawPath(border, path);
        TextRenderer.DrawText(args.Graphics, label, textFont,
            Rectangle.Inflate(ClientRectangle, -(int)Math.Ceiling(10 * scale), -(int)Math.Ceiling(7 * scale)),
            palette.Foreground, TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis);
    }
    private static GraphicsPath Outline(RectangleF bounds, float radius)
    {
        radius = Math.Clamp(radius, 0.5f, Math.Max(0.5f, Math.Min(bounds.Width, bounds.Height) / 2));
        var diameter = radius * 2;
        var path = new GraphicsPath();
        path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure(); return path;
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) textFont?.Dispose();
        base.Dispose(disposing);
    }
}
