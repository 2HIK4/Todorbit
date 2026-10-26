// All coordinates and thresholds are native physical screen pixels. No Flutter
// logical units cross this boundary. A retained target gives 6px hysteresis.
internal sealed class WidgetEdgeSnap
{
    internal const int Threshold = 10;
    private (int Source, int Target)? horizontal, vertical;
    internal Rectangle Apply(Rectangle bounds, bool moving, WidgetResizeEdge edges,
        Size minimum, IEnumerable<Rectangle> neighbors)
    {
        var nearby = neighbors.Where(n =>
            n.Right >= bounds.Left - 96 && n.Left <= bounds.Right + 96 &&
            n.Bottom >= bounds.Top - 96 && n.Top <= bounds.Bottom + 96).ToArray();
        var xSources = moving ? new[] { 0, 1 } : edges.HasFlag(WidgetResizeEdge.Left) ? new[] { 0 }
            : edges.HasFlag(WidgetResizeEdge.Right) ? new[] { 1 } : Array.Empty<int>();
        var ySources = moving ? new[] { 0, 1 } : edges.HasFlag(WidgetResizeEdge.Top) ? new[] { 0 }
            : edges.HasFlag(WidgetResizeEdge.Bottom) ? new[] { 1 } : Array.Empty<int>();
        var x = Resolve([bounds.Left, bounds.Right], xSources, nearby.SelectMany(n => new[] { n.Left, n.Right }).ToArray(), ref horizontal);
        var y = Resolve([bounds.Top, bounds.Bottom], ySources, nearby.SelectMany(n => new[] { n.Top, n.Bottom }).ToArray(), ref vertical);
        var left = bounds.Left; var right = bounds.Right;
        var top = bounds.Top; var bottom = bounds.Bottom;
        if (x is { } sx)
        {
            var delta = sx.Target - (sx.Source == 0 ? left : right);
            if (moving) { left += delta; right += delta; }
            else if (sx.Source == 0) left += delta; else right += delta;
            if (right - left < minimum.Width) { left = bounds.Left; right = bounds.Right; horizontal = null; }
        }
        if (y is { } sy)
        {
            var delta = sy.Target - (sy.Source == 0 ? top : bottom);
            if (moving) { top += delta; bottom += delta; }
            else if (sy.Source == 0) top += delta; else bottom += delta;
            if (bottom - top < minimum.Height) { top = bounds.Top; bottom = bounds.Bottom; vertical = null; }
        }
        return Rectangle.FromLTRB(left, top, right, bottom);
    }

    private static (int Source, int Target)? Resolve(int[] coordinates, int[] sources,
        int[] targets, ref (int Source, int Target)? retained)
    {
        if (retained is { } old && sources.Contains(old.Source) && targets.Contains(old.Target) &&
            Math.Abs(coordinates[old.Source] - old.Target) <= Threshold + 6) return old;
        retained = null;
        var best = Threshold + 1;
        foreach (var source in sources)
        foreach (var target in targets)
        {
            var distance = Math.Abs(coordinates[source] - target);
            if (distance < best) { best = distance; retained = (source, target); }
        }
        return retained;
    }
}
