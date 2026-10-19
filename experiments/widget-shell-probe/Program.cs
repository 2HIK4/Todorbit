using System.Runtime.InteropServices;
using System.Text;

if (args.Length >= 1 && args[0] is "--widget" or "--widget-command") {
  var appExe = ArgumentValue(args, "--app-exe");
  var diagnostics = args.Contains(
    "--render-diagnostics", StringComparer.OrdinalIgnoreCase);
  var initialCommand = args[0] == "--widget-command"
    ? ArgumentValue(args, "--widget-command") ?? "show"
    : args.Contains("--background", StringComparer.OrdinalIgnoreCase)
      ? "background" : "show";
  using var instance = new Mutex(initiallyOwned: true,
    name: "Local\\LifeManagerDesktopWidget-Native-" + AppDataPaths.ChannelSuffix,
    out var ownsMutex);
  if (!ownsMutex) {
    if (!WidgetCommandServer.TrySend(initialCommand)) {
      Console.Error.WriteLine("The running widget did not accept the command.");
      Environment.ExitCode = 2;
    }
    return;
  }
  if (args[0] == "--widget-command" && initialCommand is "hide" or "exit") {
    return;
  }
  ApplicationConfiguration.Initialize();
  try {
    using var repository = LifeManagerWidgetRepository.OpenDefault();
    Application.Run(new NativeWidgetApplicationContext(
      repository, appExe, diagnostics,
      initialCommand == "toggle" ? "show" : initialCommand));
  } catch (Exception error) {
    Console.Error.WriteLine(error);
    MessageBox.Show(error.Message, "TodoPilot widget",
      MessageBoxButtons.OK, MessageBoxIcon.Error);
    Environment.ExitCode = 1;
  }
  return;
}
if (args.Length >= 1 && args[0] is
    "--widget-standalone" or "--widget-legacy-reparent") {
  if (PrivacyState.OpenDefault().IsLocked()) {
    Console.Error.WriteLine("TodoPilot is locked. Open the main app to unlock.");
    Environment.ExitCode = 2;
    return;
  }
  var appExe = ArgumentValue(args, "--app-exe");
  var lightTheme = args.Contains("--light", StringComparer.OrdinalIgnoreCase);
  var diagnostics = args.Contains(
    "--render-diagnostics", StringComparer.OrdinalIgnoreCase);
  var hostMode = args[0] == "--widget-standalone"
    ? WidgetHostMode.Standalone : WidgetHostMode.LegacyReparent;
  using var instance = new Mutex(initiallyOwned: true,
    name: $"Local\\LifeManagerDesktopWidget-{hostMode}", out var ownsMutex);
  if (!ownsMutex) return;
  ApplicationConfiguration.Initialize();
  using var repository = LifeManagerWidgetRepository.OpenDefault();
  Application.Run(new LifeManagerWidget(
    repository, appExe, lightTheme, hostMode, diagnostics));
  return;
}
if (args is ["--self-test"]) {
  try {
    LifeManagerWidgetSelfTest.Run();
    Console.WriteLine("Widget persistence self-test passed.");
  } catch (Exception error) {
    Console.Error.WriteLine(error);
    Environment.ExitCode = 1;
  }
  return;
}
if (args is ["--attach-prototype"]) {
  ApplicationConfiguration.Initialize();
  Application.Run(new ShellHostPrototype(attachToShell: true));
  return;
}
if (args is ["--standalone"]) {
  ApplicationConfiguration.Initialize();
  Application.Run(new ShellHostPrototype(attachToShell: false));
  return;
}
if (args is ["--standalone-capture", var capturePath]) {
  ApplicationConfiguration.Initialize();
  Application.Run(new ShellHostPrototype(
    attachToShell: false, capturePath: capturePath));
  return;
}
if (args is ["--inspect-pid", var pidText] && uint.TryParse(pidText, out var targetPid)) {
  ApplicationConfiguration.Initialize();
  WindowDiagnostics.Inspect(targetPid);
  return;
}
if (args is ["--inspect-pid", var delayedPidText, "--delay-seconds", var delayText] &&
    uint.TryParse(delayedPidText, out var delayedPid) &&
    int.TryParse(delayText, out var delaySeconds) && delaySeconds is >= 1 and <= 15) {
  ApplicationConfiguration.Initialize();
  Console.WriteLine($"Read-only snapshot in {delaySeconds} seconds. You may manually show the desktop now.");
  Thread.Sleep(TimeSpan.FromSeconds(delaySeconds));
  WindowDiagnostics.Inspect(delayedPid);
  return;
}
if (args.Length != 0) {
  Console.Error.WriteLine("Usage: life_manager_widget [--widget [--render-diagnostics] [--app-exe PATH] | --widget-command show|hide|toggle|quick-add|refresh|exit | --self-test | diagnostic options]");
  return;
}

// Read-only shell inventory. Never sends messages to Explorer or changes windows.
var windows = new List<nint>();
Native.EnumWindows((window, _) => {
  windows.Add(window);
  return true;
}, 0);

PrintSpecial("desktop", Native.GetDesktopWindow());
PrintSpecial("shell", Native.GetShellWindow());
Console.WriteLine("shell children (front to back):");
for (var child = Native.GetWindow(Native.GetShellWindow(), 5u);
     child != 0;
     child = Native.GetWindow(child, 2u)) {
  PrintWindow("  sibling", child);
}
for (var index = 0; index < windows.Count; index++) {
  var window = windows[index];
  var className = Native.ClassName(window);
  if (!IsShellClass(className) && !HasShellChild(window)) continue;
  PrintWindow($"top[{index}]", window);
  Native.EnumChildWindows(window, (child, _) => {
    var childClass = Native.ClassName(child);
    if (IsShellClass(childClass)) PrintWindow("  child", child);
    return true;
  }, 0);
}

static bool IsShellClass(string value) =>
  value is "WorkerW" or "Progman" or "SHELLDLL_DefView" or "SysListView32";

static bool HasShellChild(nint window) {
  var found = false;
  Native.EnumChildWindows(window, (child, _) => {
    if (IsShellClass(Native.ClassName(child))) found = true;
    return !found;
  }, 0);
  return found;
}

static string? ArgumentValue(string[] values, string name) {
  for (var index = 0; index < values.Length - 1; index++) {
    if (values[index] == name) return values[index + 1];
  }
  return null;
}

static void PrintSpecial(string label, nint window) => PrintWindow(label, window);

static void PrintWindow(string label, nint window) {
  Native.GetWindowThreadProcessId(window, out var processId);
  Native.GetWindowRect(window, out var bounds);
  var parent = Native.GetParent(window);
  var owner = Native.GetWindow(window, 4);
  Console.WriteLine(
    $"{label} hwnd=0x{window:X} class={Native.ClassName(window)} " +
    $"pid={processId} process={WindowDiagnostics.ProcessName(processId)} " +
    $"parent=0x{parent:X} owner=0x{owner:X} visible={Native.IsWindowVisible(window)} " +
    $"rect=({bounds.Left},{bounds.Top})-({bounds.Right},{bounds.Bottom})");
}

internal static class Native {
  internal delegate bool EnumWindowCallback(nint window, nint parameter);

  [StructLayout(LayoutKind.Sequential)]
  internal struct Rect {
    internal int Left;
    internal int Top;
    internal int Right;
    internal int Bottom;
  }

  [StructLayout(LayoutKind.Sequential)]
  internal struct Point {
    internal int X;
    internal int Y;
  }

  [StructLayout(LayoutKind.Sequential)]
  internal struct Size {
    internal int Width;
    internal int Height;
  }

  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct BlendFunction {
    internal byte BlendOp;
    internal byte BlendFlags;
    internal byte SourceConstantAlpha;
    internal byte AlphaFormat;
  }

  [StructLayout(LayoutKind.Sequential)]
  internal struct PaintStruct {
    internal nint DeviceContext;
    [MarshalAs(UnmanagedType.Bool)] internal bool Erase;
    internal Rect Paint;
    [MarshalAs(UnmanagedType.Bool)] internal bool Restore;
    [MarshalAs(UnmanagedType.Bool)] internal bool IncrementalUpdate;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
    internal byte[] Reserved;
  }

  [StructLayout(LayoutKind.Sequential)]
  internal struct TrackMouseEventData {
    internal uint Size;
    internal uint Flags;
    internal nint Window;
    internal uint HoverTime;
  }

  [DllImport("user32.dll")]
  internal static extern bool EnumWindows(EnumWindowCallback callback, nint parameter);

  [DllImport("user32.dll")]
  internal static extern bool EnumChildWindows(nint parent, EnumWindowCallback callback, nint parameter);

  [DllImport("user32.dll")]
  internal static extern nint GetDesktopWindow();

  [DllImport("user32.dll")]
  internal static extern nint GetShellWindow();

  [DllImport("user32.dll")]
  internal static extern nint GetParent(nint window);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool IsWindow(nint window);

  [DllImport("user32.dll")]
  internal static extern nint GetWindow(nint window, uint command);

  [DllImport("user32.dll")]
  internal static extern nint GetForegroundWindow();

  [DllImport("user32.dll")]
  internal static extern nint GetFocus();

  [DllImport("user32.dll")]
  internal static extern nint GetActiveWindow();

  [DllImport("user32.dll", SetLastError = true)]
  internal static extern nint SetParent(nint child, nint newParent);

  [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
  internal static extern nint GetWindowLongPtr(nint window, int index);

  [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
  internal static extern nint SetWindowLongPtr(nint window, int index, nint value);

  [DllImport("user32.dll", SetLastError = true)]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool SetWindowPos(
    nint window, nint after, int x, int y, int width, int height, uint flags);

  [DllImport("user32.dll")]
  internal static extern uint GetWindowThreadProcessId(nint window, out uint processId);

  [DllImport("user32.dll")]
  internal static extern bool GetWindowRect(nint window, out Rect bounds);

  [DllImport("user32.dll")]
  internal static extern bool GetClientRect(nint window, out Rect bounds);

  [DllImport("user32.dll")]
  internal static extern nint BeginPaint(
    nint window, out PaintStruct paint);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool EndPaint(
    nint window, ref PaintStruct paint);

  [DllImport("user32.dll")]
  internal static extern nint GetDC(nint window);

  [DllImport("user32.dll")]
  internal static extern int ReleaseDC(nint window, nint dc);

  [DllImport("gdi32.dll")]
  internal static extern nint CreateCompatibleDC(nint dc);

  [DllImport("gdi32.dll")]
  internal static extern bool DeleteDC(nint dc);

  [DllImport("gdi32.dll")]
  internal static extern nint SelectObject(nint dc, nint item);

  [DllImport("gdi32.dll")]
  internal static extern bool DeleteObject(nint item);

  [DllImport("user32.dll", SetLastError = true)]
  internal static extern bool UpdateLayeredWindow(
    nint window, nint destinationDc, ref Point destination,
    ref Size size, nint sourceDc, ref Point source,
    uint colorKey, ref BlendFunction blend, uint flags);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool TrackMouseEvent(ref TrackMouseEventData data);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool GetUpdateRect(
    nint window, out Rect bounds, [MarshalAs(UnmanagedType.Bool)] bool erase);

  [DllImport("user32.dll", SetLastError = true)]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool RedrawWindow(
    nint window, nint updateRect, nint updateRegion, uint flags);

  [DllImport("user32.dll")]
  internal static extern bool ScreenToClient(nint window, ref Point point);

  [DllImport("user32.dll")]
  internal static extern bool ClientToScreen(nint window, ref Point point);

  [DllImport("user32.dll")]
  internal static extern bool GetCursorPos(out Point point);

  [DllImport("user32.dll")]
  internal static extern nint SetCapture(nint window);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool ReleaseCapture();

  [DllImport("user32.dll")]
  internal static extern nint WindowFromPoint(Point point);

  [DllImport("user32.dll")]
  internal static extern nint GetAncestor(nint window, uint flags);

  [DllImport("user32.dll")]
  internal static extern nint MonitorFromPoint(Point point, uint flags);

  [DllImport("user32.dll")]
  internal static extern uint GetDpiForWindow(nint window);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool IsIconic(nint window);

  [DllImport("dwmapi.dll")]
  internal static extern int DwmGetWindowAttribute(
    nint window, uint attribute, out Rect value, uint size);

  [DllImport("dwmapi.dll")]
  internal static extern int DwmGetWindowAttribute(
    nint window, uint attribute, out int value, uint size);

  [DllImport("shcore.dll")]
  internal static extern int GetDpiForMonitor(
    nint monitor, int dpiType, out uint dpiX, out uint dpiY);

  [DllImport("shcore.dll")]
  internal static extern int GetScaleFactorForMonitor(
    nint monitor, out int scalePercent);

  [DllImport("shcore.dll")]
  internal static extern int GetProcessDpiAwareness(nint process, out int awareness);

  [DllImport("user32.dll")]
  internal static extern nint GetWindowDpiAwarenessContext(nint window);

  [DllImport("user32.dll")]
  internal static extern int GetAwarenessFromDpiAwarenessContext(nint context);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool IsWindowVisible(nint window);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  internal static extern bool ShowWindow(nint window, int command);

  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  private static extern int GetClassName(nint window, StringBuilder name, int maxLength);

  internal static string ClassName(nint window) {
    var name = new StringBuilder(256);
    return GetClassName(window, name, name.Capacity) == 0 ? "?" : name.ToString();
  }
}
