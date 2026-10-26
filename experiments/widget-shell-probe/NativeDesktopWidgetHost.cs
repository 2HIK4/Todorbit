using System.Diagnostics;
using System.Drawing.Drawing2D;

internal sealed partial class NativeWidgetApplicationContext : ApplicationContext {
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

  private NativeDesktopWidgetHost? calendarHost;
  private readonly WidgetSettingsStore calendarSettingsStore = new(Path.Combine(AppDataPaths.ActiveDirectory, "calendar-widget-settings.json"));
  private WidgetSettings calendarSettings = new();
  private DateTime lastLocalDate = DateTime.Today;

  internal NativeWidgetApplicationContext(
      LifeManagerWidgetRepository repository, string? appExe,
      bool diagnostics, string initialCommand) {
    this.repository = repository;
    this.appExe = appExe;
    this.diagnostics = diagnostics;
    settings = settingsStore.Load();
    appearance = appearanceStore.Load(settings.Theme);
    calendarSettings = calendarSettingsStore.Load();
    var calendarConfiguration = WidgetConfiguration.Load(true, calendarSettings);
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
      calendarHost?.RefreshFromDatabase();
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
      calendarHost?.SetPalette(ResolvePalette(appearance.Theme));
      calendarHost?.RefreshFromDatabase();
      var opacity = updated.WidgetOpacity ?? updated.Customization?.WidgetOpacity;
      if (!File.Exists(WidgetConfiguration.PathFor(false)) && opacity is >= 0 and <= 100) host?.SetBackgroundOpacity(opacity.Value);
    };
    appearanceWatcher = new FileSystemWatcher(
      Path.GetDirectoryName(appearanceStore.Path)!,
      "*settings.json") {
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
    privacyTimer.Tick += (_, _) => {
      ExpireWidgetPreviews();
      host?.UpdatePrivacy(); calendarHost?.UpdatePrivacy();
      if (lastLocalDate != DateTime.Today) {
        calendarHost?.AdvanceToday(lastLocalDate);
        lastLocalDate = DateTime.Today;
        host?.RefreshFromDatabase(); calendarHost?.RefreshFromDatabase();
      }
    };
    commandServer = new WidgetCommandServer(ExecuteCommand);
    ownedTrayIcon = LoadTrayIcon();
    trayIcon = BuildTrayIcon();
    trayIcon.Visible = true;
    if (initialCommand != "background" && initialCommand != "reload-configuration" && !initialCommand.StartsWith("calendar-") && (initialCommand != "restore" || WidgetConfiguration.Load(false,settings).Enabled)) CreateHost();
    if (calendarConfiguration.Enabled) CreateCalendarHost();
    ExecuteCommand(initialCommand);
    notificationTimer.Start();
    privacyTimer.Start();
    CheckNotifications();
  }

  private NotifyIcon BuildTrayIcon() {
    var menu = new ContextMenuStrip();
    menu.Items.Add("Open Todorbit", null, (_, _) => OpenMainApp());
    menu.Items.Add("Show / hide widget", null, (_, _) => ExecuteCommand("toggle"));
    menu.Items.Add("Show / hide calendar widget", null, (_, _) => ExecuteCommand("calendar-toggle"));
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
        MessageBox.Show(error.Message, "Todorbit widget",
          MessageBoxButtons.OK, MessageBoxIcon.Error);
      }
    };
    menu.Opening += (_, _) => launch.Checked = StartupRegistration.IsEnabled();
    menu.Items.Add(launch);
    menu.Items.Add("Exit widgets", null, (_, _) => ExitThread());
    menu.Items.Add("Exit Todorbit completely", null, (_, _) => ExitCompletely());
    var icon = new NotifyIcon {
      Icon = ownedTrayIcon ?? SystemIcons.Application,
      Text = "Todorbit",
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
        ? "Reminders are available. Open Todorbit to unlock."
        : string.Join("\n", messages);
      trayIcon.ShowBalloonTip(10000, "Todorbit", body,
        ToolTipIcon.Info);
    } catch (Exception error) {
      Debug.WriteLine($"Todorbit notification check failed: {error}");
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
    uiContext.Post(_ => { host?.SetPalette(ResolvePalette(appearance.Theme)); calendarHost?.SetPalette(ResolvePalette(appearance.Theme)); }, null);
  }

  internal void ExecuteCommand(string command) {
    if (TryHandlePreviewCommand(command)) return;
    if (command == "reload-configuration") {
      var taskConfig = WidgetConfiguration.Load(false, settings);
      host?.ReloadConfiguration();
      if (taskConfig.Enabled) { EnsureHost(); host?.Show(); } else host?.Hide();
      var calendarConfiguration = WidgetConfiguration.Load(true, calendarSettings);
      calendarHost?.ReloadConfiguration();
      if (calendarConfiguration.Enabled) { CreateCalendarHost(); calendarHost?.Show(); } else calendarHost?.Hide();
      return;
    }
    if (command.StartsWith("calendar-")) {
      var action = command[9..];
      if (action is "show" or "toggle") CreateCalendarHost();
      if (action == "show") calendarHost?.Show();
      if (action == "hide") calendarHost?.Hide();
      if (action == "toggle") calendarHost?.Toggle();
      return;
    }
    if (command.StartsWith("opacity-", StringComparison.OrdinalIgnoreCase) &&
        int.TryParse(command.AsSpan(8), out var opacity) &&
        opacity is >= 0 and <= 100) {
      settings.BackgroundOpacity = opacity;
      settingsStore.Save(settings);
      appearance.WidgetOpacity = opacity;
      appearanceStore.Save(appearance);
      if (host != null) host.SetBackgroundOpacity(opacity);
      else WidgetConfiguration.Update(false, settings, c => c.Surface("shell").Opacity = opacity);
      return;
    }
    switch (command.ToLowerInvariant()) {
      case "show": EnsureHost(); host?.Show(); break;
      case "hide": host?.Hide(); break;
      case "toggle": EnsureHost(); host?.Toggle(); break;
      case "quick-add": EnsureHost(); host?.OpenQuickAddDialog(); break;
      case "refresh": host?.RefreshFromDatabase(); break;
      case "restore":
        if (WidgetConfiguration.Load(false,settings).Enabled) { EnsureHost(); host?.Show(); }
        if (WidgetConfiguration.Load(true,calendarSettings).Enabled) { CreateCalendarHost(); calendarHost?.Show(); }
        break;
      case "background": break;
      case "theme-system": SetTheme(WidgetThemePreference.System); break;
      case "theme-light": SetTheme(WidgetThemePreference.Light); break;
      case "theme-dark": SetTheme(WidgetThemePreference.Dark); break;
      case "layout-lock": SetLayoutLocked(true); break;
      case "layout-unlock": SetLayoutLocked(false); break;
      case "startup-on": SetStartup(true); break;
      case "startup-off": SetStartup(false); break;
      case "view-today": SetView(WidgetTaskView.Today); break;
      case "view-inbox": SetView(WidgetTaskView.Inbox); break;
      case "view-all": SetView(WidgetTaskView.All); break;
      case "view-upcoming": SetView(WidgetTaskView.Upcoming); break;
      case "exit": ExitThread(); break;
    }
  }

  private void SetLayoutLocked(bool locked) {
    settings.LayoutLocked = locked;
    settingsStore.Save(settings);
    if (host != null) host.SetLayoutLocked(locked);
    else WidgetConfiguration.Update(false,settings,c=>c.LayoutLocked=locked);
  }

  private void SetStartup(bool enabled) {
    StartupRegistration.SetEnabled(enabled);
    settings.LaunchAtSignIn = enabled;
    settingsStore.Save(settings);
  }

  private void SetTheme(WidgetThemePreference value) {
    appearance.Theme = value;
    appearanceStore.Save(appearance);
    host?.SetPalette(ResolvePalette(value));
    calendarHost?.SetPalette(ResolvePalette(value));
  }

  private void SetView(WidgetTaskView value) {
    settings.View = value;
    settingsStore.Save(settings);
    EnsureHost(); host?.Show(); host?.SetView(value);
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
      host.NeighborBounds = () => calendarHost?.SnapBounds() ?? [];
      var opacity = appearance.WidgetOpacity ?? appearance.Customization?.WidgetOpacity;
      if (!File.Exists(WidgetConfiguration.PathFor(false)) && opacity is >= 0 and <= 100) host.SetBackgroundOpacity(opacity.Value);

    } catch (InvalidOperationException) {
      ScheduleExplorerRecovery();
    }
  }

  private void CreateCalendarHost() {
    if (calendarHost is { Handle: not 0 }) return;
    try {
      calendarHost = new NativeDesktopWidgetHost(repository, appExe,
        ResolvePalette(appearance.Theme), calendarSettings, calendarSettingsStore, diagnostics,
        () => { calendarHost = null; ScheduleExplorerRecovery(); },
        () => { calendarHost = null; }, calendar: true);
      calendarHost.NeighborBounds = () => host?.SnapBounds() ?? [];
    } catch (InvalidOperationException) { ScheduleExplorerRecovery(); }
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
    var tasksEnabled = WidgetConfiguration.Load(false,settings).Enabled;
    var calendarEnabled = WidgetConfiguration.Load(true,calendarSettings).Enabled;
    if (tasksEnabled && (host == null || host.Handle == 0)) CreateHost();
    if (calendarEnabled && (calendarHost == null || calendarHost.Handle == 0)) CreateCalendarHost();
    var recovered = (!tasksEnabled || host is { Handle: not 0 }) &&
      (!calendarEnabled || calendarHost is { Handle: not 0 });
    if (recovered) recoveryPolicy.Reset();
    if (recovered || !recoveryPolicy.CanRetry) explorerRecovery.Stop();
  }

  internal (bool Tasks, bool Calendar) VisibleWidgets =>
    (host != null && Native.IsWindowVisible(host.Handle),
      calendarHost != null && Native.IsWindowVisible(calendarHost.Handle));

  private void OpenMainApp() {
    try {
      Process.Start(new ProcessStartInfo(ResolveMainApp()) { UseShellExecute = false });
    } catch (Exception error) {
      MessageBox.Show(error.Message, "Todorbit widget",
        MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
  }

  private string ResolveMainApp() {
    if (!string.IsNullOrWhiteSpace(appExe) && File.Exists(appExe)) {
      return Path.GetFullPath(appExe);
    }
    var sibling = Path.Combine(AppContext.BaseDirectory, "Todorbit.exe");
    if (File.Exists(sibling)) return sibling;
    throw new FileNotFoundException("Todorbit is not beside the widget executable.");
  }

  private void ExitCompletely() {
    if (MessageBox.Show("Close the widget and all running Todorbit windows?",
        "Exit Todorbit", MessageBoxButtons.YesNo,
        MessageBoxIcon.Question) != DialogResult.Yes) return;
    try {
      var expected = Path.GetFullPath(ResolveMainApp());
      foreach (var process in Process.GetProcessesByName("Todorbit")) {
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
      calendarHost?.Dispose();
      host?.Dispose();
      host = null;
    }
    base.Dispose(disposing);
  }
}

// A single owner-drawn HWND is created as an Explorer child from the beginning.
// Unlike a WinForms Form, NativeWindow does not park or reparent the HWND.
internal sealed partial class NativeDesktopWidgetHost : NativeWindow, IDisposable {
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
  private const int WmCaptureChanged = 0x0215;
  private const int WsChild = 0x40000000;
  private const int WsVisible = 0x10000000;
  private const int WsClipChildren = 0x02000000;
  private const int WsClipSiblings = 0x04000000;
  private const int WsExLayered = 0x00080000;
  private const uint SwpNoActivate = 0x0010;
  private const uint RdwInvalidate = 0x0001;
  private const uint RdwErase = 0x0004;
  private const uint RdwUpdateNow = 0x0100;

  private readonly bool calendar;
  private WidgetConfiguration configuration;
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
  private HitTarget pressedTarget = HitTarget.None;
  private int pressedIndex = -1;
  private int hoverTask = -1;
  private string statusText = "Loading...";
  private bool disposed;
  private bool dragging;
  private bool pointerInside;
  private bool resizing;
  private WidgetResizeEdge resizeEdge;
  private InlineQuickAddForm? quickAdd;
  private TaskEditorDialog? taskEditor;
  private ContextMenuStrip? contextMenu;
  private readonly WidgetTooltip openTooltip = new();
  private bool wasLocked;
  private Native.Point dragStart;
  private Native.Rect dragBounds;

  internal NativeDesktopWidgetHost(
      LifeManagerWidgetRepository repository, string? appExe,
      WidgetPalette palette, WidgetSettings settings,
      WidgetSettingsStore settingsStore, bool diagnosticsEnabled,
      Action unexpectedDestroy, Action exit, bool calendar = false) {
    this.repository = repository;
    this.calendar = calendar;
    configuration = WidgetConfiguration.Load(calendar, settings);
    this.appExe = appExe;
    this.palette = palette;
    openTooltip.Palette = palette;
    this.settings = settings;
    this.settingsStore = settingsStore;
    this.unexpectedDestroy = unexpectedDestroy;
    this.exit = exit;
    diagnostics = new WidgetRenderDiagnostics(diagnosticsEnabled);
    var (parent, position) = ResolveDesktopIconHost(settings, calendar, configuration.TextScale);
    var screen = Screen.AllScreens.FirstOrDefault(item =>
      item.DeviceName == settings.MonitorDeviceName) ?? Screen.PrimaryScreen!;
    scale = ScaleForScreen(screen);
    var logicalSize = WidgetGeometry.LogicalSize(Math.Max(MinimumSize.Width,settings.Width),Math.Max(MinimumSize.Height,settings.Height));
    var parameters = new CreateParams {
      Caption = calendar ? "Todorbit Calendar Widget" : "Todorbit Tasks Widget",
      Parent = parent,
      X = position.X,
      Y = position.Y,
      Width = WidgetGeometry.RestoreSize(settings, logicalSize, scale).Width,
      Height = WidgetGeometry.RestoreSize(settings, logicalSize, scale).Height,
      Style = WsChild | (configuration.Enabled ? WsVisible : 0) | WsClipChildren | WsClipSiblings | 0x00010000,
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
      case 0x003D when message.LParam.ToInt64() == -4:
        accessibleRoot ??= new WidgetAccessibleRoot(this);
        var accessibleId = new Guid("618736E0-3C3D-11CF-810C-00AA00389B71");
        message.Result = LresultFromObject(ref accessibleId,message.WParam,accessibleRoot);
        return;
      case 0x0100:
        if(KeyboardCommand((Keys)message.WParam.ToInt32())) { message.Result=0;return; }
        break;
      case 0x007B:
        ShowContextMenu();message.Result=0;return;
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
        pointerInside = false;
        if (!dragging && !resizing) { pressedTarget = HitTarget.None; pressedIndex = -1; }
        SetHover(HitTarget.None, -1);
        Present("pointer-left", updateNow: false);
        message.Result = 0;
        return;
      case WmLeftButtonUp:
        var released = HitTest(LogicalPoint(message.LParam));
        var activate = released.Target == pressedTarget && released.TaskIndex == pressedIndex;
        pressedTarget = HitTarget.None;
        if (dragging || resizing) EndMoveOrResize();
        else if (activate) Click(LogicalPoint(message.LParam));
        message.Result = 0;
        return;
      case WmCaptureChanged:
        if (dragging || resizing) EndMoveOrResize();
        break;
      case WmMouseWheel:
        var delta = unchecked((short)((message.WParam.ToInt64() >> 16) & 0xFFFF));
        var wheelPoint = new Native.Point { X = unchecked((short)(message.LParam.ToInt64() & 0xFFFF)), Y = unchecked((short)((message.LParam.ToInt64() >> 16) & 0xFFFF)) };
        Native.ScreenToClient(Handle, ref wheelPoint);
        ScrollAt(new PointF(wheelPoint.X / scale, wheelPoint.Y / scale), delta > 0 ? -1 : 1);
        message.Result = 0;
        return;
      case WmDisplayChange:
        if (!dragging && !resizing) Reposition();
        Present("display-change");
        break;
      case WmDpiChanged:
        if (!dragging && !resizing) Reposition();
        Present("dpi-changed");
        break;
      case WmSize:
        PositionQuickAdd();
        if (!dragging && !resizing) Present("size-changed", updateNow: false);
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
      PaintSurface(graphics, "shell", new RectangleF(0.5f, 0.5f, LogicalClientWidth - 1, LogicalClientHeight - 1), palette.Background);
      DrawWidget(graphics);
      DrawDragAffordance(graphics);
      DrawKeyboardFocus(graphics);
    }
    var screen = Native.GetDC(0);
    var memory = Native.CreateCompatibleDC(screen);
    var image = bitmap.GetHbitmap(Color.FromArgb(0));
    var previous = Native.SelectObject(memory, image);
    try {
      // SetWindowPos owns live geometry while dragging. Settings are only the
      // last committed position; using them here moves the layered child back
      // on every paint/WM_SIZE until mouse-up.
      var destination = new Native.Point { X = bounds.Left, Y = bounds.Top };
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
    using var titleFont = new Font("Segoe UI Semibold", 20 * configuration.TextScale, FontStyle.Regular, GraphicsUnit.Pixel);
    using var bodyFont = new Font("Segoe UI", 13 * configuration.TextScale, FontStyle.Regular, GraphicsUnit.Pixel);
    using var smallFont = new Font("Segoe UI", 11 * configuration.TextScale, FontStyle.Regular, GraphicsUnit.Pixel);
    using var taskFont = new Font("Segoe UI", 13 * configuration.TextScale, FontStyle.Regular, GraphicsUnit.Pixel);
    using var foreground = new SolidBrush(SurfaceText("header"));
    using var muted = new SolidBrush(SurfaceText("content",true));

    if (configuration.HasHeader) PaintSurface(graphics, "header", new RectangleF(16, 8, logicalWidth - 32, ContentTop-14), palette.Background);
    if (configuration.ShowTitle) DrawText(graphics,calendar ? "Calendar" : "Todorbit", titleFont, foreground,
      new RectangleF(16, 16, Math.Max(80, logicalWidth - (configuration.ShowOpenButton ? 78 : 32)), Math.Max(28,20*configuration.TextScale+4)),surface:"header");
    if (configuration.ShowOpenButton) DrawIconButton(graphics, OpenRect, HeaderIcon.Open, hoverTarget == HitTarget.Open);
    if (privacy.IsLocked()) {
      using var format = CenterFormat();
      DrawText(graphics,"Todorbit is locked.\nOpen the main app to unlock.",
        bodyFont, muted, new RectangleF(18, 65,
          logicalWidth - 36, logicalHeight - 155), format);
      using var button = new SolidBrush(palette.Panel);
      FillRoundedRectangle(graphics, button, AddRect, 7);
      DrawText(graphics,"Open Todorbit", bodyFont, foreground,
        AddRect, format);
      return;
    }
    if (calendar) { DrawCalendar(graphics, bodyFont, smallFont); return; }
    DrawViewSelector(graphics, bodyFont);

    PaintSurface(graphics, "content", TaskArea, palette.Panel);
    if (tasks.Count == 0) {
      using var emptyFormat = CenterFormat();
      var emptyText = settings.View switch {
        WidgetTaskView.Today => "Nothing planned for today.",
        WidgetTaskView.Inbox => "Your Inbox is clear.",
        WidgetTaskView.All => "No tasks yet. Add one below.",
        WidgetTaskView.Upcoming => "Nothing coming up.",
        _ => "No tasks to show.",
      };
      var emptyBounds = TaskArea;
      if (TaskArea.Height >= 100) {
        var centerX = TaskArea.X + TaskArea.Width / 2;
        var centerY = TaskArea.Y + TaskArea.Height / 2 - 20;
        using var pen = new Pen(Color.FromArgb(170, SurfaceText("content", true)), 1.5f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        graphics.DrawEllipse(pen, centerX - 12, centerY - 12, 24, 24);
        graphics.DrawLines(pen, new PointF[] { new(centerX - 5, centerY), new(centerX - 1, centerY + 4), new(centerX + 6, centerY - 4) });
        emptyBounds = new RectangleF(TaskArea.X + 12, centerY + 18, TaskArea.Width - 24, 42);
      }
      DrawText(graphics,emptyText,
        bodyFont, muted, emptyBounds, emptyFormat);
    } else {
      var end = Math.Min(tasks.Count, scrollOffset + VisibleTaskRows);
      for (var index = scrollOffset; index < end; index++) {
        DrawTask(graphics, tasks[index], index,
          index - scrollOffset, taskFont);
      }
      if (tasks.Count > VisibleTaskRows) DrawScrollIndicator(graphics);
    }

    PaintSurface(graphics, "input", AddRect, palette.Panel);
    if (hoverTarget == HitTarget.Add) {
      using var hover = new SolidBrush(Color.FromArgb(18, palette.Accent));
      FillRoundedRectangle(graphics, hover, AddRect, 7);
    }
    using var plusFont = new Font("Segoe UI", 20, FontStyle.Regular, GraphicsUnit.Pixel);
    using var accentBrush = new SolidBrush(palette.Accent);
    DrawText(graphics,"+", plusFont, accentBrush,
      new RectangleF(AddRect.X + 8, AddRect.Y + 4, 24, AddRect.Height - 6),surface:"input");
    using var placeholder = new SolidBrush(SurfaceText("input",true));
    DrawText(graphics,"Add a task...", bodyFont, placeholder,
      new RectangleF(AddRect.X + 38, AddRect.Y + 10,
        AddRect.Width - 130, AddRect.Height - 12),surface:"input");
    using var destinationFormat = new StringFormat {
      Alignment = StringAlignment.Far,
      LineAlignment = StringAlignment.Center,
    };
    DrawText(graphics,ViewLabel(settings.View), smallFont, placeholder,
      new RectangleF(AddRect.Right - 88, AddRect.Y, 76, AddRect.Height),
      destinationFormat,"input");
  }

  private void DrawTask(Graphics graphics, WidgetTask task,
      int taskIndex, int visibleIndex, Font font) {
    var row = TaskRowRect(visibleIndex);
    using var rowBrush = new SolidBrush(palette.Row);
    FillRoundedRectangle(graphics, rowBrush, row, 6);
    if ((hoverTarget == HitTarget.TaskRow || hoverTarget == HitTarget.TaskCheckbox) &&
        hoverTask == taskIndex) {
      using var hover = new SolidBrush(Color.FromArgb(
        WidgetEditorStyle.IsDark(palette) ? 22 : 12, palette.Foreground));
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
    DrawText(graphics,task.Title, font, textBrush,
      new RectangleF(row.X + 38, row.Y + 3, row.Width - 48, row.Height - 6),
      format,"opaque");
  }

  private void DrawScrollIndicator(Graphics graphics) {
    var track = new RectangleF(TaskArea.Right - 6, TaskArea.Top + 8,
      3, Math.Max(20, TaskArea.Height - 16));
    using var background = new SolidBrush(palette.Border);
    FillRoundedRectangle(graphics, background, track, 2);
    var thumbHeight = Math.Max(14,
      track.Height * VisibleTaskRows / tasks.Count);
    var maxOffset = Math.Max(1, tasks.Count - VisibleTaskRows);
    var top = track.Top + (track.Height - thumbHeight) * scrollOffset / maxOffset;
    using var thumb = new SolidBrush(palette.Accent);
    FillRoundedRectangle(graphics, thumb,
      new RectangleF(track.X, top, track.Width, thumbHeight), 2);
  }

  private void DrawIconButton(Graphics graphics, RectangleF bounds,
      HeaderIcon icon, bool hovered) {
    var color = pressedTarget == HitTarget.Open ? Blend(palette.Row,palette.Accent,0.4f) : hovered ? Blend(palette.Row, palette.Accent, 0.24f) : palette.Panel;
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
      graphics.DrawLines(pen, new PointF[] {new(centerX - 1, centerY - 7), new(centerX - 7, centerY - 7), new(centerX - 7, centerY + 7), new(centerX + 7, centerY + 7), new(centerX + 7, centerY + 1)});
      graphics.DrawLine(pen, centerX, centerY, centerX + 7, centerY - 7);
      graphics.DrawLines(pen, new PointF[] {new(centerX + 1, centerY - 7), new(centerX + 7, centerY - 7), new(centerX + 7, centerY - 1)});
    } else {
      graphics.DrawArc(pen, centerX - 7, centerY - 7, 14, 14, 35, 285);
      graphics.DrawLine(pen, centerX + 5, centerY - 7, centerX + 8, centerY - 2);
      graphics.DrawLine(pen, centerX + 5, centerY - 7, centerX, centerY - 6);
    }
  }

  private void DrawViewSelector(Graphics graphics, Font font) {
    if (VisibleViews.Length == 0) return;
    PaintSurface(graphics, "navigation", NavigationRect, palette.Background);
    foreach (var view in VisibleViews) {
      var bounds = ViewRect(view);
      var selected = settings.View == view;
      PaintSurface(graphics, "navigationButton", bounds, palette.Panel);
      if (selected || hoverTarget == ViewTarget(view)) {
        using var brush = new SolidBrush(selected ? palette.Accent : Blend(palette.Panel,palette.Accent,0.24f));
        FillRoundedRectangle(graphics, brush, bounds, configuration.Surface("navigationButton").Radius);
      }
      using var text = new SolidBrush(selected ? WidgetEditorStyle.OnAccent(palette) : SurfaceText("navigationButton"));
      using var format = CenterFormat();
      format.Trimming = StringTrimming.EllipsisCharacter;
      format.FormatFlags = StringFormatFlags.NoWrap;
      var icon = EffectiveNavigationDisplay != "text";
      if (icon) DrawViewIcon(graphics, view, new RectangleF(bounds.X + (EffectiveNavigationDisplay == "icons" ? (bounds.Width - 16)/2 : 6),bounds.Y + (bounds.Height-16)/2,16,16), text.Color);
      if (EffectiveNavigationDisplay != "icons") {
        if (icon) { bounds.X += 26; bounds.Width -= 26; }
        DrawText(graphics,ViewLabel(view), font, text, bounds, format,surface:selected?"opaque":"navigationButton");
      }
    }
  }

  private void DrawDragAffordance(Graphics graphics) {
    if (!pointerInside || configuration.LayoutLocked) return;
    using var grip = new SolidBrush(Color.FromArgb(120, palette.Muted));
    for (var dot = 0; dot < 6; dot++)
      graphics.FillEllipse(grip, LogicalClientWidth / 2f - 10 + dot % 3 * 8, 5 + dot / 3 * 4, 2, 2);
  }

  private void MouseMove(PointF point) {
    if (dragging || resizing) {
      ContinueMoveOrResize();
      return;
    }
    if (!pointerInside) { pointerInside = true; Present("pointer-entered", updateNow: false); }
    var tracking = new Native.TrackMouseEventData {
      Size = (uint)System.Runtime.InteropServices.Marshal.SizeOf<Native.TrackMouseEventData>(),
      Flags = 0x00000002,
      Window = Handle,
    };
    Native.TrackMouseEvent(ref tracking);
    var (target, task) = HitTest(point);
    SetHover(target, task);
    Cursor.Current = configuration.LayoutLocked ?
      (target == HitTarget.None ? Cursors.Default : Cursors.Hand) :
      CursorFor(GetResizeEdge(point), target);
  }

  private void ShowContextMenu() {
    openTooltip.Hide(this);
    contextMenu?.Dispose();
    contextMenu = CreateContextMenu();
    Native.GetCursorPos(out var point);
    contextMenu.Show(new Point(point.X, point.Y));
  }

  private ContextMenuStrip CreateContextMenu() {
    var menu = new ContextMenuStrip();
    var committed = WidgetConfiguration.Load(calendar, settings);
    menu.Items.Add("Open Todorbit", null, (_, _) => OpenMainApp());
    menu.Items.Add("Edit This Widget", null, (_, _) => OpenWidgetSettings());
    menu.Items.Add("Refresh", null, (_, _) => RefreshTasks());
    menu.Items.Add(new ToolStripSeparator());
    foreach (var element in new[] { "Title", "Open App Button" }) {
      var show = new ToolStripMenuItem("Show " + element) { Checked = element == "Title" ? committed.ShowTitle : committed.ShowOpenButton };
      show.Click += (_, _) => RunAction(() => {
        // Never save the renderer's transient preview as a side effect of a
        // context-menu toggle. Merge only this setting into the saved file.
        var saved = WidgetConfiguration.Load(calendar, settings);
        if (element == "Title") saved.ShowTitle = !saved.ShowTitle;
        else saved.ShowOpenButton = !saved.ShowOpenButton;
        saved.Save(calendar); ReloadConfiguration();
      });
      menu.Items.Add(show);
    }
    if (!calendar) {
      var views = new ToolStripMenuItem("Task view");
      foreach (var view in Enum.GetValues<WidgetTaskView>()) {
        var item = new ToolStripMenuItem(ViewLabel(view)) { Checked = settings.View == view };
        item.Click += (_, _) => SetView(view); views.DropDownItems.Add(item);
      }
      menu.Items.Add(views);
    }
    menu.Items.Add("Move widget to center", null, (_, _) => { var area = Screen.FromHandle(Handle).WorkingArea; settings.X = area.Left + area.Width/2 - Pixel(settings.Width)/2; settings.Y = area.Top + area.Height/2 - Pixel(settings.Height)/2; Reposition(); Present("center"); }).Enabled = !configuration.LayoutLocked;
    var appearance = new ToolStripMenuItem("Appearance / Widget Settings");
    foreach (var opacity in new[] { 100, 70, 30, 0 }) {
      var choice = new ToolStripMenuItem($"Background opacity: {opacity}%") {
        Checked = committed.Surface("shell").Opacity == opacity,
      };
      choice.Click += (_, _) => {
        RunAction(() => SetBackgroundOpacity(opacity));

      };
      appearance.DropDownItems.Add(choice);
    }
    appearance.DropDownItems.Add(new ToolStripSeparator());
    appearance.DropDownItems.Add("Customize theme in Todorbit", null,
      (_, _) => OpenMainApp(appearanceSettings: true));
    menu.Items.Add(appearance);
    menu.Items.Add(new ToolStripSeparator());
    var layoutLock = new ToolStripMenuItem("Lock Layout") { Checked = committed.LayoutLocked };
    layoutLock.Click += (_, _) => RunAction(() => SetLayoutLocked(!WidgetConfiguration.Load(calendar, settings).LayoutLocked));
    menu.Items.Add(layoutLock);
    menu.Items.Add(new ToolStripSeparator());
    menu.Items.Add("Close Widget", null, (_, _) => RunAction(Hide));
    WidgetMenuStyle.Apply(menu, palette);
    return menu;
  }

  private void BeginMoveOrResize(PointF point) {
    edgeSnap = new WidgetEdgeSnap();
    openTooltip.Hide(this);
    (pressedTarget, pressedIndex) = HitTest(point);
    Present("pressed");
    if (configuration.LayoutLocked) { Native.SetFocus(Handle); return; }
    resizeEdge = GetResizeEdge(point);
    resizing = resizeEdge != WidgetResizeEdge.None;
    dragging = !resizing && pressedTarget == HitTarget.None;
    if (!dragging && !resizing) { Native.SetFocus(Handle); return; }
    quickAdd?.Close();
    Native.GetCursorPos(out dragStart);
    Native.GetWindowRect(Handle, out dragBounds);
    Native.SetCapture(Handle);
  }

  private WidgetEdgeSnap edgeSnap = new();
  internal Func<IEnumerable<Rectangle>> NeighborBounds = () => [];
  internal IEnumerable<Rectangle> SnapBounds() {
    if (Handle != 0 && Native.IsWindowVisible(Handle) && Native.GetWindowRect(Handle, out var r))
      yield return Rectangle.FromLTRB(r.Left, r.Top, r.Right, r.Bottom);
  }

  private void ContinueMoveOrResize() {
    if (!Native.GetCursorPos(out var cursor)) return;
    var dx = cursor.X - dragStart.X;
    var dy = cursor.Y - dragStart.Y;
    var proposed = WidgetGeometry.MoveOrResize(
      Rectangle.FromLTRB(dragBounds.Left, dragBounds.Top,
        dragBounds.Right, dragBounds.Bottom),
      dx, dy, dragging, resizeEdge, Pixel(MinimumSize.Width), Pixel(MinimumSize.Height));
    proposed = edgeSnap.Apply(proposed, dragging, resizeEdge,
      new Size(Pixel(MinimumSize.Width), Pixel(MinimumSize.Height)), NeighborBounds());
    var width = proposed.Width;
    var height = proposed.Height;
    var screenPoint = new Native.Point {
      X = proposed.Left,
      Y = proposed.Top,
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
    var screen = Screen.FromRectangle(new Rectangle(
      bounds.Left, bounds.Top, bounds.Right - bounds.Left,
      bounds.Bottom - bounds.Top));
    settings.MonitorDeviceName = screen.DeviceName;
    scale = ScaleForScreen(screen);
    settings.Width = Math.Max(260,
      (int)Math.Round((bounds.Right - bounds.Left) / scale));
    settings.Height = Math.Max(230,
      (int)Math.Round((bounds.Bottom - bounds.Top) / scale));
    settings.PhysicalWidth = bounds.Right - bounds.Left;
    settings.PhysicalHeight = bounds.Bottom - bounds.Top;
    settings.BoundsDpi = (int)Math.Round(scale * 96);
    settingsStore.Save(settings);
    Reposition();
  }

  private void Click(PointF point) {
    var (target, taskIndex) = HitTest(point);
    if (calendar && !privacy.IsLocked() && CalendarClick(point)) return;
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
    if (configuration.ShowOpenButton && OpenRect.Contains(point)) return (HitTarget.Open, -1);
    if (privacy.IsLocked()) return AddRect.Contains(point) ? (HitTarget.Add,-1) : (HitTarget.None,-1);
    if (calendar) return CalendarHitTest(point);
    if (AddRect.Contains(point)) return (HitTarget.Add, -1);
    if (ViewRect(WidgetTaskView.Today).Contains(point)) return (HitTarget.ViewToday, -1);
    if (ViewRect(WidgetTaskView.Inbox).Contains(point)) return (HitTarget.ViewInbox, -1);
    if (ViewRect(WidgetTaskView.All).Contains(point)) return (HitTarget.ViewAll, -1);
    if (ViewRect(WidgetTaskView.Upcoming).Contains(point)) return (HitTarget.ViewUpcoming, -1);
    var end = Math.Min(tasks.Count, scrollOffset + VisibleTaskRows);
    for (var index = scrollOffset; index < end; index++) {
      var visibleIndex = index - scrollOffset;
      if (CheckboxHitRect(visibleIndex).Contains(point)) {
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
    openTooltip.Hide(this);
    hoverTarget = target;
    hoverTask = task;
    if (target == HitTarget.Open) {
      openTooltip.Show("Open Todorbit", this,
        new Point(Pixel((int)OpenRect.X), Pixel((int)OpenRect.Bottom + 8)), 3000);
    }
    if (calendar && !privacy.IsLocked()) ShowCalendarTooltip(target,task);
    if (!calendar && !privacy.IsLocked() && target == HitTarget.TaskRow && task >= 0 && task < tasks.Count) {
      var row = TaskRowRect(task - scrollOffset);
      openTooltip.Show(tasks[task].Title, this, new Point(Pixel((int)row.X), Pixel((int)row.Bottom + 4)), 3000);
    }
    foreach(var view in VisibleViews) if(target==ViewTarget(view)) {
      var r=ViewRect(view); openTooltip.Show(ViewLabel(view),this,new Point(Pixel((int)r.X),Pixel((int)r.Bottom+4)),3000);
    }
    statusText = target switch {
      HitTarget.Refresh => "Refresh tasks",
      HitTarget.Open => "Open Todorbit",
      HitTarget.Close => "Close widget",
      HitTarget.TaskCheckbox => "Complete task",
      HitTarget.TaskRow => "Edit task",
      _ => $"Updated {DateTime.Now:h:mm tt}",
    };
    Present("hover-changed", updateNow: false);
  }

  private void Scroll(int direction) {
    if (calendar) { agendaOffset = Math.Clamp(agendaOffset+direction, 0, Math.Max(0, SelectedAgenda.Length-AgendaVisibleRows)); Present("agenda-scroll"); return; }
    if (tasks.Count <= VisibleTaskRows) return;
    var maximum = Math.Max(0, tasks.Count - VisibleTaskRows);
    var next = Math.Clamp(scrollOffset + direction, 0, maximum);
    if (next == scrollOffset) return;
    scrollOffset = next;
    Present("task-scroll", updateNow: false);
  }

  private void ScrollAt(PointF point, int direction) {
    if (!calendar || AgendaRect.Contains(point)) Scroll(direction);
  }

  internal void RefreshFromDatabase() => RefreshTasks();

  internal void UpdatePrivacy() {
    var locked = privacy.IsLocked();
    if (locked == wasLocked) return;
    wasLocked = locked;
    if (locked) {
      tasks = [];
      calendarItems = [];
      openTooltip.Hide(this);
      quickAdd?.Close();
      taskEditor?.Close();
      calendarDetail?.Close();
      statusText = "Locked";
      Present("privacy-locked");
    } else {
      RefreshTasks();
    }
  }

  internal void SetPalette(WidgetPalette value) {
    palette = value;
    openTooltip.Palette = value;
    openTooltip.Hide(this);
    Present("theme-changed");
  }

  internal void SetBackgroundOpacity(int value) {
    configuration = WidgetConfiguration.Load(calendar,settings);
    settings.BackgroundOpacity = Math.Clamp(value, 0, 100);
    configuration.Surface("shell").Opacity = settings.BackgroundOpacity;
    configuration.Save(calendar);
    settingsStore.Save(settings);
    RestorePreviewIfActive();
    Present("opacity-changed");
  }

  internal void SetLayoutLocked(bool locked) {
    configuration = WidgetConfiguration.Load(calendar,settings);
    settings.LayoutLocked = locked;
    configuration.LayoutLocked = locked;
    configuration.Save(calendar);
    settingsStore.Save(settings);
    RestorePreviewIfActive();
    Present("layout-lock-changed");
  }

  internal void SetView(WidgetTaskView value) {
    settings.View = value;
    settingsStore.Save(settings);
    quickAdd?.Close();
    RefreshTasks();
  }

  internal void Show() {
    configuration = WidgetConfiguration.Load(calendar,settings);
    if(!configuration.Enabled) { configuration.Enabled = true; configuration.Save(calendar); }
    RestorePreviewIfActive();
    if (Handle != 0) Native.ShowWindow(Handle, 5);
  }

  internal void Hide() {
    openTooltip.Hide(this);
    configuration = WidgetConfiguration.Load(calendar,settings);
    if(configuration.Enabled) { configuration.Enabled = false; configuration.Save(calendar); }
    RestorePreviewIfActive();
    if (Handle != 0) Native.ShowWindow(Handle, 0);
  }

  internal void Toggle() {
    if (Handle != 0) { if (Native.IsWindowVisible(Handle)) Hide(); else Show(); }
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
      if (calendar) LoadCalendar();
      else tasks = repository.LoadTasks(DateTime.Now, settings.View);
      scrollOffset = Math.Min(scrollOffset,
        Math.Max(0, tasks.Count - VisibleTaskRows));
      statusText = $"Updated {DateTime.Now:h:mm tt}";
    });
    Present("tasks-refreshed");
  }

  private void OpenQuickAdd() {
    if (calendar) return;
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
      }, configuration.Surface("input"), configuration.TextScale);
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
    dialog.Size = new Size(
      Math.Min(dialog.Width, Math.Max(dialog.MinimumSize.Width, working.Width - 24)),
      Math.Min(dialog.Height, Math.Max(dialog.MinimumSize.Height, working.Height - 24)));
    dialog.Location = new Point(
      Math.Clamp(bounds.Left + 20, working.Left,
        Math.Max(working.Left, working.Right - dialog.Width)),
      Math.Clamp(bounds.Top + 40, working.Top,
        Math.Max(working.Top, working.Bottom - dialog.Height)));
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
      var start = new ProcessStartInfo(path) { UseShellExecute = false };
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
    var sibling = Path.Combine(AppContext.BaseDirectory, "Todorbit.exe");
    if (File.Exists(sibling)) return sibling;
    throw new FileNotFoundException(
      "Pass --app-exe PATH when the main executable is not beside the widget.");
  }

  private void RunAction(Action action) {
    try {
      action();
    } catch (Exception error) {
      statusText = "Action failed";
      MessageBox.Show(error.Message, "Todorbit widget",
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
    var logicalSize = WidgetGeometry.LogicalSize(Math.Max(MinimumSize.Width,settings.Width),Math.Max(MinimumSize.Height,settings.Height));
    var restored = WidgetGeometry.RestoreSize(settings, logicalSize, scale);
    var width = restored.Width;
    var height = restored.Height;
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

  // Preview may increase the readable minimum, but must not write geometry or
  // snap a widget back to its last saved position during a live resize.
  internal void EnsurePreviewMinimumSize() {
    if (Handle == 0 || !Native.GetWindowRect(Handle, out var current)) return;
    var width = Math.Max(current.Right - current.Left, Pixel(MinimumSize.Width));
    var height = Math.Max(current.Bottom - current.Top, Pixel(MinimumSize.Height));
    var screen = Screen.FromHandle(Handle);
    var desired = WidgetGeometry.ClampToWorkingArea(new Rectangle(current.Left, current.Top, width, height), screen.WorkingArea);
    if (desired == Rectangle.FromLTRB(current.Left, current.Top, current.Right, current.Bottom)) return;
    var position = new Native.Point { X = desired.Left, Y = desired.Top };
    if (!Native.ScreenToClient(Native.GetParent(Handle), ref position)) return;
    Native.SetWindowPos(Handle, 0, position.X, position.Y, desired.Width, desired.Height, SwpNoActivate);
    PositionQuickAdd();
  }

  private static (nint Parent, Native.Point Position) ResolveDesktopIconHost(
      WidgetSettings settings, bool calendar = false, float textScale = 1) {
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
    var minimumSize = WidgetGeometry.MinimumSize(calendar,textScale);
    var logicalSize = WidgetGeometry.LogicalSize(Math.Max(minimumSize.Width,settings.Width),Math.Max(minimumSize.Height,settings.Height));
    var scaledSize = WidgetGeometry.RestoreSize(settings, logicalSize, scale);
    var width = scaledSize.Width;
    var height = scaledSize.Height;
    var defaultX = working.Value.Right - width - 24;
    var defaultY = working.Value.Top + 24;
    if(calendar) {
      if(working.Value.Width >= width*2+64) defaultX -= width+16;
      else if(working.Value.Height >= height*2+64) defaultY += height+16;
      else defaultX = working.Value.Left+24;
    }
    var x = settings.X == int.MinValue ? defaultX : settings.X;
    var y = settings.Y == int.MinValue ? defaultY : settings.Y;
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
  internal float TooltipScale => scale;

  private RectangleF TaskRowRect(int visibleIndex) =>
    new(TaskArea.X + 7, TaskArea.Y + 7 + visibleIndex * TaskRowHeight, TaskArea.Width - 14, TaskRowHeight - 5);

  private RectangleF CheckboxRect(int visibleIndex) =>
    new(TaskArea.X + 17, TaskArea.Y + 7 + (TaskRowHeight-5-18)/2 + visibleIndex * TaskRowHeight, 18, 18);

  private RectangleF CheckboxHitRect(int visibleIndex) {
    var row = TaskRowRect(visibleIndex);
    return new RectangleF(row.X, row.Y, 36, row.Height);
  }

  private RectangleF OpenRect => new(LogicalClientWidth - 46, 14, 30, 30);
  private Size MinimumSize => WidgetGeometry.MinimumSize(calendar,configuration.TextScale);
  private float ContentTop => configuration.HasHeader ? Math.Max(50,20*configuration.TextScale+26) : 14;
  private WidgetTaskView[] VisibleViews => Enum.GetValues<WidgetTaskView>().Where(v => configuration.Views.Contains(v.ToString().ToLowerInvariant())).ToArray();
  private bool VerticalNavigation => configuration.NavigationPosition is "left" or "right";
  private string EffectiveNavigationDisplay => VerticalNavigation && LogicalClientWidth < 340 ? "icons" : configuration.NavigationDisplay;
  private float NavigationWidth => EffectiveNavigationDisplay == "icons" ? 38 : Math.Max(106, 90 * configuration.TextScale);
  private int NavigationColumns {
    get {
      if (configuration.NavigationDisplay == "icons") return Math.Max(1,VisibleViews.Length);
      var minimum = configuration.NavigationDisplay == "text"
        ? Math.Max(72,50*configuration.TextScale) : Math.Max(90,26+50*configuration.TextScale);
      var columns = Math.Max(1,Math.Min(VisibleViews.Length,(int)((LogicalClientWidth-32)/minimum)));
      return VisibleViews.Length==4 && columns==3 ? 2 : columns;
    }
  }
  private int NavigationRows => (int)Math.Ceiling(VisibleViews.Length/(double)NavigationColumns);
  private float NavigationHeight => NavigationRows*36-4;
  private RectangleF NavigationRect => VerticalNavigation
    ? new(configuration.NavigationPosition == "left" ? 16 : LogicalClientWidth - 16 - NavigationWidth, ContentTop, NavigationWidth, Math.Max(0, AddRect.Top - ContentTop - 8))
    : new(16, configuration.NavigationPosition == "bottom" ? AddRect.Top - NavigationHeight - 8 : ContentTop, LogicalClientWidth - 32, NavigationHeight);
  private RectangleF ViewRect(WidgetTaskView view) {
    var index = Array.IndexOf(VisibleViews,view);
    if (calendar || index < 0) return RectangleF.Empty;
    var nav = NavigationRect;
    if (VerticalNavigation) { var height = Math.Min(32,(nav.Height-Math.Max(0,VisibleViews.Length-1)*4)/Math.Max(1,VisibleViews.Length)); return new(nav.X, nav.Y + index*(height+4),nav.Width,height); }
    var width = (nav.Width - Math.Max(0,NavigationColumns - 1)*6) / NavigationColumns;
    return new(nav.X + index%NavigationColumns*(width+6),nav.Y+index/NavigationColumns*36,width,32);
  }
  private RectangleF TaskArea {
    get {
      var top = ContentTop + (VisibleViews.Length > 0 && !VerticalNavigation && configuration.NavigationPosition == "top" ? NavigationHeight + 8 : 0);
      var bottom = AddRect.Top - 10 - (VisibleViews.Length > 0 && configuration.NavigationPosition == "bottom" ? NavigationHeight + 8 : 0);
      var side = VisibleViews.Length > 0 && VerticalNavigation ? NavigationWidth + 8 : 0;
      return new(16 + (configuration.NavigationPosition == "left" ? side : 0),top,LogicalClientWidth-32-side,Math.Max(30,bottom-top));
    }
  }
  private RectangleF AddRect => new(16, LogicalClientHeight - 56,
    LogicalClientWidth - 32, 40);
  private float TaskRowHeight => Math.Clamp(TaskArea.Height - 12, 30, 51);
  private int VisibleTaskRows => Math.Max(1,
    (int)Math.Floor((TaskArea.Height - 12) / TaskRowHeight));
  private int LogicalClientWidth => LogicalClientSize.Width;
  private int LogicalClientHeight => LogicalClientSize.Height;
  private Size LogicalClientSize {
    get {
      if(previewSize is {} size) return size;
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
    _ => target == HitTarget.None ? Cursors.SizeAll : Cursors.Hand,
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
    radius = Math.Clamp(radius, 0, Math.Min(bounds.Width, bounds.Height)/2);
    if (radius < 0.5f) { graphics.FillRectangle(brush, bounds); return; }
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
    radius = Math.Clamp(radius, 0, Math.Min(bounds.Width, bounds.Height)/2);
    if (radius < 0.5f) { graphics.DrawRectangle(pen,bounds.X,bounds.Y,bounds.Width,bounds.Height); return; }
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
    calendarDetail?.Close();
    quickAdd?.Close();
    quickAdd?.Dispose();
    contextMenu?.Dispose();
    openTooltip.Dispose();
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
    CalendarControl,
    CalendarDate,
    CalendarAgenda,
  }

  private enum HeaderIcon { Refresh, Open, Close }

}
