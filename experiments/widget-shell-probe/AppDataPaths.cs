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

  internal static string LifeManagerDirectory => Path.Combine(RoamingRoot, "Life Manager");
}
