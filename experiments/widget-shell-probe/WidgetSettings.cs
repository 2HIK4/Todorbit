using System.Text.Json;
using System.Text.Json.Serialization;

internal enum WidgetThemePreference { System, Light, Dark }
internal enum WidgetTaskView { Today, Inbox, All, Upcoming }

internal sealed class WidgetSettings {
  public int X { get; set; } = int.MinValue;
  public int Y { get; set; } = int.MinValue;
  public int Width { get; set; } = 376;
  public int Height { get; set; } = 460;
  public string? MonitorDeviceName { get; set; }
  // Retained only to migrate releases that stored appearance in this file.
  public WidgetThemePreference? Theme { get; set; }
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
    Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
  };
}

internal sealed class AppearanceSettings {
  public WidgetThemePreference Theme { get; set; } = WidgetThemePreference.System;
}

internal sealed class AppearanceSettingsStore {
  internal string Path { get; }

  internal AppearanceSettingsStore(string? overridePath = null) {
    Path = overridePath ?? System.IO.Path.Combine(
      Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
      "Life Manager", "appearance-settings.json");
  }

  internal AppearanceSettings Load(WidgetThemePreference? legacyTheme = null) {
    if (!File.Exists(Path)) {
      var migrated = new AppearanceSettings {
        Theme = legacyTheme ?? WidgetThemePreference.System,
      };
      Save(migrated);
      return migrated;
    }
    try {
      return JsonSerializer.Deserialize<AppearanceSettings>(
        File.ReadAllText(Path), JsonOptions) ?? new AppearanceSettings();
    } catch (JsonException) {
      return new AppearanceSettings();
    }
  }

  internal void Save(AppearanceSettings settings) {
    var directory = System.IO.Path.GetDirectoryName(Path)!;
    Directory.CreateDirectory(directory);
    var temporary = Path + ".tmp";
    File.WriteAllText(temporary, JsonSerializer.Serialize(settings, JsonOptions));
    File.Move(temporary, Path, overwrite: true);
  }

  private static JsonSerializerOptions JsonOptions { get; } = new() {
    WriteIndented = true,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    PropertyNameCaseInsensitive = true,
    Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
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

[Flags]
internal enum WidgetResizeEdge {
  None = 0,
  Left = 1,
  Top = 2,
  Right = 4,
  Bottom = 8,
}

internal static class WidgetGeometry {
  internal static WidgetResizeEdge ResizeEdgeAt(
      float x, float y, float width, float height, float margin = 7) {
    var edge = WidgetResizeEdge.None;
    if (x <= margin) edge |= WidgetResizeEdge.Left;
    else if (x >= width - margin) edge |= WidgetResizeEdge.Right;
    if (y <= margin) edge |= WidgetResizeEdge.Top;
    else if (y >= height - margin) edge |= WidgetResizeEdge.Bottom;
    return edge;
  }

  internal static Size LogicalSize(int width, int height) => new(
    Math.Clamp(width, 340, 720), Math.Clamp(height, 420, 900));

  internal static Rectangle ClampToWorkingArea(
      Rectangle bounds, Rectangle workingArea) {
    var width = Math.Min(bounds.Width, workingArea.Width);
    var height = Math.Min(bounds.Height, workingArea.Height);
    var x = Math.Clamp(bounds.X, workingArea.Left,
      Math.Max(workingArea.Left, workingArea.Right - width));
    var y = Math.Clamp(bounds.Y, workingArea.Top,
      Math.Max(workingArea.Top, workingArea.Bottom - height));
    return new Rectangle(x, y, width, height);
  }

  internal static Size Scale(Size logical, float dpiScale) => new(
    (int)Math.Round(logical.Width * dpiScale),
    (int)Math.Round(logical.Height * dpiScale));
}
