using System.Text.Json;

internal enum WidgetThemePreference { System, Light, Dark }
internal enum WidgetTaskView { Today, Inbox }

internal sealed class WidgetSettings {
  public int X { get; set; } = int.MinValue;
  public int Y { get; set; } = int.MinValue;
  public int Width { get; set; } = 376;
  public int Height { get; set; } = 460;
  public string? MonitorDeviceName { get; set; }
  public WidgetThemePreference Theme { get; set; } = WidgetThemePreference.System;
  public WidgetTaskView View { get; set; } = WidgetTaskView.Today;
  public bool LaunchAtSignIn { get; set; }
}

internal sealed class WidgetSettingsStore {
  private readonly string path;

  internal WidgetSettingsStore(string? overridePath = null) {
    path = overridePath ?? Path.Combine(
      Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
      "Life Manager", "widget-settings.json");
  }

  internal WidgetSettings Load() {
    if (!File.Exists(path)) return new WidgetSettings();
    try {
      return JsonSerializer.Deserialize<WidgetSettings>(File.ReadAllText(path),
        JsonOptions) ?? new WidgetSettings();
    } catch (JsonException) {
      return new WidgetSettings();
    }
  }

  internal void Save(WidgetSettings settings) {
    var directory = Path.GetDirectoryName(path)!;
    Directory.CreateDirectory(directory);
    var temporary = path + ".tmp";
    File.WriteAllText(temporary, JsonSerializer.Serialize(settings, JsonOptions));
    File.Move(temporary, path, overwrite: true);
  }

  private static JsonSerializerOptions JsonOptions { get; } = new() {
    WriteIndented = true,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    PropertyNameCaseInsensitive = true,
  };
}

internal sealed class ExplorerRecoveryPolicy {
  private readonly int maximumAttempts;
  internal int Attempts { get; private set; }
  internal bool CanRetry => Attempts < maximumAttempts;

  internal ExplorerRecoveryPolicy(int maximumAttempts = 30) {
    if (maximumAttempts < 1) throw new ArgumentOutOfRangeException(nameof(maximumAttempts));
    this.maximumAttempts = maximumAttempts;
  }

  internal void RecordFailure() => Attempts++;
  internal void Reset() => Attempts = 0;
}
