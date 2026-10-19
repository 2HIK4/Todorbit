using System.Diagnostics;

var repository = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory,
  "..", "..", "..", "..", ".."));
var application = Path.Combine(repository, "build", "windows", "x64",
  "runner", "Release", "TodoPilot.exe");
if (!File.Exists(application)) throw new FileNotFoundException(application);
var profile = Path.Combine(Path.GetTempPath(),
  "TodoPilot isolated GUI " + Guid.NewGuid().ToString("N"));
var roaming = Path.Combine(profile, "Roaming");
var local = Path.Combine(profile, "Local");
Directory.CreateDirectory(roaming);
Directory.CreateDirectory(local);
var start = new ProcessStartInfo(application) { UseShellExecute = false };
start.Environment["APPDATA"] = roaming;
start.Environment["LOCALAPPDATA"] = local;
start.Environment["TODOPILOT_ISOLATED_PROFILE"] = profile;
Process.Start(start);
