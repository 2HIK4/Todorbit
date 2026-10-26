internal static class WidgetEdgeSnapSelfTest
{
    internal static void Run()
    {
        void Require(bool value, string message) { if (!value) throw new InvalidOperationException(message); }
        var neighbor = new Rectangle(100, 50, 400, 250);
        var snap = new WidgetEdgeSnap();
        var bounds = snap.Apply(new Rectangle(100, 310, 393, 400), false, WidgetResizeEdge.Right, new Size(260, 230), [neighbor]);
        Require(bounds.Right == 500 && bounds.Left == 100 && bounds.Top == 310, "Resize failed to match stacked widths.");
        bounds = snap.Apply(new Rectangle(100, 310, 386, 400), false, WidgetResizeEdge.Right, new Size(260, 230), [neighbor]);
        Require(bounds.Right == 500, "Snap hysteresis released too early.");
        bounds = snap.Apply(new Rectangle(100, 310, 380, 400), false, WidgetResizeEdge.Right, new Size(260, 230), [neighbor]);
        Require(bounds.Right == 480, "Resize did not release outside hysteresis.");
        foreach (var scale in new[] { 1f, 1.25f, 1.5f, 2f })
        {
            var minimum = WidgetGeometry.Scale(new Size(260, 230), scale);
            var other = new Rectangle(-1000, -800, minimum.Width + 100, minimum.Height);
            var candidate = new Rectangle(-1000, other.Bottom + 10, other.Width - 7, minimum.Height);
            var result = new WidgetEdgeSnap().Apply(candidate, false, WidgetResizeEdge.Right, minimum, [other]);
            Require(result.Right == other.Right, "Physical-pixel alignment failed across DPI/negative screen coordinates.");
            var settings = new WidgetSettings { PhysicalWidth = 601, PhysicalHeight = 701,
                Width = (int)Math.Round(601/scale), Height = (int)Math.Round(701/scale), BoundsDpi = (int)(96*scale) };
            var restored = WidgetGeometry.RestoreSize(settings, new Size(settings.Width,settings.Height), scale);
            Require(restored == new Size(601,701), "Restart lost exact physical snapped bounds.");
            Require(WidgetGeometry.RestoreSize(settings, new Size(settings.Width,settings.Height), scale+1) ==
                WidgetGeometry.Scale(new Size(settings.Width,settings.Height),scale+1), "Different DPI reused stale physical dimensions.");
        }
        var far = new Rectangle(100, -2000, 400, 200);
        Require(new WidgetEdgeSnap().Apply(new Rectangle(100, 310, 393, 400), false, WidgetResizeEdge.Right, new Size(260,230), [far]).Right == 493, "Unrelated widget affected snapping.");
        var narrow = new Rectangle(0, 0, 255, 200);
        Require(new WidgetEdgeSnap().Apply(new Rectangle(0, 210, 260, 230), false, WidgetResizeEdge.Right, new Size(260,230), [narrow]).Width == 260, "Snap violated minimum size.");
        var moved = new WidgetEdgeSnap().Apply(new Rectangle(107, 310, 300, 400), true, WidgetResizeEdge.None, new Size(260,230), [neighbor]);
        Require(moved.Left == 100 && moved.Width == 300 && neighbor == new Rectangle(100,50,400,250), "Movement snap changed size or its neighbor.");
        var side = new Rectangle(510, 55, 400, 245);
        var corner = new WidgetEdgeSnap().Apply(side, false, WidgetResizeEdge.Top | WidgetResizeEdge.Bottom, new Size(260,230), [neighbor]);
        Require(corner.Top == 50 && corner.Bottom == 300, "Top/bottom corner alignment failed.");
    }
}
