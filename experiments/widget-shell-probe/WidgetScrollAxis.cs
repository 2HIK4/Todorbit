internal sealed class WidgetScrollAxis {
  internal float Pixels;
  internal float TargetPixels;
  internal bool IsAnimating => Math.Abs(TargetPixels - Pixels) > 0.01f;

  internal static float MaxFor(float viewportHeight, float contentHeight) =>
    Math.Max(0f, contentHeight - Math.Max(0f, viewportHeight));

  internal void Clamp(float viewportHeight, float contentHeight) {
    var max = MaxFor(viewportHeight, contentHeight);
    Pixels = Math.Clamp(Pixels, 0f, max);
    TargetPixels = Math.Clamp(TargetPixels, 0f, max);
  }

  internal void Reset() {
    Pixels = 0f;
    TargetPixels = 0f;
  }

  internal bool JumpToFraction(float fraction, float viewportHeight, float contentHeight) {
    var max = MaxFor(viewportHeight, contentHeight);
    if (max <= 0f) return false;
    var next = Math.Clamp(fraction, 0f, 1f) * max;
    if (Math.Abs(Pixels - next) < 0.01f && Math.Abs(TargetPixels - next) < 0.01f) return false;
    Pixels = TargetPixels = next;
    return true;
  }

  internal void AddDelta(float deltaPixels, float max, bool animate, out bool changed, out bool startTimer) {
    changed = false;
    startTimer = false;
    if (max <= 0f) return;
    var next = Math.Clamp(TargetPixels + deltaPixels, 0f, max);
    if (Math.Abs(next - TargetPixels) < 0.01f && Math.Abs(Pixels - next) < 0.01f) return;
    TargetPixels = next;
    if (!animate) {
      Pixels = TargetPixels;
      changed = true;
    } else {
      startTimer = true;
    }
  }

  internal bool Step(out bool settled) {
    var diff = TargetPixels - Pixels;
    if (Math.Abs(diff) <= 0.5f) {
      Pixels = TargetPixels;
      settled = true;
      return true;
    }
    Pixels += diff * 0.35f;
    settled = false;
    return true;
  }

  internal bool EnsureItemVisible(float itemTop, float itemBottom, float viewportTop, float viewportBottom, float max) {
    var delta = 0f;
    if (itemTop < viewportTop) delta = itemTop - viewportTop;
    else if (itemBottom > viewportBottom) delta = itemBottom - viewportBottom;
    if (Math.Abs(delta) < 0.5f) return false;
    Pixels = TargetPixels = Math.Clamp(Pixels + delta, 0f, max);
    return true;
  }

  internal RectangleF ThumbRect(float viewportHeight, float contentHeight, RectangleF track) {
    var max = MaxFor(viewportHeight, contentHeight);
    var safeViewport = Math.Max(1f, viewportHeight);
    var total = Math.Max(safeViewport, contentHeight);
    var thumbHeight = Math.Max(14f, track.Height * (safeViewport / total));
    var progress = max <= 0.001f ? 0f : Math.Clamp(Pixels / max, 0f, 1f);
    var top = track.Top + (track.Height - thumbHeight) * progress;
    return new RectangleF(track.X, top, track.Width, thumbHeight);
  }
}
