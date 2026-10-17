using Microsoft.Win32;

internal static class StartupRegistration {
  private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
  private const string ValueName = "Life Manager Widget";

  internal static bool IsEnabled() {
    using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: false);
    return key?.GetValue(ValueName) is string value && value.Length > 0;
  }

  internal static void SetEnabled(bool enabled) {
    using var key = Registry.CurrentUser.CreateSubKey(RunKey, writable: true);
    if (enabled) {
      var executable = Environment.ProcessPath ??
        throw new InvalidOperationException("The widget executable path is unavailable.");
      key.SetValue(ValueName, $"\"{executable}\" --widget", RegistryValueKind.String);
    } else {
      key.DeleteValue(ValueName, throwOnMissingValue: false);
    }
  }
}
