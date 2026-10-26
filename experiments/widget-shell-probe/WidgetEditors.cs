// The desktop-attached HWND cannot own keyboard focus reliably. This short-lived,
// activatable top-level surface is aligned over the painted Quick Add field so the
// interaction remains visually inline without putting child controls in Explorer.
internal sealed class InlineQuickAddForm : Form {
  private readonly TextBox editor = new();
  private readonly Label feedback = new();
  private readonly Action<string> submit;
  private readonly WidgetPalette palette;
  private readonly WidgetSurface surface;

  internal InlineQuickAddForm(
      WidgetPalette palette, Rectangle bounds, string destination,
      Action<string> submit, WidgetSurface? surface = null, float textScale = 1) {
    this.surface = surface ?? new WidgetSurface { Border = true, Radius = 7 };
    var fill = this.surface.Resolve(palette.Panel);
    // Native TextBox input stays opaque while active so glyphs/selection remain clear.
    var background = Color.FromArgb(255,fill);
    var ink = ParseColor(this.surface.TextColor,palette.Foreground);
    if(WidgetEditorStyle.Contrast(ink,background)<4.5) ink = WidgetEditorStyle.Contrast(Color.Black,background)>WidgetEditorStyle.Contrast(Color.White,background)?Color.Black:Color.White;
    this.palette = palette;
    this.submit = submit;
    Text = "Quick Add - Todorbit";
    FormBorderStyle = FormBorderStyle.None;
    StartPosition = FormStartPosition.Manual;
    ShowInTaskbar = false;
    TopMost = false;
    Bounds = bounds;
    BackColor = background;
    ForeColor = ink;
    // The transient WinForms input uses native point/DPI scaling; only the
    // owner-drawn layered surface applies its own logical-pixel transform.
    Font = new Font("Segoe UI", 9.75f * textScale, FontStyle.Regular,GraphicsUnit.Point);
    Padding = new Padding(1);
    SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
      ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
    KeyPreview = true;

    var plus = new Label {
      Text = "+",
      Font = new Font("Segoe UI Semibold", 15, FontStyle.Bold),
      ForeColor = palette.Accent,
      Location = new Point(8, 5),
      Size = new Size(24, 27),
      TextAlign = ContentAlignment.MiddleCenter,
    };
    editor.BorderStyle = BorderStyle.None;
    editor.PlaceholderText = "Add a task...";
    editor.BackColor = background;
    editor.ForeColor = ink;
    editor.Location = new Point(38, 10);
    editor.Size = new Size(Math.Max(80, Width - 132), 24);
    editor.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top;
    editor.AccessibleName = $"Add a task to {destination}";
    var destinationLabel = new Label {
      Text = destination,
      ForeColor = palette.Muted,
      Location = new Point(Width - 87, 7),
      Size = new Size(76, 28),
      Anchor = AnchorStyles.Top | AnchorStyles.Right,
      TextAlign = ContentAlignment.MiddleRight,
    };
    feedback.ForeColor = palette.Error;
    feedback.Location = new Point(38, Height - 18);
    feedback.Size = new Size(Math.Max(80, Width - 48), 17);
    feedback.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom;
    feedback.Visible = false;
    editor.KeyDown += EditorKeyDown;
    editor.GotFocus += (_, _) => Invalidate();
    editor.LostFocus += (_, _) => Invalidate();
    Controls.AddRange([plus, editor, destinationLabel, feedback]);
    Activated += (_, _) => Invalidate();
    Deactivate += (_, _) => {
      if (!IsDisposed) Close();
    };
  }

  protected override void OnResize(EventArgs e) {
    base.OnResize(e);
    if (Width < 2 || Height < 2) return;
    using var path = WidgetEditorStyle.RoundedPath(
      new Rectangle(0, 0, Width, Height), (int)Math.Max(1,surface?.Radius ?? 7));
    var old = Region;
    Region = new Region(path);
    old?.Dispose();
  }

  protected override void OnPaint(PaintEventArgs e) {
    base.OnPaint(e);
    var bounds = new Rectangle(2,2,Math.Max(1,Width-5),Math.Max(1,Height-5));
    using var path=WidgetEditorStyle.RoundedPath(bounds,(int)Math.Max(1,surface.Radius));
    using var brush=new SolidBrush(BackColor);e.Graphics.FillPath(brush,path);
    if(surface.Border || ContainsFocus) {
      using var pen=new Pen(ContainsFocus?palette.Accent:surface.Resolve(palette.Border,true),ContainsFocus?2:Math.Max(0.5f,surface.Thickness));
      e.Graphics.DrawPath(pen,path);
    }
  }

  private static Color ParseColor(string? value,Color fallback) => value!=null && System.Text.RegularExpressions.Regex.IsMatch(value,"^#[0-9a-fA-F]{6}$")?ColorTranslator.FromHtml(value):fallback;

  private void EditorKeyDown(object? sender, KeyEventArgs eventArgs) {
    if (eventArgs.KeyCode == Keys.Escape) {
      eventArgs.SuppressKeyPress = true;
      Close();
      return;
    }
    if (eventArgs.KeyCode != Keys.Enter || eventArgs.Modifiers != Keys.None) return;
    eventArgs.SuppressKeyPress = true;
    var title = editor.Text.Trim();
    if (title.Length == 0) {
      feedback.Text = "Enter a task title.";
      feedback.Visible = true;
      Height = Math.Max(58, Height);
      System.Media.SystemSounds.Beep.Play();
      return;
    }
    try {
      submit(title);
      editor.Clear();
      DialogResult = DialogResult.OK;
      Close();
    } catch (Exception error) {
      feedback.Text = error.Message;
      feedback.Visible = true;
      Height = Math.Max(68, Height);
    }
  }

  protected override void OnShown(EventArgs eventArgs) {
    base.OnShown(eventArgs);
    Activate();
    editor.Focus();
  }
}
