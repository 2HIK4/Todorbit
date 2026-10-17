using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;

internal enum WidgetHostMode {
  Standalone,
  LegacyReparent,
}

internal sealed class LifeManagerWidget : Form {
  private const long WsChild = 0x40000000;
  private const long WsPopup = 0x80000000;
  private const long WsOverlappedWindow = 0x00CF0000;
  private const uint SwpFrameChanged = 0x0020;
  private const uint SwpShowWindow = 0x0040;
  private const uint SwpNoActivate = 0x0010;
  private const uint RdwInvalidate = 0x0001;
  private const uint RdwErase = 0x0004;
  private const uint RdwAllChildren = 0x0080;
  private const uint RdwUpdateNow = 0x0100;
  private static readonly nint HwndTop = 0;

  private readonly LifeManagerWidgetRepository repository;
  private readonly string? appExe;
  private readonly WidgetPalette palette;
  private readonly WidgetHostMode hostMode;
  private readonly WidgetRenderDiagnostics renderDiagnostics;
  private readonly nint shellParent;
  private readonly Native.Point shellPosition;
  private readonly BufferedFlowLayoutPanel taskList = new();
  private readonly Label status = new();
  private readonly Button addButton = new();
  private readonly Button refreshButton = new();
  private readonly Button openButton = new();
  private readonly Button closeButton = new();
  private bool busy;

  internal LifeManagerWidget(
      LifeManagerWidgetRepository repository, string? appExe,
      bool lightTheme, WidgetHostMode hostMode, bool diagnostics) {
    this.repository = repository;
    this.appExe = appExe;
    this.hostMode = hostMode;
    palette = lightTheme ? WidgetPalette.Light : WidgetPalette.Dark;
    renderDiagnostics = new WidgetRenderDiagnostics(diagnostics);
    if (hostMode == WidgetHostMode.LegacyReparent) {
      (shellParent, shellPosition) = ResolveDesktopIconHost();
    }
    Text = "Life Manager Desktop Widget";
    FormBorderStyle = hostMode == WidgetHostMode.Standalone
      ? FormBorderStyle.FixedSingle
      : FormBorderStyle.None;
    StartPosition = FormStartPosition.Manual;
    ClientSize = new Size(376, 460);
    BackColor = palette.Background;
    ForeColor = palette.Foreground;
    ShowInTaskbar = hostMode == WidgetHostMode.Standalone;
    MaximizeBox = false;
    Font = new Font("Segoe UI", 9.5f);
    Padding = new Padding(16);
    SetStyle(ControlStyles.UserPaint |
      ControlStyles.AllPaintingInWmPaint |
      ControlStyles.OptimizedDoubleBuffer |
      ControlStyles.ResizeRedraw, true);

    var header = new Label {
      Text = "Life Manager",
      Font = new Font("Segoe UI Semibold", 15, FontStyle.Bold),
      ForeColor = palette.Foreground,
      Location = new Point(16, 14),
      Size = new Size(170, 30),
    };
    var date = new Label {
      Text = DateTime.Now.ToString("dddd, MMM d"),
      ForeColor = palette.Muted,
      Location = new Point(17, 44),
      Size = new Size(180, 22),
    };
    ConfigureHeaderButton(refreshButton, "Refresh", 190, 64, palette);
    ConfigureHeaderButton(openButton, "Open", 258, 48, palette);
    ConfigureHeaderButton(closeButton, "Close", 310, 50, palette);
    refreshButton.Click += (_, _) => RefreshTasks();
    openButton.Click += (_, _) => OpenMainApp();
    closeButton.Click += (_, _) => Close();

    taskList.Location = new Point(16, 82);
    taskList.Size = new Size(344, 302);
    taskList.FlowDirection = FlowDirection.TopDown;
    taskList.WrapContents = false;
    taskList.AutoScroll = true;
    taskList.BackColor = palette.Panel;
    taskList.Padding = new Padding(7);

    addButton.Text = "+  Add a task for today";
    addButton.Location = new Point(16, 397);
    addButton.Size = new Size(344, 40);
    addButton.FlatStyle = FlatStyle.Flat;
    addButton.FlatAppearance.BorderColor = palette.AccentBorder;
    addButton.BackColor = palette.Accent;
    addButton.ForeColor = Color.White;
    addButton.Font = new Font("Segoe UI Semibold", 10, FontStyle.Bold);
    addButton.Click += (_, _) => OpenQuickAdd();

    status.Location = new Point(16, 439);
    status.Size = new Size(344, 18);
    status.ForeColor = palette.Muted;
    status.Font = new Font("Segoe UI", 8);
    status.TextAlign = ContentAlignment.MiddleCenter;

    Controls.AddRange([
      header, date, refreshButton, openButton, closeButton,
      taskList, addButton, status,
    ]);
  }

  protected override void OnShown(EventArgs eventArgs) {
    base.OnShown(eventArgs);
    if (hostMode == WidgetHostMode.LegacyReparent &&
        !AttachToDesktopIconHostLegacy()) {
      MessageBox.Show(
        "Explorer's desktop icon host was not available. The widget was not attached.",
        "Life Manager widget", MessageBoxButtons.OK, MessageBoxIcon.Error);
      Close();
      return;
    }
    RefreshTasks();
    PresentChanges("shown");
    renderDiagnostics.Snapshot(this, "shown");
  }

  protected override void OnHandleCreated(EventArgs eventArgs) {
    base.OnHandleCreated(eventArgs);
    renderDiagnostics.Snapshot(this, "handle-created");
  }

  protected override void WndProc(ref Message message) {
    renderDiagnostics.Message(this, message.Msg);
    base.WndProc(ref message);
  }

  protected override void OnPaint(PaintEventArgs eventArgs) {
    base.OnPaint(eventArgs);
    using var border = new Pen(palette.Border);
    eventArgs.Graphics.DrawRectangle(border, 0, 0,
      ClientSize.Width - 1, ClientSize.Height - 1);
  }

  private static (nint Parent, Native.Point Position) ResolveDesktopIconHost() {
    var shell = Native.GetShellWindow();
    if (shell == 0 || Native.ClassName(shell) != "Progman" ||
        !Native.IsWindowVisible(shell)) {
      throw new InvalidOperationException(
        "Explorer's visible Progman shell window is unavailable.");
    }
    var desktopIconHost = Native.GetWindow(shell, 5u);
    if (desktopIconHost == 0 ||
        Native.ClassName(desktopIconHost) != "SHELLDLL_DefView" ||
        !Native.IsWindow(desktopIconHost)) {
      throw new InvalidOperationException(
        "Explorer's desktop icon host is unavailable.");
    }

    var primary = Screen.PrimaryScreen?.WorkingArea;
    if (primary is null) {
      throw new InvalidOperationException("No primary display is available.");
    }
    var screenPoint = new Native.Point {
      X = primary.Value.Right - 376 - 24,
      Y = primary.Value.Top + 24,
    };
    if (!Native.ScreenToClient(desktopIconHost, ref screenPoint)) {
      throw new InvalidOperationException(
        "The widget position could not be mapped into Explorer coordinates.");
    }
    return (desktopIconHost, screenPoint);
  }

  private bool AttachToDesktopIconHostLegacy() {
    var originalStyle = Native.GetWindowLongPtr(Handle, -16);
    var childStyle =
      (originalStyle.ToInt64() & ~(WsPopup | WsOverlappedWindow)) | WsChild;
    Native.SetWindowLongPtr(Handle, -16, (nint)childStyle);
    Native.SetParent(Handle, shellParent);
    if (Native.GetParent(Handle) != shellParent) {
      Native.SetWindowLongPtr(Handle, -16, originalStyle);
      return false;
    }
    return Native.SetWindowPos(Handle, HwndTop,
      shellPosition.X, shellPosition.Y,
      ClientSize.Width, ClientSize.Height,
      SwpFrameChanged | SwpShowWindow | SwpNoActivate);
  }

  private void RefreshTasks() {
    if (busy) return;
    RunAction(() => {
      var tasks = repository.LoadTasks(DateTime.Now);
      taskList.SuspendLayout();
      try {
        while (taskList.Controls.Count > 0) {
          taskList.Controls[0].Dispose();
        }
        if (tasks.Count == 0) {
          taskList.Controls.Add(new Label {
            Text = "Nothing due today\nYour Inbox is clear.",
            TextAlign = ContentAlignment.MiddleCenter,
            ForeColor = palette.Muted,
            Font = new Font("Segoe UI", 10),
            Size = new Size(330, 260),
          });
        } else {
          foreach (var task in tasks) taskList.Controls.Add(TaskRow(task));
        }
      } finally {
        taskList.ResumeLayout();
      }
      status.Text = $"Updated {DateTime.Now:h:mm tt}";
      PresentChanges("tasks-refreshed");
    });
  }

  private Control TaskRow(WidgetTask task) {
    var row = new Panel {
      Size = new Size(316, 46),
      Margin = new Padding(0, 0, 0, 5),
      BackColor = palette.Row,
    };
    var checkbox = new CheckBox {
      Location = new Point(9, 12),
      Size = new Size(24, 24),
      FlatStyle = FlatStyle.Flat,
      Cursor = Cursors.Hand,
      AccessibleName = $"Complete {task.Title}",
    };
    var title = new Label {
      Text = task.Title,
      AutoEllipsis = true,
      Location = new Point(38, 8),
      Size = new Size(267, 31),
      TextAlign = ContentAlignment.MiddleLeft,
      ForeColor = palette.Foreground,
    };
    checkbox.CheckedChanged += (_, _) => {
      if (!checkbox.Checked) return;
      RunAction(() => repository.CompleteTask(task.Id));
      RefreshTasks();
    };
    row.Controls.AddRange([checkbox, title]);
    return row;
  }

  private void OpenQuickAdd() {
    using var dialog = new QuickAddDialog(palette);
    var popupPoint = PointToScreen(new Point(8, ClientSize.Height + 8));
    var working = Screen.FromPoint(popupPoint).WorkingArea;
    dialog.Location = new Point(
      Math.Clamp(popupPoint.X, working.Left, working.Right - dialog.Width),
      Math.Clamp(popupPoint.Y, working.Top, working.Bottom - dialog.Height));
    if (dialog.ShowDialog() != DialogResult.OK) return;
    RunAction(() => repository.AddTask(dialog.TaskTitle, DateTime.Now));
    RefreshTasks();
  }

  private void OpenMainApp() {
    try {
      var path = ResolveMainApp();
      Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
      status.Text = "Main app opened";
    } catch (Exception error) {
      ShowError(error.Message);
    }
  }

  private string ResolveMainApp() {
    if (!string.IsNullOrWhiteSpace(appExe) && File.Exists(appExe)) {
      return Path.GetFullPath(appExe);
    }
    var sibling = Path.Combine(AppContext.BaseDirectory, "life_manager.exe");
    if (File.Exists(sibling)) return sibling;
    throw new FileNotFoundException(
      "Pass --app-exe PATH when the main executable is not beside the widget.");
  }

  private void RunAction(Action action) {
    if (busy) return;
    busy = true;
    SetControlsEnabled(false);
    try {
      action();
    } catch (Exception error) {
      ShowError(error.Message);
    } finally {
      busy = false;
      SetControlsEnabled(true);
    }
  }

  private void SetControlsEnabled(bool enabled) {
    addButton.Enabled = enabled;
    refreshButton.Enabled = enabled;
    openButton.Enabled = enabled;
  }

  private void PresentChanges(string reason) {
    if (!IsHandleCreated) return;
    Native.RedrawWindow(Handle, 0, 0,
      RdwInvalidate | RdwErase | RdwAllChildren | RdwUpdateNow);
    renderDiagnostics.Snapshot(this, reason);
  }

  private void ShowError(string message) {
    status.Text = "Action failed";
    MessageBox.Show(message, "Life Manager widget",
      MessageBoxButtons.OK, MessageBoxIcon.Error);
  }

  private static void ConfigureHeaderButton(
      Button button, string text, int x, int width, WidgetPalette palette) {
    button.Text = text;
    button.Location = new Point(x, 17);
    button.Size = new Size(width, 30);
    button.FlatStyle = FlatStyle.Flat;
    button.FlatAppearance.BorderSize = 0;
    button.BackColor = palette.Row;
    button.ForeColor = palette.Foreground;
    button.Font = new Font("Segoe UI", 8);
  }


  protected override void Dispose(bool disposing) {
    if (disposing) renderDiagnostics.Dispose();
    base.Dispose(disposing);
  }
}

internal sealed class BufferedFlowLayoutPanel : FlowLayoutPanel {
  internal BufferedFlowLayoutPanel() {
    DoubleBuffered = true;
    SetStyle(ControlStyles.AllPaintingInWmPaint |
      ControlStyles.OptimizedDoubleBuffer |
      ControlStyles.ResizeRedraw, true);
  }
}

internal sealed class QuickAddDialog : Form {
  private readonly TextBox editor = new();
  internal string TaskTitle => editor.Text.Trim();

  internal QuickAddDialog(WidgetPalette palette) {
    Text = "Quick Add - Life Manager";
    FormBorderStyle = FormBorderStyle.FixedDialog;
    StartPosition = FormStartPosition.Manual;
    ClientSize = new Size(376, 142);
    MaximizeBox = false;
    MinimizeBox = false;
    ShowInTaskbar = true;
    BackColor = palette.Background;
    ForeColor = palette.Foreground;
    Font = new Font("Segoe UI", 9.5f);

    var label = new Label {
      Text = "Add a task for today",
      Location = new Point(14, 13),
      Size = new Size(340, 22),
    };
    editor.Location = new Point(14, 40);
    editor.Size = new Size(346, 28);
    editor.PlaceholderText = "What needs to be done?";
    editor.BackColor = palette.Panel;
    editor.ForeColor = palette.Foreground;

    var add = new Button {
      Text = "Add task",
      DialogResult = DialogResult.OK,
      Location = new Point(254, 88),
      Size = new Size(106, 36),
      BackColor = palette.Accent,
      ForeColor = Color.White,
      FlatStyle = FlatStyle.Flat,
    };
    var cancel = new Button {
      Text = "Cancel",
      DialogResult = DialogResult.Cancel,
      Location = new Point(144, 88),
      Size = new Size(102, 36),
      FlatStyle = FlatStyle.Flat,
      ForeColor = palette.Foreground,
    };
    AcceptButton = add;
    CancelButton = cancel;
    Controls.AddRange([label, editor, cancel, add]);
  }

  protected override void OnShown(EventArgs eventArgs) {
    base.OnShown(eventArgs);
    Activate();
    editor.Focus();
  }

  protected override void OnFormClosing(FormClosingEventArgs eventArgs) {
    if (DialogResult == DialogResult.OK && TaskTitle.Length == 0) {
      eventArgs.Cancel = true;
      System.Media.SystemSounds.Beep.Play();
      editor.Focus();
    }
    base.OnFormClosing(eventArgs);
  }
}

internal sealed record WidgetPalette(
  Color Background,
  Color Foreground,
  Color Muted,
  Color Panel,
  Color Row,
  Color Accent,
  Color AccentBorder,
  Color Border
) {
  internal static WidgetPalette Dark { get; } = new(
    Color.FromArgb(24, 27, 39), Color.FromArgb(239, 240, 246),
    Color.FromArgb(169, 174, 195), Color.FromArgb(31, 35, 50),
    Color.FromArgb(38, 43, 61), Color.FromArgb(70, 82, 157),
    Color.FromArgb(111, 124, 219), Color.FromArgb(58, 63, 84));

  internal static WidgetPalette Light { get; } = new(
    Color.FromArgb(247, 248, 252), Color.FromArgb(31, 34, 48),
    Color.FromArgb(94, 99, 120), Color.White,
    Color.FromArgb(238, 240, 248), Color.FromArgb(83, 101, 181),
    Color.FromArgb(83, 101, 181), Color.FromArgb(214, 217, 229));
}
