using System.Text.Json;
using System.Text.Json.Nodes;

// Transient, ordered, leased state. Nothing in this protocol writes preferences.
internal sealed class WidgetPreviewLease
{
    internal string? Session { get; private set; }
    internal long Sequence { get; private set; } = -1;
    internal DateTime Expires { get; private set; }
    internal bool Active { get; private set; }
    private bool explicitlyEnded;
    internal string Baseline { get; private set; } = "{}";
    internal string Draft { get; private set; } = "{}";

    internal bool Accept(JsonElement message, DateTime now)
    {
        var session = message.GetProperty("session").GetString();
        var sequence = message.GetProperty("sequence").GetInt64();
        if (!Guid.TryParse(session, out _) || sequence < 0) return false;
        if (Session == session && sequence <= Sequence) return false;
        if (Session != session && Active && now < Expires) return false;
        var end = message.TryGetProperty("end", out var ending) && ending.GetBoolean();
        // Cancel is terminal. A timed-out connection can recover with a newer
        // heartbeat from the still-open editor, while old sequence numbers fail.
        if (Session == session && explicitlyEnded) return false;
        if (!end)
        {
            var baseline = message.GetProperty("baseline").GetRawText();
            var draft = message.GetProperty("configuration").GetRawText();
            _ = WidgetConfiguration.Parse(baseline);
            _ = WidgetConfiguration.Parse(draft);
            Baseline = baseline; Draft = draft;
        }
        Session = session; Sequence = sequence;
        explicitlyEnded = end;
        Active = !end; Expires = now.AddSeconds(8);
        return true;
    }

    internal bool Expire(DateTime now)
    {
        if (!Active || now < Expires) return false;
        Active = false;
        return true;
    }

    internal WidgetConfiguration Resolve(WidgetConfiguration saved)
    {
        if (!Active) return saved;
        var current = JsonSerializer.SerializeToNode(saved, Options)!;
        var result = Merge(JsonNode.Parse(Baseline), JsonNode.Parse(Draft), current)!;
        result["enabled"] = saved.Enabled;
        return WidgetConfiguration.Parse(result.ToJsonString());
    }

    private static JsonNode? Merge(JsonNode? baseline, JsonNode? draft, JsonNode? current)
    {
        if (baseline is JsonObject b && draft is JsonObject d && current is JsonObject c)
        {
            var result = new JsonObject();
            foreach (var entry in c) result[entry.Key] = Merge(b[entry.Key], d[entry.Key], entry.Value);
            return result;
        }
        return (JsonNode.DeepEquals(current, baseline) ? draft : current)?.DeepClone();
    }
    private static readonly JsonSerializerOptions Options = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
}

internal sealed partial class NativeDesktopWidgetHost
{
    private readonly WidgetPreviewLease previewLease = new();

    internal void ApplyPreview(JsonElement message)
    {
        var previousBaseline = previewLease.Baseline;
        var previousDraft = previewLease.Draft;
        var wasActive = previewLease.Active;
        if (!previewLease.Accept(message, DateTime.UtcNow)) return;
        if (wasActive && previewLease.Active && previousBaseline == previewLease.Baseline &&
            previousDraft == previewLease.Draft) return; // Heartbeat only, no repaint or disk read.
        RestorePreviewIfActive();
        EnsurePreviewMinimumSize();
        // Resizing to minimum constraints uses the current bounds, never saved position.
        Present("configuration-preview");
    }

    private void RestorePreviewIfActive()
    {
        configuration = previewLease.Resolve(WidgetConfiguration.Load(calendar, settings));
    }

    internal void ExpirePreview()
    {
        if (!previewLease.Expire(DateTime.UtcNow)) return;
        configuration = WidgetConfiguration.Load(calendar, settings);
        Present("configuration-preview-expired");
    }
}

internal sealed partial class NativeWidgetApplicationContext
{
    private bool TryHandlePreviewCommand(string command)
    {
        const string prefix = "preview-configuration ";
        if (!command.StartsWith(prefix, StringComparison.Ordinal)) return false;
        try
        {
            if (command.Length > 65536) return true;
            using var document = JsonDocument.Parse(command[prefix.Length..]);
            var message = document.RootElement;
            var kind = message.GetProperty("kind").GetString();
            if (kind == "tasks") host?.ApplyPreview(message);
            else if (kind == "calendar") calendarHost?.ApplyPreview(message);
        }
        catch (Exception error) when (error is JsonException or InvalidOperationException or
            KeyNotFoundException or FormatException or InvalidDataException or IOException)
        {
            System.Diagnostics.Debug.WriteLine($"Widget preview rejected: {error.Message}");
        }
        return true;
    }

    private void ExpireWidgetPreviews()
    {
        host?.ExpirePreview(); calendarHost?.ExpirePreview();
    }
}
