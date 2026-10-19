using System.Text.Json;

internal static class AppDataPaths {
  // Flutter resolves APPDATA from the process environment. The native
  // companion must do the same so disposable profiles cannot touch real data.
  internal static string RoamingRoot {
    get {
      var value = Environment.GetEnvironmentVariable("APPDATA");
      if (string.IsNullOrWhiteSpace(value) || !Path.IsPathFullyQualified(value)) {
        throw new InvalidOperationException("APPDATA must be an absolute directory path.");
      }
      return Path.GetFullPath(value);
    }
  }

  internal static string TodoPilotDirectory => Path.Combine(RoamingRoot, "TodoPilot");
  internal static string LegacyDirectory => Path.Combine(RoamingRoot, "Life Manager");
  internal static string ActiveDirectory {
    get {
      var marker = Path.Combine(TodoPilotDirectory, "legacy-profile.json");
      if (!File.Exists(marker) ||
          !File.Exists(Path.Combine(LegacyDirectory, "life_manager.sqlite"))) {
        return TodoPilotDirectory;
      }
      try {
        using var document = JsonDocument.Parse(File.ReadAllText(marker));
        return document.RootElement.TryGetProperty("profile", out var profile) &&
            profile.GetString() == "todopilot-upgrade-v1"
          ? LegacyDirectory : TodoPilotDirectory;
      } catch (Exception error) when (error is IOException or JsonException or
          UnauthorizedAccessException or InvalidOperationException) {
        return TodoPilotDirectory;
      }
    }
  }
}
