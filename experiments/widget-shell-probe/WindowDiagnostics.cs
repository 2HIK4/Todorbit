using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

// All APIs here query existing windows. This mode never creates, reparents,
// repositions, activates, or sends messages to any window.
internal static class WindowDiagnostics {
  private const int GwlStyle = -16;
  private const int GwlExStyle = -20;
  private const long WsChild = 0x40000000;
  private const long WsVisible = 0x10000000;
  private const long WsPopup = 0x80000000;
  private const long WsDisabled = 0x08000000;
  private const long WsExLayered = 0x00080000;
  private const long WsExTransparent = 0x00000020;
  private const long WsExNoActivate = 0x08000000;

  internal static void Inspect(uint targetPid) {
    Console.WriteLine($"READ-ONLY shell placement inspection for PID {targetPid}");
    var shell = Native.GetShellWindow();
    if (Native.ClassName(shell) != "Progman") {
      Console.WriteLine("GetShellWindow is not Progman; no target inference made.");
      return;
    }
    Native.GetWindowRect(shell, out var shellRect);
    Native.GetClientRect(shell, out var shellClient);
    var clientOrigin = new Native.Point { X = 0, Y = 0 };
    var originOk = Native.ClientToScreen(shell, ref clientOrigin);
    Console.WriteLine($"shell hwnd=0x{shell:X} screen={RectText(shellRect)} " +
      $"client={RectText(shellClient)} clientOriginScreen=" +
      (originOk ? PointText(clientOrigin) : "unavailable") +
      $" dpi={Native.GetDpiForWindow(shell)}");

    var primary = Screen.PrimaryScreen;
    if (primary is null) {
      Console.WriteLine("No primary monitor reported; intended rectangle unavailable.");
      return;
    }
    var intended = new Rectangle(primary.Bounds.Left + 24,
      primary.Bounds.Top + 24, 360, 228);
    var awarenessHr = Native.GetProcessDpiAwareness(0, out var awareness);
    Console.WriteLine($"inspector process DPI awareness hr=0x{awarenessHr:X8} value={awareness}; " +
      "monitor DPI below is caller-context-dependent");
    var parentPosition = new Native.Point { X = intended.X, Y = intended.Y };
    var conversionOk = Native.ScreenToClient(shell, ref parentPosition);
    var roundTrip = parentPosition;
    var roundTripOk = conversionOk && Native.ClientToScreen(shell, ref roundTrip);
    Console.WriteLine($"intended screen={intended} parentClient=" +
      (conversionOk ? PointText(parentPosition) : "unavailable") +
      " roundTripScreen=" + (roundTripOk ? PointText(roundTrip) : "unavailable"));
    PrintMonitors(intended, "intended");
    PrintTopLevelAt(intended, shell);

    nint target = 0;
    var index = 0;
    Console.WriteLine("Progman direct children, front to back:");
    for (var child = Native.GetWindow(shell, 5u); child != 0;
         child = Native.GetWindow(child, 2u)) {
      Native.GetWindowThreadProcessId(child, out var childPid);
      Native.GetWindowRect(child, out var childRect);
      Console.WriteLine($"  [{index++}] hwnd=0x{child:X} class={Native.ClassName(child)} " +
        $"pid={childPid} visible={Native.IsWindowVisible(child)} " +
        $"screen={RectText(childRect)}");
      if (childPid == targetPid) target = child;
    }
    if (target == 0) {
      Console.WriteLine("No direct Progman child owned by that PID is present. " +
        "The experiment may have exited or its window may have been destroyed.");
      return;
    }
    Native.GetWindowRect(target, out var actual);
    var style = Native.GetWindowLongPtr(target, GwlStyle).ToInt64();
    var exStyle = Native.GetWindowLongPtr(target, GwlExStyle).ToInt64();
    var owner = Native.GetWindow(target, 4u);
    var parent = Native.GetParent(target);
    Console.WriteLine($"target hwnd=0x{target:X} parent=0x{parent:X} " +
      $"owner=0x{owner:X} screen={RectText(actual)} " +
      $"style=0x{style:X} exStyle=0x{exStyle:X} " +
      $"WS_CHILD={Has(style, WsChild)} WS_VISIBLE={Has(style, WsVisible)} " +
      $"WS_POPUP={Has(style, WsPopup)} WS_DISABLED={Has(style, WsDisabled)} " +
      $"WS_EX_LAYERED={Has(exStyle, WsExLayered)} " +
      $"WS_EX_TRANSPARENT={Has(exStyle, WsExTransparent)} " +
      $"WS_EX_NOACTIVATE={Has(exStyle, WsExNoActivate)} " +
      $"IsWindowVisible={Native.IsWindowVisible(target)} " +
      $"IsIconic={Native.IsIconic(target)} dpi={Native.GetDpiForWindow(target)} " +
      $"dpiAwareness={Native.GetAwarenessFromDpiAwarenessContext(Native.GetWindowDpiAwarenessContext(target))}");
    Console.WriteLine($"actualMinusIntended=({actual.Left - intended.Left}," +
      $"{actual.Top - intended.Top}) size={actual.Right - actual.Left}x" +
      $"{actual.Bottom - actual.Top}");
    PrintMonitors(new Rectangle(actual.Left, actual.Top,
      actual.Right - actual.Left, actual.Bottom - actual.Top), "actual");

    var cloakHr = Native.DwmGetWindowAttribute(target, 14u,
      out int cloak, (uint)Marshal.SizeOf<int>());
    var frameHr = Native.DwmGetWindowAttribute(target, 9u,
      out Native.Rect frame, (uint)Marshal.SizeOf<Native.Rect>());
    Console.WriteLine($"DWM cloak hr=0x{cloakHr:X8} value={cloak}; " +
      $"extendedFrame hr=0x{frameHr:X8} screen={RectText(frame)}");
    var center = new Native.Point {
      X = actual.Left + (actual.Right - actual.Left) / 2,
      Y = actual.Top + (actual.Bottom - actual.Top) / 2,
    };
    var hit = Native.WindowFromPoint(center);
    Native.GetWindowThreadProcessId(hit, out var hitPid);
    var hitRoot = Native.GetAncestor(hit, 2u);
    Console.WriteLine($"center={PointText(center)} WindowFromPoint=0x{hit:X} " +
      $"class={Native.ClassName(hit)} pid={hitPid} " +
      $"root=0x{hitRoot:X} rootClass={Native.ClassName(hitRoot)}; " +
      "a different hit target suggests occlusion or hit-test routing, not proof of drawing");
    Console.WriteLine("Visibility flags and Z-order do not prove pixels are drawn; " +
      "inspect the desktop manually while this process is running.");
  }

  private static bool Has(long value, long flag) => (value & flag) != 0;

  private static void PrintMonitors(Rectangle rectangle, string label) {
    foreach (var monitor in Screen.AllScreens) {
      var intersection = Rectangle.Intersect(rectangle, monitor.Bounds);
      var center = new Native.Point {
        X = monitor.Bounds.Left + monitor.Bounds.Width / 2,
        Y = monitor.Bounds.Top + monitor.Bounds.Height / 2,
      };
      var handle = Native.MonitorFromPoint(center, 2u);
      var dpiHr = Native.GetDpiForMonitor(handle, 0,
        out var dpiX, out var dpiY);
      var scaleHr = Native.GetScaleFactorForMonitor(handle, out var scalePercent);
      Console.WriteLine($"{label} monitor={monitor.DeviceName} " +
        $"primary={monitor.Primary} bounds={monitor.Bounds} " +
        $"intersection={intersection} area={intersection.Width * intersection.Height} " +
        $"effectiveDpiHr=0x{dpiHr:X8} effectiveDpi={dpiX}x{dpiY} " +
        $"scaleHr=0x{scaleHr:X8} scalePercent={scalePercent}");
    }
  }

  private static void PrintTopLevelAt(Rectangle intended, nint shell) {
    var center = new Native.Point {
      X = intended.Left + intended.Width / 2,
      Y = intended.Top + intended.Height / 2,
    };
    var hit = Native.WindowFromPoint(center);
    Native.GetWindowThreadProcessId(hit, out var hitPid);
    Console.WriteLine($"intended center={PointText(center)} WindowFromPoint=0x{hit:X} " +
      $"class={Native.ClassName(hit)} pid={hitPid}");
    var overlaps = 0;
    var beforeShell = true;
    Native.EnumWindows((window, _) => {
      if (window == shell) {
        beforeShell = false;
        return true;
      }
      if (!beforeShell || !Native.IsWindowVisible(window)) return true;
      Native.GetWindowRect(window, out var bounds);
      if (center.X < bounds.Left || center.X >= bounds.Right ||
          center.Y < bounds.Top || center.Y >= bounds.Bottom) return true;
      overlaps++;
      if (overlaps <= 12) {
        Native.GetWindowThreadProcessId(window, out var pid);
        Console.WriteLine($"  top-level ahead of Progman at center: " +
          $"hwnd=0x{window:X} class={Native.ClassName(window)} pid={pid} " +
          $"screen={RectText(bounds)}");
      }
      return true;
    }, 0);
    Console.WriteLine($"top-level candidates ahead of Progman at center={overlaps} " +
      "(bounding-box overlap only; transparent windows may not occlude)");
  }

  private static string RectText(Native.Rect value) =>
    $"({value.Left},{value.Top})-({value.Right},{value.Bottom})";

  private static string PointText(Native.Point value) =>
    $"({value.X},{value.Y})";
}
