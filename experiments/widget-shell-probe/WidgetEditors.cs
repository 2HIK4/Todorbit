// The desktop-attached HWND cannot own keyboard focus reliably. This short-lived,
// activatable top-level surface is aligned over the painted Quick Add field so the
// interaction remains visually inline without putting child controls in Explorer.
internal sealed class InlineQuickAddForm : Form {
  private readonly TextBox editor = new();
  private readonly Label feedback = new();
  private readonly Action<string> submit;
  private readonly WidgetPalette palette;

  internal InlineQuickAddForm(
      WidgetPalette palette, Rectangle bounds, string destination,
      Action<string> submit) {
    this.palette = palette;
    this.submit = submit;
    Text = "Quick Add - Todorbit";
    FormBorderStyle = FormBorderStyle.None;
    StartPosition = FormStartPosition.Manual;
    ShowInTaskbar = false;
    TopMost = false;
    Bounds = bounds;
    BackColor = palette.Panel;
    ForeColor = palette.Foreground;
    Font = new Font("Segoe UI", 9.5f);
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
    editor.BackColor = palette.Panel;
    editor.ForeColor = palette.Foreground;
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
      new Rectangle(0, 0, Width, Height), WidgetEditorStyle.Corner);
    var old = Region;
    Region = new Region(path);
    old?.Dispose();
  }

  protected override void OnPaint(PaintEventArgs e) {
    base.OnPaint(e);
    WidgetEditorStyle.PaintSurface(e.Graphics,
      new Rectangle(1, 1, Math.Max(1, Width - 3), Math.Max(1, Height - 3)),
      palette, ContainsFocus);
  }

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
