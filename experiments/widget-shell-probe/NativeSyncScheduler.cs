using System.Diagnostics;

// The companion schedules the same Dart engine as the foreground app. It does
// not read keys, implement the encrypted protocol or migrate the database.
internal sealed class NativeSyncScheduler : IDisposable {
  private readonly System.Windows.Forms.Timer periodic = new() { Interval = 60000 };
  private readonly System.Windows.Forms.Timer debounce = new() { Interval = 1000 };
  private readonly Func<bool> enabled;
  private readonly Func<string> executable;
  private Process? worker;
  internal NativeSyncScheduler(Func<bool> enabled, Func<string> executable) {
    this.enabled = enabled;
    this.executable = executable;
    periodic.Tick += (_, _) => Poll();
    debounce.Tick += (_, _) => { debounce.Stop(); Poll(); };
    periodic.Start();
  }
  internal void Request() { debounce.Stop(); debounce.Start(); }
  private void Poll() {
    try {
      if (worker is { HasExited: false }) return;
      worker?.Dispose(); worker = null;
      if (!enabled()) return;
      var start = new ProcessStartInfo(executable()) {
        UseShellExecute = false, CreateNoWindow = true,
        WindowStyle = ProcessWindowStyle.Hidden,
      };
      start.ArgumentList.Add("--sync-background");
      worker = Process.Start(start);
    } catch {
      // Missing authorization, a stopped app or a busy schema retains all
      // work. The next permitted foreground/background opportunity retries.
    }
  }
  public void Dispose() {
    periodic.Stop(); debounce.Stop();
    periodic.Dispose(); debounce.Dispose();
    worker?.Dispose(); worker = null;
  }
}
