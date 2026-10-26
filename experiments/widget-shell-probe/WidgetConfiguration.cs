using System.Text.Json;
using System.Text.Json.Serialization;

internal sealed class WidgetSurface
{
    public string? Color { get; set; }
    public string? TextColor { get; set; }
    public string? PlaceholderColor { get; set; }
    public int Opacity { get; set; } = 100;
    public bool Border { get; set; }
    public string? BorderColor { get; set; }
    public int BorderOpacity { get; set; } = 100;
    public float Thickness { get; set; } = 1;
    public float Radius { get; set; } = 8;
    internal System.Drawing.Color Resolve(System.Drawing.Color fallback, bool outline = false)
    {
        var hex = outline ? BorderColor : Color;
        var color = hex != null && System.Text.RegularExpressions.Regex.IsMatch(hex, "^#[0-9a-fA-F]{6}$")
          ? ColorTranslator.FromHtml(hex) : fallback;
        return System.Drawing.Color.FromArgb((int)Math.Round(
          Math.Clamp(outline ? BorderOpacity : Opacity, 0, 100) * 2.55), color);
    }
}

internal sealed class WidgetConfiguration
{
    public int Version { get; set; } = 1;
    public bool Enabled { get; set; }
    public bool ShowTitle { get; set; } = true;
    public bool ShowOpenButton { get; set; } = true;
    public bool LayoutLocked { get; set; }
    public bool ProtectText { get; set; } = true;
    public string NavigationPosition { get; set; } = "top";
    public string NavigationDisplay { get; set; } = "text";
    public string CalendarPresentation { get; set; } = "compactAgenda";
    public float TextScale { get; set; } = 1;
    public List<string> Views { get; set; } = ["today", "inbox", "all", "upcoming"];
    public Dictionary<string, WidgetSurface> Surfaces { get; set; } = new()
    {
        ["shell"] = new() { Border = true, Radius = 12 },
        ["content"] = new(),
        ["input"] = new() { Border = true, Radius = 7 },
        ["header"] = new() { Opacity = 0 },
        ["navigation"] = new() { Opacity = 0 },
        ["navigationButton"] = new() { Radius = 6 },
        ["calendarCell"] = new() { Opacity = 0, Radius = 4 },
        ["agenda"] = new(),
        ["selectedDate"] = new() { Radius = 4 },
        ["today"] = new() { Opacity = 0, Border = true, Thickness = 2, Radius = 4 },
    };
    internal bool HasHeader => ShowTitle || ShowOpenButton;
    internal WidgetSurface Surface(string name)
    {
        if (Surfaces.TryGetValue(name, out var surface)) return surface;
        surface = new WidgetConfiguration().Surfaces.GetValueOrDefault(name) ?? new WidgetSurface();
        Surfaces[name] = surface;
        return surface;
    }
    internal static string PathFor(bool calendar) => Path.Combine(AppDataPaths.ActiveDirectory,
      $"widget-{(calendar ? "calendar" : "tasks")}-configuration.json");
    internal static WidgetConfiguration Load(bool calendar, WidgetSettings legacy)
    {
        var path = PathFor(calendar);
        if (!File.Exists(path))
        {
            var migrated = new WidgetConfiguration { Enabled = !calendar, LayoutLocked = legacy.LayoutLocked };
            migrated.Surfaces["shell"].Opacity = legacy.BackgroundOpacity;
            var appearanceStore = new AppearanceSettingsStore();
            if (!calendar && File.Exists(appearanceStore.Path)) { var appearance = appearanceStore.Load(); migrated.Surfaces["shell"].Opacity = appearance.WidgetOpacity ?? appearance.Customization?.WidgetOpacity ?? legacy.BackgroundOpacity; }
            return migrated;
        }
        if (new FileInfo(path).Length > 65536) throw new InvalidDataException("Widget configuration exceeds 64 KiB; original file preserved.");
        return Parse(File.ReadAllText(path));
    }
    internal static WidgetConfiguration Parse(string json)
    {
        if (System.Text.Encoding.UTF8.GetByteCount(json) > 65536) throw new InvalidDataException("Widget configuration exceeds 64 KiB.");
        var config = JsonSerializer.Deserialize<WidgetConfiguration>(json, Options)
          ?? throw new InvalidDataException("Invalid widget configuration; original file preserved.");
        if (config.Version != 1) throw new InvalidDataException("Unsupported widget configuration version.");
        config.TextScale = float.IsFinite(config.TextScale) ? Math.Clamp(config.TextScale, 1, 1.6f) : 1;
        config.Views ??= [];
        config.Surfaces ??= new WidgetConfiguration().Surfaces;
        foreach (var surface in config.Surfaces.Values)
        {
            if (surface == null) throw new InvalidDataException("Invalid widget surface; original file preserved.");
            surface.Opacity = Math.Clamp(surface.Opacity, 0, 100); surface.BorderOpacity = Math.Clamp(surface.BorderOpacity, 0, 100);
            surface.Thickness = float.IsFinite(surface.Thickness) ? Math.Clamp(surface.Thickness, 0, 8) : 1;
            surface.Radius = float.IsFinite(surface.Radius) ? Math.Clamp(surface.Radius, 0, 32) : 8;
        }
        config.NavigationPosition = config.NavigationPosition is "top" or "left" or "right" or "bottom" ? config.NavigationPosition : "top";
        config.NavigationDisplay = config.NavigationDisplay is "text" or "icons" or "both" ? config.NavigationDisplay : "text";
        config.CalendarPresentation = config.CalendarPresentation == "fullMonth" ? "fullMonth" : "compactAgenda";
        config.Views = config.Views.Where(v => v is "today" or "inbox" or "all" or "upcoming").Distinct().ToList();
        return config;
    }
    internal static void Update(bool calendar, WidgetSettings legacy, Action<WidgetConfiguration> change)
    {
        var config = Load(calendar, legacy); change(config); config.Save(calendar);
    }
    internal void Save(bool calendar)
    {
        var path = PathFor(calendar);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + "." + Environment.ProcessId + "-" + Guid.NewGuid() + ".tmp";
        try { File.WriteAllText(temporary, JsonSerializer.Serialize(this, Options)); File.Move(temporary, path, true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        NumberHandling = JsonNumberHandling.Strict,
    };
}
