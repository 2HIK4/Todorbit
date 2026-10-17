using System.Diagnostics;
using System.Drawing.Drawing2D;

internal sealed class NativeWidgetApplicationContext : ApplicationContext {
  private readonly LifeManagerWidgetRepository repository;
  private readonly string? appExe;
  private readonly bool diagnostics;
  private readonly WidgetSettingsStore settingsStore = new();
  private readonly WidgetSettings settings;
  private readonly WidgetCommandServer commandServer;
  private readonly SynchronizationContext uiContext;
  private readonly NotifyIcon trayIcon;
  private readonly FileSystemWatcher databaseWatcher;
  private readonly System.Windows.Forms.Timer refreshDebounce;
  private readonly System.Windows.Forms.Timer explorerRecovery;
  private NativeDesktopWidgetHost? host;
  private readonly ExplorerRecoveryPolicy recoveryPolicy = new();

  internal NativeWidgetApplicationContext(
      LifeManagerWidgetRepository repository, string? appExe,
      bool diagnostics, string initialCommand) {
    this.repository = repository;
    this.appExe = appExe;
    this.diagnostics = diagnostics;
    settings = settingsStore.Load();
    SynchronizationContext.SetSynchronizationContext(
      SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext());
    uiContext = SynchronizationContext.Current!;

    refreshDebounce = new System.Windows.Forms.Timer { Interval = 250 };
    refreshDebounce.Tick += (_, _) => {
      refreshDebounce.Stop();
      host?.RefreshFromDatabase();
    };
    databaseWatcher = new FileSystemWatcher(
      Path.GetDirectoryName(repository.DatabasePath)!,
      Path.GetFileName(repository.DatabasePath) + "*") {
      NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.Size |
        NotifyFilters.FileName,
      EnableRaisingEvents = true,
    };
    databaseWatcher.Changed += DatabaseChanged;
    databaseWatcher.Created += DatabaseChanged;
    databaseWatcher.Renamed += DatabaseChanged;

    explorerRecovery = new System.Windows.Forms.Timer { Interval = 1000 };
    explorerRecovery.Tick += (_, _) => RecoverAfterExplorerRestart();
    commandServer = new WidgetCommandServer(ExecuteCommand);
    trayIcon = BuildTrayIcon();
    trayIcon.Visible = true;
    CreateHost();
    ExecuteCommand(initialCommand);
  }

  private NotifyIcon BuildTrayIcon() {
    var menu = new ContextMenuStrip();
    menu.Items.Add("Open Life Manager", null, (_, _) => OpenMainApp());
    menu.Items.Add("Show / hide widget", null, (_, _) => ExecuteCommand("toggle"));
    menu.Items.Add("Quick Add", null, (_, _) => ExecuteCommand("quick-add"));
    var view = new ToolStripMenuItem("Task view");
    view.DropDownItems.Add("Today", null, (_, _) => ExecuteCommand("view-today"));
    view.DropDownItems.Add("Inbox", null, (_, _) => ExecuteCommand("view-inbox"));
    menu.Items.Add(view);
    var theme = new ToolStripMenuItem("Appearance");
    theme.DropDownItems.Add("System", null, (_, _) => ExecuteCommand("theme-system"));
    theme.DropDownItems.Add("Light", null, (_, _) => ExecuteCommand("theme-light"));
    theme.DropDownItems.Add("Dark", null, (_, _) => ExecuteCommand("theme-dark"));
    menu.Items.Add(theme);
    menu.Items.Add(new ToolStripSeparator());
    var launch = new ToolStripMenuItem("Launch at Windows sign-in") {
      Checked = StartupRegistration.IsEnabled(),
    };
    launch.Click += (_, _) => {
      try {
        var enabled = !launch.Checked;
        StartupRegistration.SetEnabled(enabled);
        launch.Checked = enabled;
        settings.LaunchAtSignIn = enabled;
        settingsStore.Save(settings);
      } catch (Exception error) {
        launch.Checked = StartupRegistration.IsEnabled();
        MessageBox.Show(error.Message, "Life Manager widget",
          MessageBoxButtons.OK, MessageBoxIcon.Error);
      }
    };
    menu.Items.Add(launch);
    menu.Items.Add("Exit widget", null, (_, _) => ExitThread());
    menu.Items.Add("Exit Life Manager completely", null, (_, _) => ExitCompletely());
    var icon = new NotifyIcon {
      Icon = SystemIcons.Application,
      Text = "Life Manager",
      ContextMenuStrip = menu,
    };
    icon.DoubleClick += (_, _) => ExecuteCommand("toggle");
    return icon;
  }

  private void DatabaseChanged(object sender, FileSystemEventArgs args) {
    uiContext.Post(_ => {
      try {
        refreshDebounce.Stop();
        refreshDebounce.Start();
      } catch (InvalidOperationException) { }
    }, null);
  }

  private void ExecuteCommand(string command) {
    switch (command.ToLowerInvariant()) {
      case "show": EnsureHost(); host?.Show(); break;
      case "hide": host?.Hide(); break;
      case "toggle": EnsureHost(); host?.Toggle(); break;
      case "quick-add": EnsureHost(); host?.OpenQuickAddDialog(); break;
      case "refresh": host?.RefreshFromDatabase(); break;
      case "theme-system": SetTheme(WidgetThemePreference.System); break;
      case "theme-light": SetTheme(WidgetThemePreference.Light); break;
      case "theme-dark": SetTheme(WidgetThemePreference.Dark); break;
      case "view-today": SetView(WidgetTaskView.Today); break;
      case "view-inbox": SetView(WidgetTaskView.Inbox); break;
      case "exit": ExitThread(); break;
    }
  }

  private void SetTheme(WidgetThemePreference value) {
    settings.Theme = value;
    settingsStore.Save(settings);
    host?.SetPalette(ResolvePalette(value));
  }

  private void SetView(WidgetTaskView value) {
    settings.View = value;
    settingsStore.Save(settings);
    host?.SetView(value);
  }

  private static WidgetPalette ResolvePalette(WidgetThemePreference value) =>
    value switch {
      WidgetThemePreference.Light => WidgetPalette.Light,
      WidgetThemePreference.Dark => WidgetPalette.Dark,
      _ => SystemDarkMode() ? WidgetPalette.Dark : WidgetPalette.Light,
    };

  private static bool SystemDarkMode() {
    using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
      @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
    return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
  }

  private void CreateHost() {
    try {
      host = new NativeDesktopWidgetHost(repository, appExe,
        ResolvePalette(settings.Theme), settings, settingsStore, diagnostics,
        HostDestroyed, ExitThread);
      recoveryPolicy.Reset();
      explorerRecovery.Stop();
    } catch (InvalidOperationException) {
      ScheduleExplorerRecovery();
    }
  }

  private void EnsureHost() {
    if (host == null || host.Handle == 0) CreateHost();
  }

  private void HostDestroyed() {
    host = null;
    ScheduleExplorerRecovery();
  }

  private void ScheduleExplorerRecovery() {
    if (recoveryPolicy.CanRetry) explorerRecovery.Start();
  }

  private void RecoverAfterExplorerRestart() {
    recoveryPolicy.RecordFailure();
    CreateHost();
    if (host != null || !recoveryPolicy.CanRetry) explorerRecovery.Stop();
  }

  private void OpenMainApp() {
    try {
      Process.Start(new ProcessStartInfo(ResolveMainApp()) { UseShellExecute = true });
    } catch (Exception error) {
      MessageBox.Show(error.Message, "Life Manager widget",
        MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
  }

  private string ResolveMainApp() {
    if (!string.IsNullOrWhiteSpace(appExe) && File.Exists(appExe)) {
      return Path.GetFullPath(appExe);
    }
    var sibling = Path.Combine(AppContext.BaseDirectory, "life_manager.exe");
    if (File.Exists(sibling)) return sibling;
    throw new FileNotFoundException("Life Manager is not beside the widget executable.");
  }

  private void ExitCompletely() {
    if (MessageBox.Show("Close the widget and all running Life Manager windows?",
        "Exit Life Manager", MessageBoxButtons.YesNo,
        MessageBoxIcon.Question) != DialogResult.Yes) return;
    try {
      var expected = Path.GetFullPath(ResolveMainApp());
      foreach (var process in Process.GetProcessesByName("life_manager")) {
        try {
          if (string.Equals(process.MainModule?.FileName, expected,
              StringComparison.OrdinalIgnoreCase)) process.CloseMainWindow();
        } catch { }
        finally { process.Dispose(); }
      }
    } catch (FileNotFoundException) { }
    ExitThread();
  }

  protected override void Dispose(bool disposing) {
    if (disposing) {
      trayIcon.Visible = false;
      trayIcon.Dispose();
      commandServer.Dispose();
      databaseWatcher.Dispose();
      refreshDebounce.Dispose();
      explorerRecovery.Dispose();
      host?.Dispose();
      host = null;
    }
    base.Dispose(disposing);
  }
}

// A single owner-drawn HWND is created as an Explorer child from the beginning.
// Unlike a WinForms Form, NativeWindow does not park or reparent the HWND.
internal sealed class NativeDesktopWidgetHost : NativeWindow, IDisposable {
  private const int LogicalWidth = 376;
  private const int LogicalHeight = 460;
  private const int WmDestroy = 0x0002;
  private const int WmPaint = 0x000F;
  private const int WmEraseBackground = 0x0014;
  private const int WmMouseMove = 0x0200;
  private const int WmLeftButtonDown = 0x0201;
  private const int WmMouseLeave = 0x02A3;
  private const int WmLeftButtonUp = 0x0202;
  private const int WmMouseWheel = 0x020A;
  private const int WmDisplayChange = 0x007E;
  private const int WsChild = 0x40000000;
  private const int WsVisible = 0x10000000;
  private const int WsClipChildren = 0x02000000;
  private const int WsClipSiblings = 0x04000000;
  private const uint SwpNoActivate = 0x0010;
  private const uint RdwInvalidate = 0x0001;
  private const uint RdwErase = 0x0004;
  private const uint RdwUpdateNow = 0x0100;

  private readonly LifeManagerWidgetRepository repository;
  private readonly string? appExe;
  private WidgetPalette palette;
  private readonly WidgetSettings settings;
  private readonly WidgetSettingsStore settingsStore;
  private readonly WidgetRenderDiagnostics diagnostics;
  private readonly Action unexpectedDestroy;
  private readonly Action exit;
  private IReadOnlyList<WidgetTask> tasks = [];
  private float scale = 1f;
  private int scrollOffset;
  private HitTarget hoverTarget = HitTarget.None;
  private int hoverTask = -1;
  private string statusText = "Loading...";
  private bool disposed;
  private bool dragging;
  private bool resizing;
  private Native.Point dragStart;
  private Native.Rect dragBounds;

  internal NativeDesktopWidgetHost(
      LifeManagerWidgetRepository repository, string? appExe,
      WidgetPalette palette, WidgetSettings settings,
      WidgetSettingsStore settingsStore, bool diagnosticsEnabled,
      Action unexpectedDestroy, Action exit) {
    this.repository = repository;
    this.appExe = appExe;
    this.palette = palette;
    this.settings = settings;
    this.settingsStore = settingsStore;
    this.unexpectedDestroy = unexpectedDestroy;
    this.exit = exit;
    diagnostics = new WidgetRenderDiagnostics(diagnosticsEnabled);
    var (parent, position) = ResolveDesktopIconHost(settings);
    var screen = Screen.AllScreens.FirstOrDefault(item =>
      item.DeviceName == settings.MonitorDeviceName) ?? Screen.PrimaryScreen!;
    scale = ScaleForScreen(screen);
    var parameters = new CreateParams {
      Caption = "Life Manager Desktop Widget",
      Parent = parent,
      X = position.X,
      Y = position.Y,
      Width = Pixel(Math.Clamp(settings.Width, 340, 520)),
      Height = Pixel(Math.Clamp(settings.Height, 420, 720)),
      Style = WsChild | WsVisible | WsClipChildren | WsClipSiblings,
    };
    CreateHandle(parameters);
    settingsStore.Save(settings);
    diagnostics.Snapshot(Handle, "native-handle-created");
    RefreshTasks();
  }

  protected override void WndProc(ref Message message) {
    diagnostics.Message(Handle, message.Msg);
    switch (message.Msg) {
      case WmPaint:
        PaintWindow();
        message.Result = 0;
        return;
      case WmEraseBackground:
        message.Result = 1;
        return;
      case WmMouseMove:
        MouseMove(LogicalPoint(message.LParam));
        message.Result = 0;
        return;
      case WmLeftButtonDown:
        BeginMoveOrResize(LogicalPoint(message.LParam));
        message.Result = 0;
        return;
      case WmMouseLeave:
        SetHover(HitTarget.None, -1);
        message.Result = 0;
        return;
      case WmLeftButtonUp:
        if (dragging || resizing) EndMoveOrResize();
        else Click(LogicalPoint(message.LParam));
        message.Result = 0;
        return;
      case WmMouseWheel:
        var delta = unchecked((short)((message.WParam.ToInt64() >> 16) & 0xFFFF));
        Scroll(delta > 0 ? -1 : 1);
        message.Result = 0;
        return;
      case WmDisplayChange:
        Reposition();
        Present("display-change");
        break;
      case WmDestroy:
        if (!disposed) {
          disposed = true;
          diagnostics.Dispose();
          unexpectedDestroy();
        }
        break;
    }
    base.WndProc(ref message);
  }

  private void PaintWindow() {
    var paintDc = Native.BeginPaint(Handle, out var paint);
    if (paintDc == 0) return;
    try {
      Native.GetClientRect(Handle, out var client);
      var size = new Size(client.Right - client.Left, client.Bottom - client.Top);
      if (size.Width <= 0 || size.Height <= 0) return;
      using var target = Graphics.FromHdc(paintDc);
      using var buffer = BufferedGraphicsManager.Current.Allocate(
        target, new Rectangle(Point.Empty, size));
      var graphics = buffer.Graphics;
      graphics.Clear(palette.Background);
      graphics.SmoothingMode = SmoothingMode.AntiAlias;
      graphics.TextRenderingHint =
        System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
      graphics.ScaleTransform(scale, scale);
      DrawWidget(graphics);
      buffer.Render(target);
    } finally {
      Native.EndPaint(Handle, ref paint);
    }
  }

  private void DrawWidget(Graphics graphics) {
    var logicalWidth = LogicalClientWidth;
    var logicalHeight = LogicalClientHeight;
    using var border = new Pen(palette.Border);
    graphics.DrawRectangle(border, 0, 0, logicalWidth - 1, logicalHeight - 1);
    using var titleFont = new Font("Segoe UI Semibold", 15, FontStyle.Bold);
    using var bodyFont = new Font("Segoe UI", 9.5f);
    using var smallFont = new Font("Segoe UI", 8);
    using var buttonFont = new Font("Segoe UI Semibold", 8.5f, FontStyle.Bold);
    using var taskFont = new Font("Segoe UI", 9.5f);
    using var foreground = new SolidBrush(palette.Foreground);
    using var muted = new SolidBrush(palette.Muted);

    graphics.DrawString($"Life Manager - {settings.View}", titleFont, foreground,
      new RectangleF(16, 12, Math.Max(80, RefreshRect.Left - 24), 32));
    graphics.DrawString(DateTime.Now.ToString("dddd, MMM d"), bodyFont, muted,
      new RectangleF(17, 43, 170, 24));
    DrawButton(graphics, RefreshRect, "Refresh", buttonFont,
      hoverTarget == HitTarget.Refresh);
    DrawButton(graphics, OpenRect, "Open", buttonFont,
      hoverTarget == HitTarget.Open);
    DrawButton(graphics, CloseRect, "Close", buttonFont,
      hoverTarget == HitTarget.Close);

    using (var panel = new SolidBrush(palette.Panel)) {
      FillRoundedRectangle(graphics, panel, TaskArea, 8);
    }
    if (tasks.Count == 0) {
      using var emptyFormat = CenterFormat();
      var emptyText = settings.View == WidgetTaskView.Today
        ? "Nothing planned for today." : "Your Inbox is clear.";
      graphics.DrawString(emptyText,
        bodyFont, muted, TaskArea, emptyFormat);
    } else {
      var end = Math.Min(tasks.Count, scrollOffset + VisibleTaskRows);
      for (var index = scrollOffset; index < end; index++) {
        DrawTask(graphics, tasks[index], index,
          index - scrollOffset, taskFont);
      }
      if (tasks.Count > VisibleTaskRows) {
        var range = $"{scrollOffset + 1}-{end} of {tasks.Count} - scroll";
        using var rangeFormat = new StringFormat {
          Alignment = StringAlignment.Far,
          LineAlignment = StringAlignment.Far,
        };
        graphics.DrawString(range, smallFont, muted,
          new RectangleF(24, TaskArea.Bottom - 30,
            logicalWidth - 50, 23), rangeFormat);
      }
    }

    using (var accent = new SolidBrush(palette.Accent)) {
      FillRoundedRectangle(graphics, accent, AddRect, 7);
    }
    if (hoverTarget == HitTarget.Add) {
      using var hover = new SolidBrush(Color.FromArgb(28, Color.White));
      FillRoundedRectangle(graphics, hover, AddRect, 7);
    }
    using var white = new SolidBrush(Color.White);
    using var addFormat = CenterFormat();
    using var addFont = new Font("Segoe UI Semibold", 10, FontStyle.Bold);
    graphics.DrawString("+  Add a task for today",
      addFont, white,
      AddRect, addFormat);
    using var statusFormat = CenterFormat();
    graphics.DrawString(statusText, smallFont, muted,
      new RectangleF(16, logicalHeight - 21, logicalWidth - 32, 18), statusFormat);
  }

  private void DrawTask(Graphics graphics, WidgetTask task,
      int taskIndex, int visibleIndex, Font font) {
    var row = TaskRowRect(visibleIndex);
    using var rowBrush = new SolidBrush(palette.Row);
    FillRoundedRectangle(graphics, rowBrush, row, 6);
    if (hoverTarget == HitTarget.Task && hoverTask == taskIndex) {
      using var hover = new SolidBrush(Color.FromArgb(
        palette == WidgetPalette.Dark ? 22 : 12, palette.Foreground));
      FillRoundedRectangle(graphics, hover, row, 6);
    }
    var box = CheckboxRect(visibleIndex);
    using var boxPen = new Pen(palette.AccentBorder, 1.5f);
    graphics.DrawRectangle(boxPen, box.X, box.Y, box.Width, box.Height);
    using var textBrush = new SolidBrush(palette.Foreground);
    using var format = new StringFormat {
      LineAlignment = StringAlignment.Center,
      Trimming = StringTrimming.EllipsisCharacter,
      FormatFlags = StringFormatFlags.NoWrap,
    };
    graphics.DrawString(task.Title, font, textBrush,
      new RectangleF(row.X + 38, row.Y + 3, row.Width - 48, row.Height - 6),
      format);
  }

  private void DrawButton(Graphics graphics, RectangleF bounds, string text,
      Font font, bool hovered) {
    var color = hovered ? Blend(palette.Row, palette.Accent, 0.24f) : palette.Row;
    using var brush = new SolidBrush(color);
    FillRoundedRectangle(graphics, brush, bounds, 6);
    using var textBrush = new SolidBrush(palette.Foreground);
    using var format = CenterFormat();
    graphics.DrawString(text, font, textBrush, bounds, format);
  }

  private void MouseMove(PointF point) {
    if (dragging || resizing) {
      ContinueMoveOrResize();
      return;
    }
    var tracking = new Native.TrackMouseEventData {
      Size = (uint)System.Runtime.InteropServices.Marshal.SizeOf<Native.TrackMouseEventData>(),
      Flags = 0x00000002,
      Window = Handle,
    };
    Native.TrackMouseEvent(ref tracking);
    var (target, task) = HitTest(point);
    SetHover(target, task);
    Cursor.Current = IsResizeGrip(point) ? Cursors.SizeNWSE :
      target == HitTarget.None ? Cursors.Default : Cursors.Hand;
  }

  private void BeginMoveOrResize(PointF point) {
    if (HitTest(point).Target != HitTarget.None) return;
    resizing = IsResizeGrip(point);
    dragging = !resizing && point.Y <= 66;
    if (!dragging && !resizing) return;
    Native.GetCursorPos(out dragStart);
    Native.GetWindowRect(Handle, out dragBounds);
    Native.SetCapture(Handle);
  }

  private void ContinueMoveOrResize() {
    if (!Native.GetCursorPos(out var cursor)) return;
    var dx = cursor.X - dragStart.X;
    var dy = cursor.Y - dragStart.Y;
    var width = resizing
      ? Math.Clamp(dragBounds.Right - dragBounds.Left + dx, Pixel(340), Pixel(520))
      : dragBounds.Right - dragBounds.Left;
    var height = resizing
      ? Math.Clamp(dragBounds.Bottom - dragBounds.Top + dy, Pixel(420), Pixel(720))
      : dragBounds.Bottom - dragBounds.Top;
    var screenPoint = new Native.Point {
      X = dragging ? dragBounds.Left + dx : dragBounds.Left,
      Y = dragging ? dragBounds.Top + dy : dragBounds.Top,
    };
    var screen = Screen.FromPoint(new Point(screenPoint.X, screenPoint.Y));
    screenPoint.X = Math.Clamp(screenPoint.X, screen.WorkingArea.Left,
      Math.Max(screen.WorkingArea.Left, screen.WorkingArea.Right - width));
    screenPoint.Y = Math.Clamp(screenPoint.Y, screen.WorkingArea.Top,
      Math.Max(screen.WorkingArea.Top, screen.WorkingArea.Bottom - height));
    var parentPoint = screenPoint;
    if (!Native.ScreenToClient(Native.GetParent(Handle), ref parentPoint)) return;
    Native.SetWindowPos(Handle, 0, parentPoint.X, parentPoint.Y,
      width, height, SwpNoActivate);
    Present("move-resize", updateNow: false);
  }

  private void EndMoveOrResize() {
    dragging = false;
    resizing = false;
    Native.ReleaseCapture();
    if (!Native.GetWindowRect(Handle, out var bounds)) return;
    settings.X = bounds.Left;
    settings.Y = bounds.Top;
    settings.Width = (int)Math.Round((bounds.Right - bounds.Left) / scale);
    settings.Height = (int)Math.Round((bounds.Bottom - bounds.Top) / scale);
    var screen = Screen.FromRectangle(new Rectangle(
      bounds.Left, bounds.Top, bounds.Right - bounds.Left,
      bounds.Bottom - bounds.Top));
    settings.MonitorDeviceName = screen.DeviceName;
    scale = ScaleForScreen(screen);
    settingsStore.Save(settings);
    Reposition();
  }

  private void Click(PointF point) {
    var (target, taskIndex) = HitTest(point);
    switch (target) {
      case HitTarget.Refresh:
        RefreshTasks();
        break;
      case HitTarget.Open:
        OpenMainApp();
        break;
      case HitTarget.Close:
        Dispose();
        exit();
        break;
      case HitTarget.Add:
        OpenQuickAdd();
        break;
      case HitTarget.Task when taskIndex >= 0 && taskIndex < tasks.Count:
        RunAction(() => repository.CompleteTask(tasks[taskIndex].Id));
        RefreshTasks();
        break;
    }
  }

  private (HitTarget Target, int TaskIndex) HitTest(PointF point) {
    if (RefreshRect.Contains(point)) return (HitTarget.Refresh, -1);
    if (OpenRect.Contains(point)) return (HitTarget.Open, -1);
    if (CloseRect.Contains(point)) return (HitTarget.Close, -1);
    if (AddRect.Contains(point)) return (HitTarget.Add, -1);
    var end = Math.Min(tasks.Count, scrollOffset + VisibleTaskRows);
    for (var index = scrollOffset; index < end; index++) {
      var visibleIndex = index - scrollOffset;
      if (CheckboxRect(visibleIndex).Contains(point)) {
        return (HitTarget.Task, index);
      }
    }
    return (HitTarget.None, -1);
  }

  private void SetHover(HitTarget target, int task) {
    if (hoverTarget == target && hoverTask == task) return;
    hoverTarget = target;
    hoverTask = task;
    Present("hover-changed", updateNow: false);
  }

  private void Scroll(int direction) {
    if (tasks.Count <= VisibleTaskRows) return;
    var maximum = Math.Max(0, tasks.Count - VisibleTaskRows);
    var next = Math.Clamp(scrollOffset + direction, 0, maximum);
    if (next == scrollOffset) return;
    scrollOffset = next;
    Present("task-scroll", updateNow: false);
  }

  internal void RefreshFromDatabase() => RefreshTasks();

  internal void SetPalette(WidgetPalette value) {
    palette = value;
    Present("theme-changed");
  }

  internal void SetView(WidgetTaskView value) {
    settings.View = value;
    settingsStore.Save(settings);
    RefreshTasks();
  }

  internal void Show() {
    if (Handle != 0) Native.ShowWindow(Handle, 5);
  }

  internal void Hide() {
    if (Handle != 0) Native.ShowWindow(Handle, 0);
  }

  internal void Toggle() {
    if (Handle != 0) Native.ShowWindow(Handle,
      Native.IsWindowVisible(Handle) ? 0 : 5);
  }

  internal void OpenQuickAddDialog() => OpenQuickAdd();

  private void RefreshTasks() {
    RunAction(() => {
      tasks = repository.LoadTasks(DateTime.Now, settings.View);
      scrollOffset = Math.Min(scrollOffset,
        Math.Max(0, tasks.Count - VisibleTaskRows));
      statusText = $"Updated {DateTime.Now:h:mm tt}";
    });
    Present("tasks-refreshed");
  }

  private void OpenQuickAdd() {
    using var dialog = new QuickAddDialog(palette);
    Native.GetWindowRect(Handle, out var bounds);
    var popupPoint = new Point(bounds.Left + 8, bounds.Bottom + 8);
    var working = Screen.FromPoint(popupPoint).WorkingArea;
    dialog.Location = new Point(
      Math.Clamp(popupPoint.X, working.Left, working.Right - dialog.Width),
      Math.Clamp(popupPoint.Y, working.Top, working.Bottom - dialog.Height));
    if (dialog.ShowDialog() != DialogResult.OK) return;
    RunAction(() => repository.AddTask(dialog.TaskTitle, DateTime.Now));
    RefreshTasks();
  }

  private void OpenMainApp() {
    RunAction(() => {
      var path = ResolveMainApp();
      Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
      statusText = "Main app opened";
    });
    Present("main-app-opened");
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
    try {
      action();
    } catch (Exception error) {
      statusText = "Action failed";
      MessageBox.Show(error.Message, "Life Manager widget",
        MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
  }

  private void Present(string reason, bool updateNow = true) {
    if (Handle == 0) return;
    var flags = RdwInvalidate | RdwErase;
    if (updateNow) flags |= RdwUpdateNow;
    Native.RedrawWindow(Handle, 0, 0, flags);
    diagnostics.Snapshot(Handle, reason);
  }

  private void Reposition() {
    if (Handle == 0) return;
    var parent = Native.GetParent(Handle);
    if (parent == 0 || Native.ClassName(parent) != "SHELLDLL_DefView") return;
    var screen = Screen.AllScreens.FirstOrDefault(item =>
      item.DeviceName == settings.MonitorDeviceName) ?? Screen.PrimaryScreen;
    if (screen is null) return;
    scale = ScaleForScreen(screen);
    var width = Pixel(Math.Clamp(settings.Width, 340, 520));
    var height = Pixel(Math.Clamp(settings.Height, 420, 720));
    var x = Math.Clamp(settings.X, screen.WorkingArea.Left,
      Math.Max(screen.WorkingArea.Left, screen.WorkingArea.Right - width));
    var y = Math.Clamp(settings.Y, screen.WorkingArea.Top,
      Math.Max(screen.WorkingArea.Top, screen.WorkingArea.Bottom - height));
    var point = new Native.Point {
      X = x,
      Y = y,
    };
    if (!Native.ScreenToClient(parent, ref point)) return;
    Native.SetWindowPos(Handle, 0, point.X, point.Y,
      width, height, SwpNoActivate);
    settings.X = x;
    settings.Y = y;
    settingsStore.Save(settings);
  }

  private static (nint Parent, Native.Point Position) ResolveDesktopIconHost(
      WidgetSettings settings) {
    var shell = Native.GetShellWindow();
    if (shell == 0 || Native.ClassName(shell) != "Progman" ||
        !Native.IsWindowVisible(shell)) {
      throw new InvalidOperationException(
        "Explorer's visible Progman shell window is unavailable.");
    }
    var parent = Native.GetWindow(shell, 5u);
    if (parent == 0 || Native.ClassName(parent) != "SHELLDLL_DefView" ||
        !Native.IsWindow(parent)) {
      throw new InvalidOperationException(
        "Explorer's desktop icon host is unavailable.");
    }
    var screen = Screen.AllScreens.FirstOrDefault(item =>
      item.DeviceName == settings.MonitorDeviceName) ?? Screen.PrimaryScreen;
    var working = screen?.WorkingArea;
    if (working is null) {
      throw new InvalidOperationException("No primary display is available.");
    }
    var scale = ScaleForScreen(screen!);
    var width = (int)Math.Round(Math.Clamp(settings.Width, 340, 520) * scale);
    var height = (int)Math.Round(Math.Clamp(settings.Height, 420, 720) * scale);
    var x = settings.X == int.MinValue
      ? working.Value.Right - width - 24 : settings.X;
    var y = settings.Y == int.MinValue ? working.Value.Top + 24 : settings.Y;
    x = Math.Clamp(x, working.Value.Left,
      Math.Max(working.Value.Left, working.Value.Right - width));
    y = Math.Clamp(y, working.Value.Top,
      Math.Max(working.Value.Top, working.Value.Bottom - height));
    settings.X = x;
    settings.Y = y;
    settings.MonitorDeviceName = screen!.DeviceName;
    var point = new Native.Point { X = x, Y = y };
    if (!Native.ScreenToClient(parent, ref point)) {
      throw new InvalidOperationException(
        "The widget position could not be mapped into Explorer coordinates.");
    }
    return (parent, point);
  }

  private static float ScaleForScreen(Screen screen) {
    var center = new Native.Point {
      X = screen.Bounds.Left + screen.Bounds.Width / 2,
      Y = screen.Bounds.Top + screen.Bounds.Height / 2,
    };
    var monitor = Native.MonitorFromPoint(center, 2);
    if (monitor != 0 && Native.GetDpiForMonitor(
        monitor, 0, out var dpiX, out _) == 0 && dpiX > 0) {
      return dpiX / 96f;
    }
    return 1f;
  }

  private PointF LogicalPoint(nint parameter) {
    var packed = parameter.ToInt64();
    var x = unchecked((short)(packed & 0xFFFF));
    var y = unchecked((short)((packed >> 16) & 0xFFFF));
    return new PointF(x / scale, y / scale);
  }

  private int Pixel(int logical) => (int)Math.Round(logical * scale);

  private RectangleF TaskRowRect(int visibleIndex) =>
    new(23, 89 + visibleIndex * 51, LogicalClientWidth - 46, 46);

  private static RectangleF CheckboxRect(int visibleIndex) =>
    new(33, 103 + visibleIndex * 51, 18, 18);

  private RectangleF RefreshRect => new(LogicalClientWidth - 186, 17, 64, 30);
  private RectangleF OpenRect => new(LogicalClientWidth - 118, 17, 48, 30);
  private RectangleF CloseRect => new(LogicalClientWidth - 66, 17, 50, 30);
  private RectangleF TaskArea => new(16, 82, LogicalClientWidth - 32,
    LogicalClientHeight - 158);
  private RectangleF AddRect => new(16, LogicalClientHeight - 63,
    LogicalClientWidth - 32, 40);
  private int VisibleTaskRows => Math.Max(1,
    (int)Math.Floor((TaskArea.Height - 12) / 51));
  private int LogicalClientWidth => LogicalClientSize.Width;
  private int LogicalClientHeight => LogicalClientSize.Height;
  private Size LogicalClientSize {
    get {
      Native.GetClientRect(Handle, out var bounds);
      return new Size(
        Math.Max(1, (int)Math.Round((bounds.Right - bounds.Left) / scale)),
        Math.Max(1, (int)Math.Round((bounds.Bottom - bounds.Top) / scale)));
    }
  }
  private bool IsResizeGrip(PointF point) =>
    point.X >= LogicalClientWidth - 18 && point.Y >= LogicalClientHeight - 18;

  private static StringFormat CenterFormat() => new() {
    Alignment = StringAlignment.Center,
    LineAlignment = StringAlignment.Center,
  };

  private static void FillRoundedRectangle(
      Graphics graphics, Brush brush, RectangleF bounds, float radius) {
    using var path = new GraphicsPath();
    var diameter = radius * 2;
    path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
    path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
    path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter,
      diameter, diameter, 0, 90);
    path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
    path.CloseFigure();
    graphics.FillPath(brush, path);
  }

  private static Color Blend(Color first, Color second, float amount) =>
    Color.FromArgb(
      (int)(first.R + (second.R - first.R) * amount),
      (int)(first.G + (second.G - first.G) * amount),
      (int)(first.B + (second.B - first.B) * amount));

  public void Dispose() {
    if (disposed) return;
    disposed = true;
    diagnostics.Snapshot(Handle, "native-host-disposing");
    diagnostics.Dispose();
    if (Handle != 0) DestroyHandle();
  }

  private enum HitTarget {
    None,
    Refresh,
    Open,
    Close,
    Add,
    Task,
  }
}
