using Microsoft.Win32;

internal static class StartupRegistration {
  private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
  private const string LegacyValueName = "Life Manager Widget";
  private const string ValuePrefix = "Todorbit Widget ";
  private static string ValueName => ValuePrefix + AppDataPaths.ChannelSuffix;

  private static string Command() {
    var executable = Environment.ProcessPath ??
      throw new InvalidOperationException("The widget executable path is unavailable.");
    return $"\"{Path.GetFullPath(executable)}\" --widget";
  }

  internal static bool IsEnabled(string? keyPath = null) {
    using var key = Registry.CurrentUser.OpenSubKey(keyPath ?? RunKey, writable: false);
    return key?.GetValue(ValueName) is string value &&
      string.Equals(value, Command(), StringComparison.OrdinalIgnoreCase);
  }

  internal static void SetEnabled(bool enabled, string? keyPath = null) {
    using var key = Registry.CurrentUser.CreateSubKey(keyPath ?? RunKey, writable: true);
    if (key == null) throw new InvalidOperationException("Windows startup settings are unavailable.");
    // Migrate the old global entry only when it belongs to this copy or its
    // executable has gone away. Another installed copy may still use it.
    if (key.GetValue(LegacyValueName) is string legacy) {
      var legacyPath = legacy.StartsWith('"') ? legacy.Split('"').ElementAtOrDefault(1) : null;
      if (string.Equals(legacyPath, Environment.ProcessPath,
          StringComparison.OrdinalIgnoreCase) ||
          (legacyPath != null && !File.Exists(legacyPath))) {
        key.DeleteValue(LegacyValueName, throwOnMissingValue: false);
      }
    }
    foreach (var name in key.GetValueNames()) {
      if (!name.StartsWith(ValuePrefix, StringComparison.OrdinalIgnoreCase) ||
          name == ValueName || key.GetValue(name) is not string command) continue;
      var quoted = command.StartsWith('"') ? command.Split('"').ElementAtOrDefault(1) : null;
      if (quoted != null && !File.Exists(quoted)) {
        key.DeleteValue(name, throwOnMissingValue: false);
      }
    }
    if (enabled) {
      key.SetValue(ValueName, Command(), RegistryValueKind.String);
    } else {
      key.DeleteValue(ValueName, throwOnMissingValue: false);
    }
  }
}
