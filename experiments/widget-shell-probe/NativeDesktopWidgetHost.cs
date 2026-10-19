using System.Diagnostics;
using System.Drawing.Drawing2D;

internal sealed class NativeWidgetApplicationContext : ApplicationContext {
  private readonly LifeManagerWidgetRepository repository;
  private readonly string? appExe;
  private readonly bool diagnostics;
  private readonly WidgetSettingsStore settingsStore = new();
  private readonly WidgetSettings settings;
  private readonly AppearanceSettingsStore appearanceStore = new();
  private readonly AppearanceSettings appearance;
  private readonly PrivacyState privacy = PrivacyState.OpenDefault();
  private readonly WidgetCommandServer commandServer;
  private readonly SynchronizationContext uiContext;
  private readonly NotifyIcon trayIcon;
  private readonly Icon? ownedTrayIcon;
  private readonly FileSystemWatcher databaseWatcher;
  private readonly FileSystemWatcher appearanceWatcher;
  private readonly System.Windows.Forms.Timer refreshDebounce;
  private readonly System.Windows.Forms.Timer appearanceDebounce;
  private readonly System.Windows.Forms.Timer explorerRecovery;
  private readonly System.Windows.Forms.Timer notificationTimer;
  private readonly System.Windows.Forms.Timer privacyTimer;
  private NativeDesktopWidgetHost? host;
  private readonly ExplorerRecoveryPolicy recoveryPolicy = new();

  internal NativeWidgetApplicationContext(
      LifeManagerWidgetRepository repository, string? appExe,
      bool diagnostics, string initialCommand) {
    this.repository = repository;
    this.appExe = appExe;
    this.diagnostics = diagnostics;
    settings = settingsStore.Load();
    appearance = appearanceStore.Load(settings.Theme);
    if (settings.Theme != null) {
      settings.Theme = null;
      settingsStore.Save(settings);
    }
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

    appearanceDebounce = new System.Windows.Forms.Timer { Interval = 150 };
    appearanceDebounce.Tick += (_, _) => {
      appearanceDebounce.Stop();
      var updated = appearanceStore.Load();
      appearance.Theme = updated.Theme;
      appearance.Customization = updated.Customization;
      host?.SetPalette(ResolvePalette(appearance.Theme));
      var opacity = updated.WidgetOpacity ?? updated.Customization?.WidgetOpacity;
      if (opacity is >= 0 and <= 100) host?.SetBackgroundOpacity(opacity.Value);
    };
    appearanceWatcher = new FileSystemWatcher(
      Path.GetDirectoryName(appearanceStore.Path)!,
      Path.GetFileName(appearanceStore.Path)) {
      NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.Size |
        NotifyFilters.FileName,
      EnableRaisingEvents = true,
    };
    appearanceWatcher.Changed += AppearanceChanged;
    appearanceWatcher.Created += AppearanceChanged;
    appearanceWatcher.Renamed += AppearanceChanged;
    Microsoft.Win32.SystemEvents.UserPreferenceChanged += SystemPreferenceChanged;

    explorerRecovery = new System.Windows.Forms.Timer { Interval = 1000 };
    explorerRecovery.Tick += (_, _) => RecoverAfterExplorerRestart();
    notificationTimer = new System.Windows.Forms.Timer { Interval = 30000 };
    notificationTimer.Tick += (_, _) => CheckNotifications();
    privacyTimer = new System.Windows.Forms.Timer { Interval = 1000 };
    privacyTimer.Tick += (_, _) => host?.UpdatePrivacy();
    commandServer = new WidgetCommandServer(ExecuteCommand);
    ownedTrayIcon = LoadTrayIcon();
    trayIcon = BuildTrayIcon();
    trayIcon.Visible = true;
    if (initialCommand != "background") CreateHost();
    ExecuteCommand(initialCommand);
    notificationTimer.Start();
    privacyTimer.Start();
    CheckNotifications();
  }

  private NotifyIcon BuildTrayIcon() {
    var menu = new ContextMenuStrip();
    menu.Items.Add("Open TodoPilot", null, (_, _) => OpenMainApp());
    menu.Items.Add("Show / hide widget", null, (_, _) => ExecuteCommand("toggle"));
    menu.Items.Add("Quick Add", null, (_, _) => ExecuteCommand("quick-add"));
    var view = new ToolStripMenuItem("Task view");
    view.DropDownItems.Add("Today", null, (_, _) => ExecuteCommand("view-today"));
    view.DropDownItems.Add("Inbox", null, (_, _) => ExecuteCommand("view-inbox"));
    view.DropDownItems.Add("All Tasks", null, (_, _) => ExecuteCommand("view-all"));
    view.DropDownItems.Add("Upcoming", null, (_, _) => ExecuteCommand("view-upcoming"));
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
        MessageBox.Show(error.Message, "TodoPilot widget",
          MessageBoxButtons.OK, MessageBoxIcon.Error);
      }
    };
    menu.Items.Add(launch);
    menu.Items.Add("Exit widget", null, (_, _) => ExitThread());
    menu.Items.Add("Exit TodoPilot completely", null, (_, _) => ExitCompletely());
    var icon = new NotifyIcon {
      Icon = ownedTrayIcon ?? SystemIcons.Application,
      Text = "TodoPilot",
      ContextMenuStrip = menu,
    };
    icon.DoubleClick += (_, _) => ExecuteCommand("toggle");
    icon.BalloonTipClicked += (_, _) => OpenMainApp();
    return icon;
  }

  private static Icon? LoadTrayIcon() {
    try {
      return Environment.ProcessPath is { } path
        ? Icon.ExtractAssociatedIcon(path) : null;
    } catch (Exception) {
      return null;
    }
  }

  private void CheckNotifications() {
    try {
      if (privacy.IsLocked() && privacy.SuppressLockedNotifications()) return;
      var now = DateTime.Now;
      var messages = repository.ClaimDailyNotifications(now)
        .Concat(repository.ClaimEventReminders(now)).ToList();
      if (messages.Count == 0) return;
      if (privacy.IsLocked() && privacy.SuppressLockedNotifications()) return;
      var body = privacy.IsLocked()
        ? "Reminders are available. Open TodoPilot to unlock."
        : string.Join("\n", messages);
      trayIcon.ShowBalloonTip(10000, "TodoPilot", body,
        ToolTipIcon.Info);
    } catch (Exception error) {
      Debug.WriteLine($"TodoPilot notification check failed: {error}");
    }
  }

  private void DatabaseChanged(object sender, FileSystemEventArgs args) {
    uiContext.Post(_ => {
      try {
        refreshDebounce.Stop();
        refreshDebounce.Start();
      } catch (InvalidOperationException) { }
    }, null);
  }

  private void AppearanceChanged(object sender, FileSystemEventArgs args) {
    uiContext.Post(_ => {
      try {
        appearanceDebounce.Stop();
        appearanceDebounce.Start();
      } catch (InvalidOperationException) { }
    }, null);
  }

  private void SystemPreferenceChanged(
      object sender, Microsoft.Win32.UserPreferenceChangedEventArgs args) {
    if (appearance.Theme != WidgetThemePreference.System) return;
    uiContext.Post(_ => host?.SetPalette(ResolvePalette(appearance.Theme)), null);
  }

  private void ExecuteCommand(string command) {
    switch (command.ToLowerInvariant()) {
      case "show": EnsureHost(); host?.Show(); break;
      case "hide": host?.Hide(); break;
      case "toggle": EnsureHost(); host?.Toggle(); break;
      case "quick-add": EnsureHost(); host?.OpenQuickAddDialog(); break;
      case "refresh": host?.RefreshFromDatabase(); break;
      case "background": break;
      case "theme-system": SetTheme(WidgetThemePreference.System); break;
      case "theme-light": SetTheme(WidgetThemePreference.Light); break;
      case "theme-dark": SetTheme(WidgetThemePreference.Dark); break;
      case "view-today": SetView(WidgetTaskView.Today); break;
      case "view-inbox": SetView(WidgetTaskView.Inbox); break;
      case "view-all": SetView(WidgetTaskView.All); break;
      case "view-upcoming": SetView(WidgetTaskView.Upcoming); break;
      case "exit": ExitThread(); break;
    }
  }

  private void SetTheme(WidgetThemePreference value) {
    appearance.Theme = value;
    appearanceStore.Save(appearance);
    host?.SetPalette(ResolvePalette(value));
  }

  private void SetView(WidgetTaskView value) {
    settings.View = value;
    settingsStore.Save(settings);
    host?.SetView(value);
  }

  private WidgetPalette ResolvePalette(WidgetThemePreference value) {
    var dark = value == WidgetThemePreference.Dark ||
      value == WidgetThemePreference.System && SystemDarkMode();
    var fallback = dark ? WidgetPalette.Dark : WidgetPalette.Light;
    return appearance.Customization?.Version == 1
      ? WidgetPalette.FromCustom(
          dark ? appearance.Customization.Dark : appearance.Customization.Light,
          fallback)
      : fallback;
  }

  private static bool SystemDarkMode() {
    using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
      @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
    return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
  }

  private void CreateHost() {
    try {
      host = new NativeDesktopWidgetHost(repository, appExe,
        ResolvePalette(appearance.Theme), settings, settingsStore, diagnostics,
        HostDestroyed, ExitThread);
      var opacity = appearance.WidgetOpacity ?? appearance.Customization?.WidgetOpacity;
      if (opacity is >= 0 and <= 100) host.SetBackgroundOpacity(opacity.Value);
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
      MessageBox.Show(error.Message, "TodoPilot widget",
        MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
  }

  private string ResolveMainApp() {
    if (!string.IsNullOrWhiteSpace(appExe) && File.Exists(appExe)) {
      return Path.GetFullPath(appExe);
    }
    var sibling = Path.Combine(AppContext.BaseDirectory, "TodoPilot.exe");
    if (File.Exists(sibling)) return sibling;
    throw new FileNotFoundException("TodoPilot is not beside the widget executable.");
  }

  private void ExitCompletely() {
    if (MessageBox.Show("Close the widget and all running TodoPilot windows?",
        "Exit TodoPilot", MessageBoxButtons.YesNo,
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
      ownedTrayIcon?.Dispose();
      commandServer.Dispose();
      databaseWatcher.Dispose();
      appearanceWatcher.Dispose();
      Microsoft.Win32.SystemEvents.UserPreferenceChanged -= SystemPreferenceChanged;
      refreshDebounce.Dispose();
      appearanceDebounce.Dispose();
      explorerRecovery.Dispose();
      notificationTimer.Dispose();
      privacyTimer.Dispose();
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
  private const int WmRightButtonUp = 0x0205;
  private const int WmMouseWheel = 0x020A;
  private const int WmDisplayChange = 0x007E;
  private const int WmSize = 0x0005;
  private const int WmDpiChanged = 0x02E0;
  private const int WsChild = 0x40000000;
  private const int WsVisible = 0x10000000;
  private const int WsClipChildren = 0x02000000;
  private const int WsClipSiblings = 0x04000000;
  private const int WsExLayered = 0x00080000;
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
  private readonly PrivacyState privacy = PrivacyState.OpenDefault();
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
  private WidgetResizeEdge resizeEdge;
  private InlineQuickAddForm? quickAdd;
  private TaskEditorDialog? taskEditor;
  private ContextMenuStrip? contextMenu;
  private bool wasLocked;
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
    var logicalSize = WidgetGeometry.LogicalSize(settings.Width, settings.Height);
    var parameters = new CreateParams {
      Caption = "TodoPilot Desktop Widget",
      Parent = parent,
      X = position.X,
      Y = position.Y,
      Width = Pixel(logicalSize.Width),
      Height = Pixel(logicalSize.Height),
      Style = WsChild | WsVisible | WsClipChildren | WsClipSiblings,
      ExStyle = WsExLayered,
    };
    CreateHandle(parameters);
    Reposition();
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
      case WmRightButtonUp:
        ShowContextMenu();
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
      case WmDpiChanged:
        Reposition();
        Present("dpi-changed");
        break;
      case WmSize:
        PositionQuickAdd();
        Present("size-changed", updateNow: false);
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
      RenderLayer();
    } finally {
      Native.EndPaint(Handle, ref paint);
    }
  }

  private void RenderLayer() {
    if (Handle == 0 || !Native.GetWindowRect(Handle, out var bounds)) return;
    var size = new Size(bounds.Right - bounds.Left, bounds.Bottom - bounds.Top);
    if (size.Width < 1 || size.Height < 1) return;
    using var bitmap = new Bitmap(size.Width, size.Height,
      System.Drawing.Imaging.PixelFormat.Format32bppPArgb);
    using (var graphics = Graphics.FromImage(bitmap)) {
      graphics.Clear(Color.Transparent);
      graphics.SmoothingMode = SmoothingMode.AntiAlias;
      graphics.TextRenderingHint =
        System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
      graphics.ScaleTransform(scale, scale);
      var alpha = (int)Math.Round(Math.Clamp(settings.BackgroundOpacity, 0, 100) * 255 / 100d);
      using var background = new SolidBrush(Color.FromArgb(Math.Max(1, alpha), palette.Background));
      FillRoundedRectangle(graphics, background,
        new RectangleF(0, 0, LogicalClientWidth, LogicalClientHeight), 12);
      DrawWidget(graphics);
    }
    var screen = Native.GetDC(0);
    var memory = Native.CreateCompatibleDC(screen);
    var image = bitmap.GetHbitmap(Color.FromArgb(0));
    var previous = Native.SelectObject(memory, image);
    try {
      var destination = new Native.Point { X = settings.X, Y = settings.Y };
      // For a layered Explorer child, UpdateLayeredWindow uses parent-client
      // coordinates on this host even though top-level windows use screen space.
      if (!Native.ScreenToClient(Native.GetParent(Handle), ref destination)) return;
      var source = new Native.Point { X = 0, Y = 0 };
      var dimensions = new Native.Size { Width = size.Width, Height = size.Height };
      var blend = new Native.BlendFunction {
        BlendOp = 0, BlendFlags = 0, SourceConstantAlpha = 255, AlphaFormat = 1,
      };
      if (!Native.UpdateLayeredWindow(Handle, screen, ref destination,
          ref dimensions, memory, ref source, 0, ref blend, 2)) {
        Console.Error.WriteLine($"Widget alpha update failed: {System.Runtime.InteropServices.Marshal.GetLastWin32Error()}");
      }
    } finally {
      Native.SelectObject(memory, previous);
      Native.DeleteObject(image);
      Native.DeleteDC(memory);
      Native.ReleaseDC(0, screen);
    }
  }

  private void DrawWidget(Graphics graphics) {
    var logicalWidth = LogicalClientWidth;
    var logicalHeight = LogicalClientHeight;
    using var border = new Pen(palette.Border);
    DrawRoundedRectangle(graphics, border,
      new RectangleF(0.5f, 0.5f, logicalWidth - 1, logicalHeight - 1), 12);
    using var titleFont = new Font("Segoe UI Semibold", 15, FontStyle.Bold);
    using var bodyFont = new Font("Segoe UI", 9.5f);
    using var smallFont = new Font("Segoe UI", 8);
    using var taskFont = new Font("Segoe UI", 9.5f);
    using var foreground = new SolidBrush(palette.Foreground);
    using var muted = new SolidBrush(palette.Muted);

    graphics.DrawString("TodoPilot", titleFont, foreground,
      new RectangleF(16, 12, Math.Max(80, OpenRect.Left - 24), 32));
    if (privacy.IsLocked()) {
      using var format = CenterFormat();
      graphics.DrawString("TodoPilot is locked.\nOpen the main app to unlock.",
        bodyFont, muted, new RectangleF(18, 65,
          logicalWidth - 36, logicalHeight - 155), format);
      using var button = new SolidBrush(palette.Panel);
      FillRoundedRectangle(graphics, button, AddRect, 7);
      graphics.DrawString("Open TodoPilot", bodyFont, foreground,
        AddRect, format);
      return;
    }
    DrawIconButton(graphics, OpenRect, HeaderIcon.Open,
      hoverTarget == HitTarget.Open);
    DrawViewSelector(graphics, bodyFont);

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

    using (var field = new SolidBrush(palette.Panel)) {
      FillRoundedRectangle(graphics, field, AddRect, 7);
    }
    using (var fieldBorder = new Pen(
        hoverTarget == HitTarget.Add ? palette.Accent : palette.Border, 1.5f)) {
      DrawRoundedRectangle(graphics, fieldBorder, AddRect, 7);
    }
    if (hoverTarget == HitTarget.Add) {
      using var hover = new SolidBrush(Color.FromArgb(18, palette.Accent));
      FillRoundedRectangle(graphics, hover, AddRect, 7);
    }
    using var plusFont = new Font("Segoe UI Semibold", 15, FontStyle.Bold);
    using var accentBrush = new SolidBrush(palette.Accent);
    graphics.DrawString("+", plusFont, accentBrush,
      new RectangleF(AddRect.X + 8, AddRect.Y + 4, 24, AddRect.Height - 6));
    graphics.DrawString("Add a task...", bodyFont, muted,
      new RectangleF(AddRect.X + 38, AddRect.Y + 10,
        AddRect.Width - 130, AddRect.Height - 12));
    using var destinationFormat = new StringFormat {
      Alignment = StringAlignment.Far,
      LineAlignment = StringAlignment.Center,
    };
    graphics.DrawString(ViewLabel(settings.View), smallFont, muted,
      new RectangleF(AddRect.Right - 88, AddRect.Y, 76, AddRect.Height),
      destinationFormat);
    using var statusFormat = CenterFormat();
    graphics.DrawString(statusText, smallFont, muted,
      new RectangleF(16, logicalHeight - 21, logicalWidth - 32, 18), statusFormat);
  }

  private void DrawTask(Graphics graphics, WidgetTask task,
      int taskIndex, int visibleIndex, Font font) {
    var row = TaskRowRect(visibleIndex);
    using var rowBrush = new SolidBrush(palette.Row);
    FillRoundedRectangle(graphics, rowBrush, row, 6);
    if ((hoverTarget == HitTarget.TaskRow || hoverTarget == HitTarget.TaskCheckbox) &&
        hoverTask == taskIndex) {
      using var hover = new SolidBrush(Color.FromArgb(
        palette == WidgetPalette.Dark ? 22 : 12, palette.Foreground));
      FillRoundedRectangle(graphics, hover, row, 6);
    }
    var box = CheckboxRect(visibleIndex);
    using var boxPen = new Pen(palette.AccentBorder, 1.5f);
    graphics.DrawRectangle(boxPen, box.X, box.Y, box.Width, box.Height);
    if (hoverTarget == HitTarget.TaskCheckbox && hoverTask == taskIndex) {
      using var checkboxHover = new SolidBrush(Color.FromArgb(42, palette.Accent));
      graphics.FillRectangle(checkboxHover, box);
    }
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

  private void DrawIconButton(Graphics graphics, RectangleF bounds,
      HeaderIcon icon, bool hovered) {
    var color = hovered ? Blend(palette.Row, palette.Accent, 0.24f) : palette.Row;
    using var brush = new SolidBrush(color);
    FillRoundedRectangle(graphics, brush, bounds, 6);
    using var pen = new Pen(palette.Foreground, 1.7f) {
      StartCap = LineCap.Round, EndCap = LineCap.Round,
    };
    var centerX = bounds.X + bounds.Width / 2;
    var centerY = bounds.Y + bounds.Height / 2;
    if (icon == HeaderIcon.Close) {
      graphics.DrawLine(pen, centerX - 5, centerY - 5, centerX + 5, centerY + 5);
      graphics.DrawLine(pen, centerX + 5, centerY - 5, centerX - 5, centerY + 5);
    } else if (icon == HeaderIcon.Open) {
      graphics.DrawRectangle(pen, centerX - 7, centerY - 4, 10, 10);
      graphics.DrawLine(pen, centerX - 1, centerY - 7, centerX + 7, centerY - 7);
      graphics.DrawLine(pen, centerX + 7, centerY - 7, centerX + 7, centerY + 1);
      graphics.DrawLine(pen, centerX, centerY, centerX + 7, centerY - 7);
    } else {
      graphics.DrawArc(pen, centerX - 7, centerY - 7, 14, 14, 35, 285);
      graphics.DrawLine(pen, centerX + 5, centerY - 7, centerX + 8, centerY - 2);
      graphics.DrawLine(pen, centerX + 5, centerY - 7, centerX, centerY - 6);
    }
  }

  private void DrawViewSelector(Graphics graphics, Font font) {
    foreach (var view in Enum.GetValues<WidgetTaskView>()) {
      var bounds = ViewRect(view);
      var selected = settings.View == view;
      using var brush = new SolidBrush(selected ? palette.Accent : palette.Panel);
      FillRoundedRectangle(graphics, brush, bounds, 6);
      using var text = new SolidBrush(selected ? Color.White : palette.Muted);
      using var format = CenterFormat();
      format.Trimming = StringTrimming.EllipsisCharacter;
      format.FormatFlags = StringFormatFlags.NoWrap;
      var label = LogicalClientWidth < 320 && view == WidgetTaskView.Upcoming
        ? "Next" : LogicalClientWidth < 320 && view == WidgetTaskView.All
        ? "All" : ViewLabel(view);
      graphics.DrawString(label, font, text, bounds, format);
    }
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
    Cursor.Current = settings.LayoutLocked ?
      (target == HitTarget.None ? Cursors.Default : Cursors.Hand) :
      CursorFor(GetResizeEdge(point), target);
  }

  private void ShowContextMenu() {
    contextMenu?.Dispose();
    var menu = new ContextMenuStrip();
    contextMenu = menu;
    menu.Items.Add("Open TodoPilot", null, (_, _) => OpenMainApp());
    menu.Items.Add("Refresh", null, (_, _) => RefreshTasks());
    var appearance = new ToolStripMenuItem("Appearance / Widget Settings");
    foreach (var opacity in new[] { 100, 70, 30, 0 }) {
      var choice = new ToolStripMenuItem($"Background opacity: {opacity}%") {
        Checked = settings.BackgroundOpacity == opacity,
      };
      choice.Click += (_, _) => {
        SetBackgroundOpacity(opacity);
        SaveSharedOpacity(opacity);
      };
      appearance.DropDownItems.Add(choice);
    }
    var slider = new TrackBar {
      Minimum = 0, Maximum = 100, TickFrequency = 10,
      Value = Math.Clamp(settings.BackgroundOpacity, 0, 100),
      Width = 180, AutoSize = false, Height = 32,
    };
    slider.Scroll += (_, _) => {
      SetBackgroundOpacity(slider.Value);
      SaveSharedOpacity(slider.Value);
    };
    appearance.DropDownItems.Add(new ToolStripControlHost(slider));
    appearance.DropDownItems.Add(new ToolStripSeparator());
    appearance.DropDownItems.Add("Customize theme in TodoPilot", null,
      (_, _) => OpenMainApp(appearanceSettings: true));
    menu.Items.Add(appearance);
    menu.Items.Add(new ToolStripSeparator());
    var layoutLock = new ToolStripMenuItem(settings.LayoutLocked
      ? "Unlock Layout" : "Lock Layout") { Checked = settings.LayoutLocked };
    layoutLock.Click += (_, _) => {
      settings.LayoutLocked = !settings.LayoutLocked;
      settingsStore.Save(settings);
      Present("layout-lock-changed");
    };
    menu.Items.Add(layoutLock);
    menu.Items.Add("Close Widget", null, (_, _) => { Dispose(); exit(); });
    Native.GetCursorPos(out var point);
    menu.Show(new Point(point.X, point.Y));
  }

  private void BeginMoveOrResize(PointF point) {
    if (settings.LayoutLocked) return;
    resizeEdge = GetResizeEdge(point);
    resizing = resizeEdge != WidgetResizeEdge.None;
    dragging = !resizing && HitTest(point).Target == HitTarget.None && point.Y <= 44;
    if (!dragging && !resizing) return;
    quickAdd?.Close();
    Native.GetCursorPos(out dragStart);
    Native.GetWindowRect(Handle, out dragBounds);
    Native.SetCapture(Handle);
  }

  private void ContinueMoveOrResize() {
    if (!Native.GetCursorPos(out var cursor)) return;
    var dx = cursor.X - dragStart.X;
    var dy = cursor.Y - dragStart.Y;
    var left = dragBounds.Left;
    var top = dragBounds.Top;
    var right = dragBounds.Right;
    var bottom = dragBounds.Bottom;
    if (dragging) {
      left += dx; right += dx; top += dy; bottom += dy;
    } else {
      if (resizeEdge.HasFlag(WidgetResizeEdge.Left)) left += dx;
      if (resizeEdge.HasFlag(WidgetResizeEdge.Right)) right += dx;
      if (resizeEdge.HasFlag(WidgetResizeEdge.Top)) top += dy;
      if (resizeEdge.HasFlag(WidgetResizeEdge.Bottom)) bottom += dy;
      var minWidth = Pixel(260);
      var minHeight = Pixel(230);
      if (right - left < minWidth) {
        if (resizeEdge.HasFlag(WidgetResizeEdge.Left)) left = right - minWidth;
        else right = left + minWidth;
      }
      if (bottom - top < minHeight) {
        if (resizeEdge.HasFlag(WidgetResizeEdge.Top)) top = bottom - minHeight;
        else bottom = top + minHeight;
      }
    }
    var width = right - left;
    var height = bottom - top;
    var screenPoint = new Native.Point {
      X = left,
      Y = top,
    };
    var screen = Screen.FromPoint(new Point(screenPoint.X, screenPoint.Y));
    var clamped = WidgetGeometry.ClampToWorkingArea(
      new Rectangle(screenPoint.X, screenPoint.Y, width, height),
      screen.WorkingArea);
    screenPoint.X = clamped.X;
    screenPoint.Y = clamped.Y;
    width = clamped.Width;
    height = clamped.Height;
    var parentPoint = screenPoint;
    if (!Native.ScreenToClient(Native.GetParent(Handle), ref parentPoint)) return;
    Native.SetWindowPos(Handle, 0, parentPoint.X, parentPoint.Y,
      width, height, SwpNoActivate);
    Present("move-resize", updateNow: false);
  }

  private void EndMoveOrResize() {
    dragging = false;
    resizing = false;
    resizeEdge = WidgetResizeEdge.None;
    Native.ReleaseCapture();
    if (!Native.GetWindowRect(Handle, out var bounds)) return;
    settings.X = bounds.Left;
    settings.Y = bounds.Top;
    settings.Width = Math.Max(260,
      (int)Math.Round((bounds.Right - bounds.Left) / scale));
    settings.Height = Math.Max(230,
      (int)Math.Round((bounds.Bottom - bounds.Top) / scale));
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
    if (privacy.IsLocked()) {
      if (target == HitTarget.Open || target == HitTarget.Add) OpenMainApp();
      else if (target == HitTarget.Close) { Dispose(); exit(); }
      else UpdatePrivacy();
      return;
    }
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
      case HitTarget.ViewToday:
        SetView(WidgetTaskView.Today);
        break;
      case HitTarget.ViewInbox:
        SetView(WidgetTaskView.Inbox);
        break;
      case HitTarget.ViewAll:
        SetView(WidgetTaskView.All);
        break;
      case HitTarget.ViewUpcoming:
        SetView(WidgetTaskView.Upcoming);
        break;
      case HitTarget.TaskCheckbox when taskIndex >= 0 && taskIndex < tasks.Count:
        RunAction(() => repository.CompleteTask(tasks[taskIndex].Id));
        RefreshTasks();
        break;
      case HitTarget.TaskRow when taskIndex >= 0 && taskIndex < tasks.Count:
        OpenTaskEditor(tasks[taskIndex]);
        break;
    }
  }

  private (HitTarget Target, int TaskIndex) HitTest(PointF point) {
    if (OpenRect.Contains(point)) return (HitTarget.Open, -1);
    if (AddRect.Contains(point)) return (HitTarget.Add, -1);
    if (ViewRect(WidgetTaskView.Today).Contains(point)) return (HitTarget.ViewToday, -1);
    if (ViewRect(WidgetTaskView.Inbox).Contains(point)) return (HitTarget.ViewInbox, -1);
    if (ViewRect(WidgetTaskView.All).Contains(point)) return (HitTarget.ViewAll, -1);
    if (ViewRect(WidgetTaskView.Upcoming).Contains(point)) return (HitTarget.ViewUpcoming, -1);
    var end = Math.Min(tasks.Count, scrollOffset + VisibleTaskRows);
    for (var index = scrollOffset; index < end; index++) {
      var visibleIndex = index - scrollOffset;
      if (CheckboxRect(visibleIndex).Contains(point)) {
        return (HitTarget.TaskCheckbox, index);
      }
      if (TaskRowRect(visibleIndex).Contains(point)) {
        return (HitTarget.TaskRow, index);
      }
    }
    return (HitTarget.None, -1);
  }

  private void SetHover(HitTarget target, int task) {
    if (hoverTarget == target && hoverTask == task) return;
    hoverTarget = target;
    hoverTask = task;
    statusText = target switch {
      HitTarget.Refresh => "Refresh tasks",
      HitTarget.Open => "Open TodoPilot",
      HitTarget.Close => "Close widget",
      HitTarget.TaskCheckbox => "Complete task",
      HitTarget.TaskRow => "Edit task",
      _ => $"Updated {DateTime.Now:h:mm tt}",
    };
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

  internal void UpdatePrivacy() {
    var locked = privacy.IsLocked();
    if (locked == wasLocked) return;
    wasLocked = locked;
    if (locked) {
      tasks = [];
      quickAdd?.Close();
      taskEditor?.Close();
      statusText = "Locked";
      Present("privacy-locked");
    } else {
      RefreshTasks();
    }
  }

  internal void SetPalette(WidgetPalette value) {
    palette = value;
    Present("theme-changed");
  }

  internal void SetBackgroundOpacity(int value) {
    settings.BackgroundOpacity = Math.Clamp(value, 0, 100);
    settingsStore.Save(settings);
    Present("opacity-changed");
  }

  private static void SaveSharedOpacity(int value) {
    var store = new AppearanceSettingsStore();
    var appearance = store.Load();
    appearance.WidgetOpacity = value;
    store.Save(appearance);
  }

  internal void SetView(WidgetTaskView value) {
    settings.View = value;
    settingsStore.Save(settings);
    quickAdd?.Close();
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
    if (privacy.IsLocked()) {
      tasks = [];
      wasLocked = true;
      statusText = "Locked";
      Present("privacy-locked");
      return;
    }
    RunAction(() => {
      tasks = repository.LoadTasks(DateTime.Now, settings.View);
      scrollOffset = Math.Min(scrollOffset,
        Math.Max(0, tasks.Count - VisibleTaskRows));
      statusText = $"Updated {DateTime.Now:h:mm tt}";
    });
    Present("tasks-refreshed");
  }

  private void OpenQuickAdd() {
    if (privacy.IsLocked()) { OpenMainApp(); return; }
    if (quickAdd is { IsDisposed: false }) {
      quickAdd.Activate();
      return;
    }
    var saved = false;
    quickAdd = new InlineQuickAddForm(palette, QuickAddScreenBounds(),
      ViewLabel(settings.View), title => {
        repository.AddTask(title, DateTime.Now, settings.View);
        saved = true;
      });
    quickAdd.FormClosed += (_, _) => {
      quickAdd?.Dispose();
      quickAdd = null;
      RefreshTasks();
      if (saved) {
        statusText = $"Added to {ViewLabel(settings.View)}";
        Present("quick-add-saved");
      }
    };
    quickAdd.Show();
  }

  private void OpenTaskEditor(WidgetTask summary) {
    if (privacy.IsLocked()) { OpenMainApp(); return; }
    var current = repository.LoadTask(summary.Id);
    if (current == null) {
      statusText = "Task no longer exists";
      RefreshTasks();
      return;
    }
    using var dialog = new TaskEditorDialog(repository, current, palette);
    taskEditor = dialog;
    Native.GetWindowRect(Handle, out var bounds);
    var working = Screen.FromRectangle(new Rectangle(
      bounds.Left, bounds.Top, bounds.Right - bounds.Left,
      bounds.Bottom - bounds.Top)).WorkingArea;
    dialog.Location = new Point(
      Math.Clamp(bounds.Left + 20, working.Left, working.Right - dialog.Width),
      Math.Clamp(bounds.Top + 40, working.Top, working.Bottom - dialog.Height));
    var result = dialog.ShowDialog();
    taskEditor = null;
    if (dialog.OpenFullDetails) {
      OpenMainApp(current.Id);
      return;
    }
    if (result == DialogResult.OK) {
      statusText = "Task saved";
      RefreshTasks();
    }
  }

  private void OpenMainApp(string? taskId = null, bool appearanceSettings = false) {
    RunAction(() => {
      var path = ResolveMainApp();
      var start = new ProcessStartInfo(path) { UseShellExecute = true };
      if (!string.IsNullOrWhiteSpace(taskId)) {
        start.ArgumentList.Add("--task-id");
        start.ArgumentList.Add(taskId);
      }
      if (appearanceSettings) start.ArgumentList.Add("--appearance");
      Process.Start(start);
      statusText = "Main app opened";
    });
    Present("main-app-opened");
  }

  private string ResolveMainApp() {
    if (!string.IsNullOrWhiteSpace(appExe) && File.Exists(appExe)) {
      return Path.GetFullPath(appExe);
    }
    var sibling = Path.Combine(AppContext.BaseDirectory, "TodoPilot.exe");
    if (File.Exists(sibling)) return sibling;
    throw new FileNotFoundException(
      "Pass --app-exe PATH when the main executable is not beside the widget.");
  }

  private void RunAction(Action action) {
    try {
      action();
    } catch (Exception error) {
      statusText = "Action failed";
      MessageBox.Show(error.Message, "TodoPilot widget",
        MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
  }

  private void Present(string reason, bool updateNow = true) {
    if (Handle == 0) return;
    RenderLayer();
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
    var logicalSize = WidgetGeometry.LogicalSize(settings.Width, settings.Height);
    var width = Pixel(logicalSize.Width);
    var height = Pixel(logicalSize.Height);
    var clamped = WidgetGeometry.ClampToWorkingArea(
      new Rectangle(settings.X, settings.Y, width, height), screen.WorkingArea);
    var x = clamped.X;
    var y = clamped.Y;
    width = clamped.Width;
    height = clamped.Height;
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
    PositionQuickAdd();
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
    var logicalSize = WidgetGeometry.LogicalSize(settings.Width, settings.Height);
    var scaledSize = WidgetGeometry.Scale(logicalSize, scale);
    var width = scaledSize.Width;
    var height = scaledSize.Height;
    var x = settings.X == int.MinValue
      ? working.Value.Right - width - 24 : settings.X;
    var y = settings.Y == int.MinValue ? working.Value.Top + 24 : settings.Y;
    var clamped = WidgetGeometry.ClampToWorkingArea(
      new Rectangle(x, y, width, height), working.Value);
    x = clamped.X;
    y = clamped.Y;
    width = clamped.Width;
    height = clamped.Height;
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

  private RectangleF OpenRect => new(LogicalClientWidth - 46, 14, 30, 30);
  private RectangleF ViewRect(WidgetTaskView view) {
    var index = (int)view;
    var width = (LogicalClientWidth - 50f) / 4f;
    return new RectangleF(16f + index * (width + 6f), 50, width, 26);
  }
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
  private Rectangle QuickAddScreenBounds() {
    Native.GetWindowRect(Handle, out var bounds);
    return new Rectangle(
      bounds.Left + Pixel((int)AddRect.X),
      bounds.Top + Pixel((int)AddRect.Y),
      Pixel((int)AddRect.Width), Pixel((int)AddRect.Height));
  }

  private void PositionQuickAdd() {
    if (quickAdd is not { IsDisposed: false }) return;
    quickAdd.Bounds = QuickAddScreenBounds();
  }

  private WidgetResizeEdge GetResizeEdge(PointF point) =>
    WidgetGeometry.ResizeEdgeAt(
      point.X, point.Y, LogicalClientWidth, LogicalClientHeight);

  private static Cursor CursorFor(WidgetResizeEdge edge, HitTarget target) => edge switch {
    WidgetResizeEdge.Left or WidgetResizeEdge.Right => Cursors.SizeWE,
    WidgetResizeEdge.Top or WidgetResizeEdge.Bottom => Cursors.SizeNS,
    WidgetResizeEdge.Left | WidgetResizeEdge.Top or
      WidgetResizeEdge.Right | WidgetResizeEdge.Bottom =>
      Cursors.SizeNWSE,
    WidgetResizeEdge.Right | WidgetResizeEdge.Top or
      WidgetResizeEdge.Left | WidgetResizeEdge.Bottom =>
      Cursors.SizeNESW,
    _ => target == HitTarget.None ? Cursors.Default : Cursors.Hand,
  };

  private static string ViewLabel(WidgetTaskView view) => view switch {
    WidgetTaskView.Today => "Today",
    WidgetTaskView.Inbox => "Inbox",
    WidgetTaskView.All => "All Tasks",
    WidgetTaskView.Upcoming => "Upcoming",
    _ => view.ToString(),
  };

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

  private static void DrawRoundedRectangle(
      Graphics graphics, Pen pen, RectangleF bounds, float radius) {
    using var path = new GraphicsPath();
    var diameter = radius * 2;
    path.AddArc(bounds.X, bounds.Y, diameter, diameter, 180, 90);
    path.AddArc(bounds.Right - diameter, bounds.Y, diameter, diameter, 270, 90);
    path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter,
      diameter, diameter, 0, 90);
    path.AddArc(bounds.X, bounds.Bottom - diameter, diameter, diameter, 90, 90);
    path.CloseFigure();
    graphics.DrawPath(pen, path);
  }

  private static Color Blend(Color first, Color second, float amount) =>
    Color.FromArgb(
      (int)(first.R + (second.R - first.R) * amount),
      (int)(first.G + (second.G - first.G) * amount),
      (int)(first.B + (second.B - first.B) * amount));

  public void Dispose() {
    if (disposed) return;
    disposed = true;
    quickAdd?.Close();
    quickAdd?.Dispose();
    contextMenu?.Dispose();
    quickAdd = null;
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
    ViewToday,
    ViewInbox,
    ViewAll,
    ViewUpcoming,
    TaskCheckbox,
    TaskRow,
  }

  private enum HeaderIcon { Refresh, Open, Close }

}
