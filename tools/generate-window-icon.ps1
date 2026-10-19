param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

# Draw Lucide's orbit geometry independently at Windows window-icon sizes.
# The primary app_icon.ico remains the first executable icon resource.
Add-Type -AssemblyName System.Drawing
$sizes = @(16, 20, 24, 32, 48, 64)
$images = [System.Collections.Generic.List[byte[]]]::new()
foreach ($size in $sizes) {
  $bitmap = [System.Drawing.Bitmap]::new($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.ScaleTransform($size / 24.0, $size / 24.0)
  foreach ($layer in @(@('#050505', 3.5), @('#FFFFFF', 2.0))) {
    $pen = [System.Drawing.Pen]::new(
      [System.Drawing.ColorTranslator]::FromHtml($layer[0]), [float]$layer[1])
    $pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $graphics.DrawArc($pen, 2, 2, 20, 20, -33.5, 133.5)
    $graphics.DrawArc($pen, 2, 2, 20, 20, 146.5, 134.2)
    foreach ($circle in @(@(12,12,3), @(19,5,2), @(5,19,2))) {
      $cx, $cy, $radius = $circle
      $graphics.DrawEllipse($pen, [float]($cx - $radius),
        [float]($cy - $radius), [float](2 * $radius), [float](2 * $radius))
    }
    $pen.Dispose()
  }
  $stream = [System.IO.MemoryStream]::new()
  $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $images.Add($stream.ToArray())
  $stream.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$icoPath = Join-Path $Root 'windows/runner/resources/window_icon.ico'
$stream = [System.IO.File]::Create($icoPath)
$writer = [System.IO.BinaryWriter]::new($stream)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $writer.Write([byte]$sizes[$i]); $writer.Write([byte]$sizes[$i])
  $writer.Write([byte]0); $writer.Write([byte]0)
  $writer.Write([uint16]1); $writer.Write([uint16]32)
  $writer.Write([uint32]$images[$i].Length)
  $writer.Write([uint32]$offset)
  $offset += $images[$i].Length
}
foreach ($bytes in $images) { $writer.Write($bytes) }
$writer.Dispose()
