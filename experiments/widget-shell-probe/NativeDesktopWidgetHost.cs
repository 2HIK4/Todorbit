using System.Diagnostics;
using System.Drawing.Drawing2D;

internal sealed class NativeWidgetApplicationContext : ApplicationContext {
  private readonly NativeDesktopWidgetHost host;

  internal NativeWidgetApplicationContext(
      LifeManagerWidgetRepository repository, string? appExe,
      bool lightTheme, bool diagnostics) {
    host = new NativeDesktopWidgetHost(repository, appExe,
      lightTheme ? WidgetPalette.Light : WidgetPalette.Dark,
      diagnostics, ExitThread);
  }

  protected override void Dispose(bool disposing) {
    if (disposing) host.Dispose();
    base.Dispose(disposing);
  }
}

// A single owner-drawn HWND is created as an Explorer child from the beginning.
// Unlike a WinForms Form, NativeWindow does not park or reparent the HWND.
internal sealed class NativeDesktopWidgetHost : NativeWindow, IDisposable {
  private const int LogicalWidth = 376;
  private const int LogicalHeight = 460;
  private const int VisibleTaskRows = 5;
  private const int WmDestroy = 0x0002;
  private const int WmPaint = 0x000F;
  private const int WmEraseBackground = 0x0014;
  private const int WmMouseMove = 0x0200;
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
  private readonly WidgetPalette palette;
  private readonly WidgetRenderDiagnostics diagnostics;
  private readonly Action exit;
  private IReadOnlyList<WidgetTask> tasks = [];
  private float scale = 1f;
  private int scrollOffset;
  private HitTarget hoverTarget = HitTarget.None;
  private int hoverTask = -1;
  private string statusText = "Loading...";
  private bool disposed;

  internal NativeDesktopWidgetHost(
      LifeManagerWidgetRepository repository, string? appExe,
      WidgetPalette palette, bool diagnosticsEnabled, Action exit) {
    this.repository = repository;
    this.appExe = appExe;
    this.palette = palette;
    this.exit = exit;
    diagnostics = new WidgetRenderDiagnostics(diagnosticsEnabled);
    var (parent, position) = ResolveDesktopIconHost();
    var dpi = Native.GetDpiForWindow(parent);
    scale = dpi == 0 ? 1f : dpi / 96f;
    var parameters = new CreateParams {
      Caption = "Life Manager Desktop Widget",
      Parent = parent,
      X = position.X,
      Y = position.Y,
      Width = Pixel(LogicalWidth),
      Height = Pixel(LogicalHeight),
      Style = WsChild | WsVisible | WsClipChildren | WsClipSiblings,
    };
    CreateHandle(parameters);
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
      case WmMouseLeave:
        SetHover(HitTarget.None, -1);
        message.Result = 0;
        return;
      case WmLeftButtonUp:
        Click(LogicalPoint(message.LParam));
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
        if (!disposed) exit();
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
    using var border = new Pen(palette.Border);
    graphics.DrawRectangle(border, 0, 0, LogicalWidth - 1, LogicalHeight - 1);
    using var titleFont = new Font("Segoe UI Semibold", 15, FontStyle.Bold);
    using var bodyFont = new Font("Segoe UI", 9.5f);
    using var smallFont = new Font("Segoe UI", 8);
    using var buttonFont = new Font("Segoe UI Semibold", 8.5f, FontStyle.Bold);
    using var taskFont = new Font("Segoe UI", 9.5f);
    using var foreground = new SolidBrush(palette.Foreground);
    using var muted = new SolidBrush(palette.Muted);

    graphics.DrawString("Life Manager", titleFont, foreground,
      new RectangleF(16, 12, 170, 32));
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
      graphics.DrawString("Nothing due today\nYour Inbox is clear.",
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
          new RectangleF(24, 354, 326, 23), rangeFormat);
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
      new RectangleF(16, 439, 344, 18), statusFormat);
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
    var tracking = new Native.TrackMouseEventData {
      Size = (uint)System.Runtime.InteropServices.Marshal.SizeOf<Native.TrackMouseEventData>(),
      Flags = 0x00000002,
      Window = Handle,
    };
    Native.TrackMouseEvent(ref tracking);
    var (target, task) = HitTest(point);
    SetHover(target, task);
    Cursor.Current = target == HitTarget.None ? Cursors.Default : Cursors.Hand;
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

  private void RefreshTasks() {
    RunAction(() => {
      tasks = repository.LoadTasks(DateTime.Now);
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
    var primary = Screen.PrimaryScreen?.WorkingArea;
    if (primary is null) return;
    var point = new Native.Point {
      X = primary.Value.Right - Pixel(LogicalWidth) - 24,
      Y = primary.Value.Top + 24,
    };
    if (!Native.ScreenToClient(parent, ref point)) return;
    Native.SetWindowPos(Handle, 0, point.X, point.Y,
      Pixel(LogicalWidth), Pixel(LogicalHeight), SwpNoActivate);
  }

  private static (nint Parent, Native.Point Position) ResolveDesktopIconHost() {
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
    var primary = Screen.PrimaryScreen?.WorkingArea;
    if (primary is null) {
      throw new InvalidOperationException("No primary display is available.");
    }
    var dpi = Native.GetDpiForWindow(parent);
    var scale = dpi == 0 ? 1f : dpi / 96f;
    var point = new Native.Point {
      X = primary.Value.Right - (int)Math.Round(LogicalWidth * scale) - 24,
      Y = primary.Value.Top + 24,
    };
    if (!Native.ScreenToClient(parent, ref point)) {
      throw new InvalidOperationException(
        "The widget position could not be mapped into Explorer coordinates.");
    }
    return (parent, point);
  }

  private PointF LogicalPoint(nint parameter) {
    var packed = parameter.ToInt64();
    var x = unchecked((short)(packed & 0xFFFF));
    var y = unchecked((short)((packed >> 16) & 0xFFFF));
    return new PointF(x / scale, y / scale);
  }

  private int Pixel(int logical) => (int)Math.Round(logical * scale);

  private static RectangleF TaskRowRect(int visibleIndex) =>
    new(23, 89 + visibleIndex * 51, 330, 46);

  private static RectangleF CheckboxRect(int visibleIndex) =>
    new(33, 103 + visibleIndex * 51, 18, 18);

  private static RectangleF RefreshRect => new(190, 17, 64, 30);
  private static RectangleF OpenRect => new(258, 17, 48, 30);
  private static RectangleF CloseRect => new(310, 17, 50, 30);
  private static RectangleF TaskArea => new(16, 82, 344, 302);
  private static RectangleF AddRect => new(16, 397, 344, 40);

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
