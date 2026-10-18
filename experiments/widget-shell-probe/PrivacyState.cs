using System.Diagnostics;
using System.Text.Json;

// The native companion never verifies a PIN. It trusts only a short-lived
// session written by the main app after PIN verification, and fails closed.
internal sealed class PrivacyState {
  private readonly string settingsPath;
  private readonly string sessionPath;
  private readonly string expectedProcessName;

  internal PrivacyState(string directory, string expectedProcessName = "life_manager") {
    settingsPath = Path.Combine(directory, "privacy-settings.json");
    sessionPath = Path.Combine(directory, "privacy-session.json");
    this.expectedProcessName = expectedProcessName;
  }

  internal static PrivacyState OpenDefault() => new(AppDataPaths.LifeManagerDirectory);

  internal bool IsLocked() {
    if (!File.Exists(settingsPath)) return false;
    try {
      using var settings = JsonDocument.Parse(File.ReadAllText(settingsPath));
      if (!settings.RootElement.TryGetProperty("enabled", out var enabled)) return true;
      if (enabled.ValueKind == JsonValueKind.False) return false;
      if (enabled.ValueKind != JsonValueKind.True) return true;
      if (!File.Exists(sessionPath)) return true;
      using var session = JsonDocument.Parse(File.ReadAllText(sessionPath));
      var pid = session.RootElement.GetProperty("pid").GetInt32();
      var expiry = session.RootElement.GetProperty("expiresUtc").GetDateTimeOffset();
      if (expiry <= DateTimeOffset.UtcNow ||
          expiry > DateTimeOffset.UtcNow.AddSeconds(6)) return true;
      using var process = Process.GetProcessById(pid);
      return process.HasExited ||
        !string.Equals(process.ProcessName, expectedProcessName,
          StringComparison.OrdinalIgnoreCase);
    } catch {
      return true;
    }
  }

  internal bool SuppressLockedNotifications() {
    try {
      using var settings = JsonDocument.Parse(File.ReadAllText(settingsPath));
      return !settings.RootElement.TryGetProperty("hideNotifications", out var hide) ||
        hide.ValueKind != JsonValueKind.False;
    } catch {
      return true;
    }
  }

  internal void RequireUnlocked() {
    if (IsLocked()) throw new InvalidOperationException(
      "Life Manager is locked. Open the main app and enter your PIN.");
  }
}
