using System.Drawing;
using System.Windows.Forms;

// Deliberately separate from the Flutter widget and database. This tests shell
// layering and a user-activated top-level input surface, not task persistence.
internal sealed class ShellHostPrototype : Form {
  private const long WsChild = 0x40000000;
  private const long WsPopup = 0x80000000;
  private const long WsOverlappedWindow = 0x00CF0000;
  private const uint SwpFrameChanged = 0x0020;
  private const uint SwpShowWindow = 0x0040;
  private const uint SwpNoActivate = 0x0010;

  private readonly Label summary = new();
  private readonly Form inputPopup = new();
  private readonly TextBox editor = new();
  private readonly System.Windows.Forms.Timer timeout = new();
  private int submitted;

  internal ShellHostPrototype() {
    Text = "Life Manager shell-host experiment";
    FormBorderStyle = FormBorderStyle.None;
    StartPosition = FormStartPosition.Manual;
    Location = new Point(24, 24);
    ClientSize = new Size(360, 228);
    BackColor = Color.FromArgb(27, 31, 45);
    ForeColor = Color.White;
    ShowInTaskbar = false;

    var header = new Label {
      Text = "Life Manager - shell test",
      Font = new Font("Segoe UI", 14, FontStyle.Bold),
      Location = new Point(16, 14),
      Size = new Size(330, 32),
    };
    summary.Text = "No task data is opened. Click Input to test typing.";
    summary.Location = new Point(16, 55);
    summary.Size = new Size(330, 62);
    var inputButton = new Button {
      Text = "Input...",
      Location = new Point(16, 131),
      Size = new Size(155, 36),
    };
    inputButton.Click += (_, _) => OpenInput();
    var stopButton = new Button {
      Text = "Stop experiment",
      Location = new Point(181, 131),
      Size = new Size(163, 36),
    };
    stopButton.Click += (_, _) => Close();
    var hint = new Label {
      Text = "Auto-exits after 10 minutes. No Explorer changes persist.",
      Location = new Point(16, 184),
      Size = new Size(330, 36),
    };
    Controls.AddRange([header, summary, inputButton, stopButton, hint]);

    inputPopup.Text = "Life Manager input test";
    inputPopup.FormBorderStyle = FormBorderStyle.FixedDialog;
    inputPopup.StartPosition = FormStartPosition.Manual;
    inputPopup.ClientSize = new Size(350, 102);
    inputPopup.MaximizeBox = false;
    inputPopup.MinimizeBox = false;
    inputPopup.ShowInTaskbar = true;
    inputPopup.Controls.Add(editor);
    editor.Location = new Point(12, 15);
    editor.Size = new Size(325, 30);
    editor.PlaceholderText = "Type, paste, Backspace, then Enter";
    editor.KeyDown += (_, eventArgs) => {
      if (eventArgs.KeyCode != Keys.Enter) return;
      eventArgs.SuppressKeyPress = true;
      if (editor.Text.Trim().Length > 0) {
        submitted++;
        summary.Text = $"Keyboard entry {submitted} received in memory.";
      }
      editor.Clear();
      inputPopup.Hide();
    };
    inputPopup.FormClosing += (_, eventArgs) => {
      if (eventArgs.CloseReason != CloseReason.UserClosing) return;
      eventArgs.Cancel = true;
      inputPopup.Hide();
    };

    timeout.Interval = 10 * 60 * 1000;
    timeout.Tick += (_, _) => Close();
    timeout.Start();
  }

  protected override void OnShown(EventArgs eventArgs) {
    base.OnShown(eventArgs);
    var shell = Native.GetShellWindow();
    if (Native.ClassName(shell) != "Progman" || !Native.IsWindowVisible(shell)) {
      Console.Error.WriteLine("No visible Progman shell window; not attaching.");
      Close();
      return;
    }
    Native.GetWindowThreadProcessId(shell, out var shellPid);
    if (shellPid == Environment.ProcessId) {
      Console.Error.WriteLine("Unexpected in-process shell target; not attaching.");
      Close();
      return;
    }
    var defView = Native.GetWindow(shell, 5u);
    if (Native.ClassName(defView) != "SHELLDLL_DefView") {
      Console.Error.WriteLine("Shell child hierarchy changed; not attaching.");
      Close();
      return;
    }
    var originalStyle = Native.GetWindowLongPtr(Handle, -16);
    var childStyle = (originalStyle.ToInt64() & ~(WsPopup | WsOverlappedWindow)) | WsChild;
    var primary = Screen.PrimaryScreen?.Bounds;
    if (primary is null) {
      Console.Error.WriteLine("No primary display; not attaching.");
      Close();
      return;
    }
    var position = new Native.Point {
      X = primary.Value.Left + 24,
      Y = primary.Value.Top + 24,
    };
    if (!Native.ScreenToClient(shell, ref position)) {
      Console.Error.WriteLine("Could not map the primary display into Progman coordinates.");
      Close();
      return;
    }
    Native.SetWindowLongPtr(Handle, -16, (nint)childStyle);
    Native.SetParent(Handle, shell);
    if (Native.GetParent(Handle) != shell ||
        !Native.SetWindowPos(Handle, 0, position.X, position.Y, 360, 228,
          SwpFrameChanged | SwpShowWindow | SwpNoActivate)) {
      Console.Error.WriteLine($"Attachment failed, Win32 error={System.Runtime.InteropServices.Marshal.GetLastWin32Error()}.");
      Close();
      return;
    }
    Console.WriteLine($"Attached experimental surface pid={Environment.ProcessId} " +
      $"hwnd=0x{Handle:X} Progman=0x{shell:X}; close this process to remove it.");
  }

  private void OpenInput() {
    inputPopup.Location = PointToScreen(new Point(8, ClientSize.Height + 12));
    inputPopup.Show();
    inputPopup.Activate();
    editor.Focus();
    Console.WriteLine($"popup foreground=0x{Native.GetForegroundWindow():X} " +
      $"active=0x{Native.GetActiveWindow():X} focus=0x{Native.GetFocus():X} " +
      $"editor=0x{editor.Handle:X}");
  }

  protected override void OnFormClosed(FormClosedEventArgs eventArgs) {
    timeout.Stop();
    inputPopup.Dispose();
    base.OnFormClosed(eventArgs);
  }
}
