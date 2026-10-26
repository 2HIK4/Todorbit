using System.Text.Json;

internal static partial class LifeManagerWidgetSelfTest
{
    private static void TestWidgetPreview()
    {
        var now = DateTime.UtcNow;
        var session = Guid.NewGuid().ToString();
        var options = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
        var baseline = JsonSerializer.Serialize(new WidgetConfiguration { Enabled = true }, options);
        var draft = JsonSerializer.Serialize(new WidgetConfiguration { Enabled = false, ShowTitle = false, TextScale = 1.4f }, options);
        JsonElement Message(long sequence, bool end = false, string? id = null) => JsonSerializer.SerializeToElement(new {
            session = id ?? session, sequence, end,
            baseline = JsonSerializer.Deserialize<JsonElement>(baseline),
            configuration = JsonSerializer.Deserialize<JsonElement>(draft),
        });
        var lease = new WidgetPreviewLease();
        Require(lease.Accept(Message(1), now), "Preview accepts a new session");
        var saved = WidgetConfiguration.Parse(baseline);
        var displayed = lease.Resolve(saved);
        Require(!displayed.ShowTitle && displayed.TextScale == 1.4f && displayed.Enabled,
            "Preview renders draft but preserves independent visibility");
        Require(saved.ShowTitle && saved.TextScale == 1, "Preview never mutates saved settings");
        Require(!lease.Accept(Message(0), now), "Out-of-order preview is ignored");
        Require(!lease.Accept(Message(2, id: Guid.NewGuid().ToString()), now), "Active editor is not replaced by another session");
        saved.ShowOpenButton = false;
        Require(!lease.Resolve(saved).ShowOpenButton, "Concurrent menu setting survives preview");
        saved.TextScale = 1.2f;
        Require(lease.Resolve(saved).TextScale == 1.2f, "Concurrent same-property edit wins");
        Require(lease.Accept(Message(2, true), now), "Rollback ends current lease");
        Require(lease.Resolve(saved).ShowTitle, "Rollback restores latest saved configuration");
        Require(!lease.Accept(Message(3), now), "Ended session cannot be revived by delayed preview");
        var nextSession = Guid.NewGuid().ToString();
        Require(lease.Accept(Message(1, id: nextSession), now), "Next editor starts independently");
        Require(!lease.Expire(now.AddSeconds(7)) && lease.Expire(now.AddSeconds(9)),
            "Lost app restores committed settings after bounded lease");
        Require(!lease.Active, "Expired preview is inactive");
        Require(lease.Accept(Message(2, id: nextSession), now.AddSeconds(10)),
            "Still-open editor can resume preview after a temporary connection loss");
    }
}
