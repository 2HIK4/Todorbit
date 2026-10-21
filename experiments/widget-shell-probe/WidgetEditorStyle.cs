using System.Globalization;
using System.ComponentModel;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

// Shared dimensions and semantic colors for the short-lived native editors.
internal static class WidgetEditorStyle {
  internal const int Margin = 20;
  internal const int Gap = 12;
  internal const int FieldHeight = 36;
  internal const int ButtonHeight = 36;
  internal const int Corner = 7;
  internal const int DateActionWidth = 32;

  internal static int Scale(int logical, float dpi) =>
    Math.Max(1, (int)Math.Round(logical * dpi / 96f));

  internal static Color Error(WidgetPalette palette) => palette.Error;

  internal static bool IsDark(WidgetPalette palette) =>
    palette.Background.GetBrightness() < 0.45f;

  internal static Color OnAccent(WidgetPalette palette) {
    var dark = IsDark(palette) ? palette.Background : palette.Foreground;
    var light = IsDark(palette) ? palette.Foreground : palette.Panel;
    var best = Contrast(dark, palette.Accent) > Contrast(light, palette.Accent)
      ? dark : light;
    if (Contrast(best, palette.Accent) >= 4.5) return best;
    return Contrast(Color.Black, palette.Accent) >
      Contrast(Color.White, palette.Accent) ? Color.Black : Color.White;
  }

  internal static double Contrast(Color first, Color second) {
    static double Luminance(Color value) {
      static double Channel(byte v) {
        var x = v / 255d;
        return x <= 0.04045 ? x / 12.92 : Math.Pow((x + 0.055) / 1.055, 2.4);
      }
      return 0.2126 * Channel(value.R) + 0.7152 * Channel(value.G) +
        0.0722 * Channel(value.B);
    }
    var a = Luminance(first);
    var b = Luminance(second);
    return (Math.Max(a, b) + 0.05) / (Math.Min(a, b) + 0.05);
  }

  internal static Button Button(string text, WidgetPalette palette, bool primary = false) {
    var button = new WidgetStyledButton(palette, primary) {
      Text = text,
      Height = ButtonHeight,
      Font = new Font("Segoe UI Semibold", 9.5f),
      Cursor = Cursors.Hand,
    };
    return button;
  }

  internal static Color Blend(Color a, Color b, float amount) => Color.FromArgb(
    (int)(a.R + (b.R - a.R) * amount),
    (int)(a.G + (b.G - a.G) * amount),
    (int)(a.B + (b.B - a.B) * amount));

  internal static GraphicsPath RoundedPath(Rectangle bounds, int radius) {
    var diameter = Math.Min(radius * 2, Math.Min(bounds.Width, bounds.Height));
    var path = new GraphicsPath();
    path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
    path.AddArc(bounds.Right - diameter, bounds.Top, diameter, diameter, 270, 90);
    path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter,
      diameter, diameter, 0, 90);
    path.AddArc(bounds.Left, bounds.Bottom - diameter,
      diameter, diameter, 90, 90);
    path.CloseFigure();
    return path;
  }

  internal static void PaintSurface(Graphics graphics, Rectangle bounds,
      WidgetPalette palette, bool focused, bool enabled = true) {
    graphics.SmoothingMode = SmoothingMode.AntiAlias;
    using var path = RoundedPath(bounds, Scale(Corner, graphics.DpiX));
    using var fill = new SolidBrush(enabled ? palette.Panel :
      Blend(palette.Panel, palette.Background, 0.48f));
    using var border = new Pen(focused ? palette.Accent : palette.Border,
      focused ? 2 : 1) { Alignment = PenAlignment.Inset };
    graphics.FillPath(fill, path);
    graphics.DrawPath(border, path);
  }

  internal static void ApplyCaption(Form form, WidgetPalette palette) {
    var dark = IsDark(palette) ? 1 : 0;
    DwmSetWindowAttribute(form.Handle, 20, ref dark, sizeof(int));
    var caption = palette.Background.R | (palette.Background.G << 8) |
      (palette.Background.B << 16);
    var text = palette.Foreground.R | (palette.Foreground.G << 8) |
      (palette.Foreground.B << 16);
    DwmSetWindowAttribute(form.Handle, 35, ref caption, sizeof(int));
    DwmSetWindowAttribute(form.Handle, 36, ref text, sizeof(int));
  }

  [DllImport("dwmapi.dll")]
  private static extern int DwmSetWindowAttribute(
    IntPtr window, int attribute, ref int value, int size);
}

internal sealed class WidgetStyledButton : Button {
  private readonly WidgetPalette palette;
  private readonly bool primary;
  private bool hovered;
  private bool pressed;
  [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
  internal bool ShowChoiceArrow { get; set; }

  internal WidgetStyledButton(WidgetPalette palette, bool primary) {
    this.palette = palette;
    this.primary = primary;
    SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
      ControlStyles.OptimizedDoubleBuffer, true);
    FlatStyle = FlatStyle.Flat;
    UseVisualStyleBackColor = false;
    BackColor = palette.Panel;
    ForeColor = palette.Foreground;
  }

  protected override void OnMouseEnter(EventArgs e) {
    hovered = true;
    Invalidate();
    base.OnMouseEnter(e);
  }
  protected override void OnMouseLeave(EventArgs e) {
    hovered = false;
    pressed = false;
    Invalidate();
    base.OnMouseLeave(e);
  }
  protected override void OnMouseDown(MouseEventArgs e) {
    pressed = true;
    Invalidate();
    base.OnMouseDown(e);
  }
  protected override void OnMouseUp(MouseEventArgs e) {
    pressed = false;
    Invalidate();
    base.OnMouseUp(e);
  }
  protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
  protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }
  protected override void OnEnabledChanged(EventArgs e) {
    Invalidate();
    base.OnEnabledChanged(e);
  }

  protected override void OnPaint(PaintEventArgs e) {
    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
    var fill = primary ? palette.Accent : palette.Panel;
    if (hovered) fill = WidgetEditorStyle.Blend(fill,
      primary ? palette.Foreground : palette.Accent, primary ? 0.11f : 0.13f);
    if (pressed) fill = WidgetEditorStyle.Blend(fill, palette.Background, 0.20f);
    if (!Enabled) fill = WidgetEditorStyle.Blend(fill, palette.Background, 0.48f);
    var outline = Focused ? palette.Accent :
      primary ? palette.Accent : palette.Border;
    var bounds = new Rectangle(1, 1, Math.Max(1, Width - 3), Math.Max(1, Height - 3));
    using var path = WidgetEditorStyle.RoundedPath(bounds,
      WidgetEditorStyle.Scale(WidgetEditorStyle.Corner, e.Graphics.DpiX));
    using var brush = new SolidBrush(fill);
    using var pen = new Pen(outline, Focused ? 2 : 1);
    e.Graphics.FillPath(brush, path);
    e.Graphics.DrawPath(pen, path);
    var foreground = primary ? WidgetEditorStyle.OnAccent(palette) : palette.Foreground;
    if (!Enabled) foreground = WidgetEditorStyle.Blend(foreground, fill, 0.48f);
    var flags = TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine;
    if (Width > 70) flags |= TextFormatFlags.EndEllipsis;
    flags |= TextAlign == ContentAlignment.MiddleLeft
      ? TextFormatFlags.Left : TextFormatFlags.HorizontalCenter;
    var inset = Width > 70 ? 8 + Padding.Left : 1;
    var trailing = ShowChoiceArrow ? WidgetEditorStyle.Scale(30, e.Graphics.DpiX) : 0;
    TextRenderer.DrawText(e.Graphics, Text, Font,
      new Rectangle(inset, 2,
        Math.Max(1, Width - inset * 2 - (Width > 70 ? Padding.Right : 0) - trailing),
        Height - 4), foreground, flags);
    if (ShowChoiceArrow) {
      using var arrow = new Pen(Enabled ? palette.Foreground : palette.Muted, 1.7f) {
        StartCap = LineCap.Round, EndCap = LineCap.Round,
      };
      var unit = WidgetEditorStyle.Scale(4, e.Graphics.DpiX);
      var x = Width - WidgetEditorStyle.Scale(18, e.Graphics.DpiX);
      var y = Height / 2 - unit / 2;
      e.Graphics.DrawLines(arrow, [new Point(x - unit, y),
        new Point(x, y + unit), new Point(x + unit, y)]);
    }
  }

  protected override void OnPaintBackground(PaintEventArgs e) {
    e.Graphics.Clear(Parent?.BackColor ?? palette.Background);
  }

}

internal sealed class WidgetEditorScrollPanel : Panel {
  private readonly WidgetPalette palette;
  private int contentHeight;
  private int scrollOffset;
  private bool dragging;
  internal event EventHandler? ScrollChanged;
  internal int ContentHeight => contentHeight;
  internal int ScrollOffset => scrollOffset;
  internal bool Scrollable => contentHeight > ClientSize.Height;

  internal WidgetEditorScrollPanel(WidgetPalette palette) {
    this.palette = palette;
    DoubleBuffered = true;
    TabStop = false;
    BackColor = palette.Background;
  }

  internal void SetContentHeight(int height) {
    contentHeight = height;
    scrollOffset = Math.Min(scrollOffset,
      Math.Max(0, contentHeight - ClientSize.Height));
    Invalidate();
  }

  internal void ScrollBy(int amount) => ScrollTo(scrollOffset + amount);

  internal void ScrollTo(int offset) {
    var next = Math.Clamp(offset, 0,
      Math.Max(0, contentHeight - ClientSize.Height));
    if (next == scrollOffset) return;
    scrollOffset = next;
    ScrollChanged?.Invoke(this, EventArgs.Empty);
    Invalidate();
  }

  protected override void OnMouseWheel(MouseEventArgs e) {
    ScrollBy(-e.Delta / 120 * 58);
    base.OnMouseWheel(e);
  }

  protected override void OnMouseDown(MouseEventArgs e) {
    if (Scrollable && e.X >= Width - 16) {
      dragging = true;
      Capture = true;
      ScrollFromPointer(e.Y);
    }
    base.OnMouseDown(e);
  }

  protected override void OnMouseMove(MouseEventArgs e) {
    if (dragging) ScrollFromPointer(e.Y);
    base.OnMouseMove(e);
  }

  protected override void OnMouseUp(MouseEventArgs e) {
    dragging = false;
    Capture = false;
    base.OnMouseUp(e);
  }

  private void ScrollFromPointer(int y) {
    var track = Math.Max(1, Height - 24);
    ScrollTo((int)Math.Round((y - 12d) / track *
      Math.Max(0, contentHeight - Height)));
  }

  protected override void OnPaint(PaintEventArgs e) {
    base.OnPaint(e);
    if (!Scrollable) return;
    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
    var track = new Rectangle(Width - 9, 8, 3, Height - 16);
    using var trackBrush = new SolidBrush(palette.Border);
    e.Graphics.FillRectangle(trackBrush, track);
    var thumbHeight = Math.Max(20, track.Height * Height / contentHeight);
    var maxOffset = Math.Max(1, contentHeight - Height);
    var top = track.Top + (track.Height - thumbHeight) * scrollOffset / maxOffset;
    using var thumb = new SolidBrush(palette.Accent);
    e.Graphics.FillRectangle(thumb, new Rectangle(track.X, top,
      track.Width, thumbHeight));
  }
}

internal sealed class WidgetTextInput : UserControl {
  private readonly WidgetPalette palette;
  private readonly TextBox editor = new();
  [DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
  internal string Value { get => editor.Text; set => editor.Text = value; }

  internal WidgetTextInput(WidgetPalette palette, string name, bool multiline = false) {
    this.palette = palette;
    AccessibleName = name;
    BackColor = palette.Panel;
    Padding = new Padding(10, multiline ? 8 : 7, 10, 6);
    editor.BorderStyle = BorderStyle.None;
    editor.BackColor = palette.Panel;
    editor.ForeColor = palette.Foreground;
    editor.Font = new Font("Segoe UI", 9.5f);
    editor.AccessibleName = name;
    editor.Multiline = multiline;
    editor.AcceptsReturn = multiline;
    editor.ScrollBars = ScrollBars.None;
    editor.Dock = DockStyle.Fill;
    editor.GotFocus += (_, _) => Invalidate();
    editor.LostFocus += (_, _) => Invalidate();
    editor.MouseWheel += (_, e) => OnMouseWheel(e);
    Controls.Add(editor);
    Paint += (_, e) => {
      e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
      using var path = WidgetEditorStyle.RoundedPath(
        new Rectangle(1, 1, Width - 3, Height - 3), WidgetEditorStyle.Corner);
      using var pen = new Pen(editor.Focused ? palette.Accent : palette.Border,
        editor.Focused ? 2 : 1);
      e.Graphics.DrawPath(pen, path);
    };
  }

  internal void FocusEditor(bool selectAll = false) {
    editor.Focus();
    if (selectAll) editor.SelectAll();
  }

  protected override void OnPaintBackground(PaintEventArgs e) {
    e.Graphics.Clear(Parent?.BackColor ?? palette.Background);
    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
    using var path = WidgetEditorStyle.RoundedPath(
      new Rectangle(0, 0, Width - 1, Height - 1), WidgetEditorStyle.Corner);
    using var brush = new SolidBrush(palette.Panel);
    e.Graphics.FillPath(brush, path);
  }
}

internal sealed class WidgetChoiceBox : UserControl {
  private readonly WidgetPalette palette;
  private readonly Button display;
  private readonly List<(string Label, string Value)> choices = [];
  private string? value;
  internal event EventHandler? ValueChanged;
  internal string? Value => value;

  internal WidgetChoiceBox(WidgetPalette palette, string accessibleName) {
    this.palette = palette;
    Height = WidgetEditorStyle.FieldHeight;
    BackColor = palette.Background;
    display = WidgetEditorStyle.Button("", palette);
    display.Dock = DockStyle.Fill;
    display.Font = new Font("Segoe UI", 9.5f);
    display.TextAlign = ContentAlignment.MiddleLeft;
    display.Padding = new Padding(9, 0, 6, 0);
    ((WidgetStyledButton)display).ShowChoiceArrow = true;
    display.AccessibleName = accessibleName;
    display.Click += (_, _) => ShowChoices();
    display.MouseWheel += (_, e) => OnMouseWheel(e);
    display.KeyDown += (_, e) => {
      if (e.KeyCode is Keys.Down or Keys.Up) {
        ChangeBy(e.KeyCode == Keys.Down ? 1 : -1);
        e.Handled = true;
      }
    };
    Controls.Add(display);
  }

  internal void SetChoices(IEnumerable<(string Label, string Value)> items,
      string? selected) {
    choices.Clear();
    choices.AddRange(items);
    Select(selected, false);
  }

  internal void Select(string? selected, bool notify = true) {
    var choice = choices.FirstOrDefault(item => item.Value == (selected ?? ""));
    if (!choices.Contains(choice)) choice = choices.FirstOrDefault();
    var previous = value;
    value = choice.Value.Length == 0 ? null : choice.Value;
    display.Text = choice.Label;
    if (notify && previous != value) ValueChanged?.Invoke(this, EventArgs.Empty);
  }

  private void ChangeBy(int direction) {
    if (choices.Count == 0) return;
    var index = choices.FindIndex(item => item.Value == (value ?? ""));
    index = Math.Clamp(index + direction, 0, choices.Count - 1);
    Select(choices[index].Value);
  }

  private void ShowChoices() {
    if (!Enabled || choices.Count == 0) return;
    var menu = new ContextMenuStrip();
    foreach (var choice in choices) {
      var item = new ToolStripMenuItem(choice.Label) {
        Checked = choice.Value == (value ?? ""),
      };
      item.Click += (_, _) => Select(choice.Value);
      menu.Items.Add(item);
    }
    WidgetMenuStyle.Apply(menu, palette);
    menu.Closed += (_, _) => menu.Dispose();
    menu.Show(display, new Point(0, display.Height));
  }
}

internal sealed class WidgetDateInput : UserControl {
  private readonly WidgetPalette palette;
  private readonly TextBox text = new();
  private readonly WidgetDateAction calendar;
  private readonly WidgetDateAction clear;
  internal string? DateValue {
    get {
      if (String.IsNullOrWhiteSpace(text.Text)) return null;
      if (!DateTime.TryParseExact(text.Text.Trim(), "yyyy-MM-dd",
          CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
        throw new FormatException($"{AccessibleName} must use YYYY-MM-DD.");
      return date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    }
  }

  internal WidgetDateInput(WidgetPalette palette, string name, string? value) {
    this.palette = palette;
    AccessibleName = name;
    Height = WidgetEditorStyle.FieldHeight;
    BackColor = palette.Panel;
    SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    text.BorderStyle = BorderStyle.None;
    text.BackColor = palette.Panel;
    text.ForeColor = palette.Foreground;
    text.Font = new Font("Segoe UI", 9.5f);
    text.PlaceholderText = "YYYY-MM-DD";
    text.AccessibleName = name;
    text.Text = value ?? "";
    text.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
    calendar = new WidgetDateAction(palette, DateActionKind.Calendar);
    calendar.AccessibleName = $"Choose {name.ToLowerInvariant()}";
    calendar.Click += (_, _) => ShowCalendar();
    calendar.MouseWheel += (_, e) => OnMouseWheel(e);
    clear = new WidgetDateAction(palette, DateActionKind.Clear);
    clear.AccessibleName = $"Clear {name.ToLowerInvariant()}";
    clear.Click += (_, _) => { text.Clear(); text.Focus(); };
    clear.MouseWheel += (_, e) => OnMouseWheel(e);
    text.MouseWheel += (_, e) => OnMouseWheel(e);
    Controls.AddRange([text, calendar, clear]);
    text.GotFocus += (_, _) => Invalidate();
    text.LostFocus += (_, _) => Invalidate();
    calendar.GotFocus += (_, _) => Invalidate();
    calendar.LostFocus += (_, _) => Invalidate();
    clear.GotFocus += (_, _) => Invalidate();
    clear.LostFocus += (_, _) => Invalidate();
    Resize += (_, _) => LayoutChildren();
    LayoutChildren();
  }

  private void LayoutChildren() {
    var w = Width;
    var inset = WidgetEditorStyle.Scale(11, DeviceDpi);
    var gap = WidgetEditorStyle.Scale(5, DeviceDpi);
    var edge = WidgetEditorStyle.Scale(2, DeviceDpi);
    var action = WidgetEditorStyle.Scale(WidgetEditorStyle.DateActionWidth, DeviceDpi);
    var textHeight = Math.Min(Height - edge * 2, text.PreferredHeight);
    text.SetBounds(inset, (Height - textHeight) / 2,
      Math.Max(1, w - inset - gap - action * 2 - edge), textHeight);
    calendar.SetBounds(Math.Max(0, w - action * 2 - edge), edge,
      action, Math.Max(1, Height - edge * 2));
    clear.SetBounds(Math.Max(0, w - action - edge), edge,
      action, Math.Max(1, Height - edge * 2));
  }

  private void ShowCalendar() {
    DateTime initial;
    try { initial = DateValue is { } date
      ? DateTime.ParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture)
      : DateTime.Today; }
    catch (FormatException) { initial = DateTime.Today; }
    using var picker = new WidgetCalendarDialog(palette, initial);
    var point = PointToScreen(new Point(0, Height));
    var working = Screen.FromPoint(point).WorkingArea;
    picker.Location = new Point(
      Math.Clamp(point.X, working.Left, Math.Max(working.Left, working.Right - picker.Width)),
      Math.Clamp(point.Y, working.Top, Math.Max(working.Top, working.Bottom - picker.Height)));
    if (picker.ShowDialog(FindForm()) == DialogResult.OK) {
      text.Text = picker.SelectedDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
      text.Focus();
    }
  }

  protected override void OnPaintBackground(PaintEventArgs e) {
    e.Graphics.Clear(Parent?.BackColor ?? palette.Background);
    WidgetEditorStyle.PaintSurface(e.Graphics,
      new Rectangle(1, 1, Math.Max(1, Width - 3), Math.Max(1, Height - 3)),
      palette, ContainsFocus, Enabled);
  }
}

internal enum DateActionKind { Calendar, Clear }

// The date field owns the only outline. Actions paint inside its surface.
internal sealed class WidgetDateAction : Button {
  private readonly WidgetPalette palette;
  private readonly DateActionKind kind;
  private bool hovered;
  private bool pressed;

  internal WidgetDateAction(WidgetPalette palette, DateActionKind kind) {
    this.palette = palette;
    this.kind = kind;
    SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
      ControlStyles.OptimizedDoubleBuffer, true);
    FlatStyle = FlatStyle.Flat;
    TabStop = true;
    Cursor = Cursors.Hand;
    BackColor = palette.Panel;
  }

  protected override void OnMouseEnter(EventArgs e) { hovered = true; Invalidate(); base.OnMouseEnter(e); }
  protected override void OnMouseLeave(EventArgs e) { hovered = false; pressed = false; Invalidate(); base.OnMouseLeave(e); }
  protected override void OnMouseDown(MouseEventArgs e) { pressed = true; Invalidate(); base.OnMouseDown(e); }
  protected override void OnMouseUp(MouseEventArgs e) { pressed = false; Invalidate(); base.OnMouseUp(e); }
  protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
  protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }
  protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }

  protected override void OnPaint(PaintEventArgs e) {
    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
    var fill = pressed ? WidgetEditorStyle.Blend(palette.Panel, palette.Accent, 0.24f) :
      hovered || Focused ? WidgetEditorStyle.Blend(palette.Panel, palette.Accent, 0.13f) :
      palette.Panel;
    using var brush = new SolidBrush(fill);
    using var area = WidgetEditorStyle.RoundedPath(
      new Rectangle(1, 1, Math.Max(1, Width - 3), Math.Max(1, Height - 3)),
      WidgetEditorStyle.Scale(5, e.Graphics.DpiX));
    e.Graphics.FillPath(brush, area);
    var ink = Enabled ? palette.Foreground : palette.Muted;
    using var pen = new Pen(ink, 1.6f) {
      StartCap = LineCap.Round, EndCap = LineCap.Round,
    };
    var x = Width / 2;
    var y = Height / 2;
    var unit = WidgetEditorStyle.Scale(4, e.Graphics.DpiX);
    if (kind == DateActionKind.Clear) {
      e.Graphics.DrawLine(pen, x - unit, y - unit, x + unit, y + unit);
      e.Graphics.DrawLine(pen, x + unit, y - unit, x - unit, y + unit);
    } else {
      var half = WidgetEditorStyle.Scale(7, e.Graphics.DpiX);
      var top = WidgetEditorStyle.Scale(6, e.Graphics.DpiX);
      e.Graphics.DrawRectangle(pen, x - half, y - top, half * 2, top * 2 + 1);
      e.Graphics.DrawLine(pen, x - half, y - unit / 2, x + half, y - unit / 2);
      e.Graphics.DrawLine(pen, x - unit, y - top - 2, x - unit, y - top + 2);
      e.Graphics.DrawLine(pen, x + unit, y - top - 2, x + unit, y - top + 2);
    }
  }
}

internal sealed class WidgetCalendarDialog : Form {
  private readonly WidgetPalette palette;
  private readonly Label month = new();
  private readonly Panel days = new();
  private DateTime shownMonth;
  internal DateTime SelectedDate { get; private set; }

  internal WidgetCalendarDialog(WidgetPalette palette, DateTime initial) {
    this.palette = palette;
    SelectedDate = initial;
    shownMonth = new DateTime(initial.Year, initial.Month, 1);
    Text = "Choose date";
    FormBorderStyle = FormBorderStyle.FixedDialog;
    StartPosition = FormStartPosition.Manual;
    ShowInTaskbar = false;
    MaximizeBox = false;
    MinimizeBox = false;
    ClientSize = new Size(306, 303);
    Font = new Font("Segoe UI", 9f);
    BackColor = palette.Background;
    ForeColor = palette.Foreground;
    KeyPreview = true;
    KeyDown += (_, e) => { if (e.KeyCode == Keys.Escape) Close(); };
    var previous = WidgetEditorStyle.Button("‹", palette);
    previous.SetBounds(12, 12, 36, 36);
    previous.AccessibleName = "Previous month";
    previous.Click += (_, _) => { shownMonth = shownMonth.AddMonths(-1); RenderDays(); };
    var next = WidgetEditorStyle.Button("›", palette);
    next.SetBounds(258, 12, 36, 36);
    next.AccessibleName = "Next month";
    next.Click += (_, _) => { shownMonth = shownMonth.AddMonths(1); RenderDays(); };
    month.SetBounds(52, 12, 202, 36);
    month.TextAlign = ContentAlignment.MiddleCenter;
    month.Font = new Font("Segoe UI Semibold", 10f);
    days.SetBounds(12, 55, 282, 240);
    days.BackColor = palette.Background;
    Controls.AddRange([previous, month, next, days]);
    Shown += (_, _) => WidgetEditorStyle.ApplyCaption(this, palette);
    RenderDays();
  }

  private void RenderDays() {
    days.SuspendLayout();
    foreach (Control child in days.Controls) child.Dispose();
    days.Controls.Clear();
    month.Text = shownMonth.ToString("MMMM yyyy", CultureInfo.CurrentCulture);
    var labels = CultureInfo.CurrentCulture.DateTimeFormat.AbbreviatedDayNames;
    for (var column = 0; column < 7; column++) {
      var label = new Label {
        Text = labels[column],
        ForeColor = palette.Muted,
        TextAlign = ContentAlignment.MiddleCenter,
      };
      label.SetBounds(column * 40, 0, 40, 25);
      days.Controls.Add(label);
    }
    var offset = (int)shownMonth.DayOfWeek;
    var rows = (offset + DateTime.DaysInMonth(shownMonth.Year,
      shownMonth.Month) + 6) / 7;
    days.Height = 27 + rows * 35;
    ClientSize = new Size(306, days.Bottom + 10);
    if (Visible) {
      var work = Screen.FromControl(this).WorkingArea;
      Location = new Point(
        Math.Clamp(Left, work.Left, Math.Max(work.Left, work.Right - Width)),
        Math.Clamp(Top, work.Top, Math.Max(work.Top, work.Bottom - Height)));
    }
    for (var day = 1; day <= DateTime.DaysInMonth(shownMonth.Year, shownMonth.Month); day++) {
      var date = new DateTime(shownMonth.Year, shownMonth.Month, day);
      var cell = offset + day - 1;
      var button = WidgetEditorStyle.Button(day.ToString(CultureInfo.CurrentCulture),
        palette, date == SelectedDate.Date);
      button.Font = new Font("Segoe UI", 9f);
      button.FlatAppearance.BorderSize = date == DateTime.Today ? 1 : 0;
      button.SetBounds((cell % 7) * 40, 27 + (cell / 7) * 35, 38, 33);
      button.AccessibleName = date.ToLongDateString();
      button.Click += (_, _) => {
        SelectedDate = date;
        DialogResult = DialogResult.OK;
        Close();
      };
      days.Controls.Add(button);
    }
    days.ResumeLayout();
  }
}
