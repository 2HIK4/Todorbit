using System.Globalization;

internal sealed class WidgetRenderDiagnostics : IDisposable {
  private const int WmPaint = 0x000F;
  private const int WmEraseBackground = 0x0014;
  private const int WmShowWindow = 0x0018;
  private const int WmWindowPositionChanged = 0x0047;
  private const int WmPrint = 0x0317;
  private const int WmPrintClient = 0x0318;
  private readonly StreamWriter? writer;
  private int paintCount;
  private int eraseCount;
  private int printCount;
  private int positionCount;
  private int detailedMessages;

  internal WidgetRenderDiagnostics(bool enabled) {
    if (!enabled) return;
    try {
      var appData = Environment.GetFolderPath(
        Environment.SpecialFolder.ApplicationData);
      var directory = Path.Combine(appData, "Life Manager", "logs");
      Directory.CreateDirectory(directory);
      var path = Path.Combine(directory,
        $"native-widget-render-{Environment.ProcessId}.log");
      if (File.Exists(path) && new FileInfo(path).Length > 1024 * 1024) {
        File.WriteAllText(path, string.Empty);
      }
      writer = new StreamWriter(path, append: true) { AutoFlush = true };
      Write("render diagnostics started; no task text or keyboard data is logged");
    } catch (IOException) {
      writer = null;
    } catch (UnauthorizedAccessException) {
      writer = null;
    }
  }

  internal void Message(Form form, int message) {
    Message(form.IsHandleCreated ? form.Handle : 0, message);
  }

  internal void Message(nint handle, int message) {
    if (writer == null) return;
    string? name = null;
    switch (message) {
      case WmPaint:
        paintCount++;
        name = "WM_PAINT";
        break;
      case WmEraseBackground:
        eraseCount++;
        name = "WM_ERASEBKGND";
        break;
      case WmPrint:
        printCount++;
        name = "WM_PRINT";
        break;
      case WmPrintClient:
        printCount++;
        name = "WM_PRINTCLIENT";
        break;
      case WmShowWindow:
        name = "WM_SHOWWINDOW";
        break;
      case WmWindowPositionChanged:
        positionCount++;
        name = "WM_WINDOWPOSCHANGED";
        break;
    }
    if (name == null || detailedMessages >= 30) return;
    detailedMessages++;
    var updateText = "unavailable";
    if (handle != 0 &&
        Native.GetUpdateRect(handle, out var update, erase: false)) {
      updateText = $"({update.Left},{update.Top})-({update.Right},{update.Bottom})";
    }
    Write($"message={name} hwnd=0x{handle:X} update={updateText}");
  }

  internal void Snapshot(Form form, string reason) {
    if (!form.IsHandleCreated) return;
    Snapshot(form.Handle, reason);
  }

  internal void Snapshot(nint handle, string reason) {
    if (writer == null || handle == 0) return;
    Native.GetWindowRect(handle, out var bounds);
    var style = Native.GetWindowLongPtr(handle, -16).ToInt64();
    var exStyle = Native.GetWindowLongPtr(handle, -20).ToInt64();
    Write($"snapshot={reason} hwnd=0x{handle:X} " +
      $"parent=0x{Native.GetParent(handle):X} " +
      $"parentClass={Native.ClassName(Native.GetParent(handle))} " +
      $"style=0x{style:X} exStyle=0x{exStyle:X} " +
      $"visible={Native.IsWindowVisible(handle)} " +
      $"screen=({bounds.Left},{bounds.Top})-({bounds.Right},{bounds.Bottom}) " +
      $"paint={paintCount} erase={eraseCount} print={printCount} " +
      $"position={positionCount}");
  }

  private void Write(string value) {
    try {
      writer?.WriteLine(
        $"{DateTime.Now.ToString("O", CultureInfo.InvariantCulture)} " +
        $"pid={Environment.ProcessId} {value}");
    } catch (IOException) {
      // Diagnostics must never affect widget behavior.
    } catch (ObjectDisposedException) {
      // Ignore messages racing with shutdown.
    }
  }

  public void Dispose() {
    if (writer == null) return;
    Write($"render diagnostics stopped paint={paintCount} " +
      $"erase={eraseCount} print={printCount} position={positionCount}");
    writer.Dispose();
  }
}
