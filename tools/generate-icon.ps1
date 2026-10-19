param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

# Rasterize the Lucide-derived orbit geometry in assets/todopilot_icon.svg.
# Draw each ICO resolution independently to keep small Windows icons legible.
Add-Type -AssemblyName System.Drawing
$sizes = @(16, 24, 32, 48, 64, 128, 256)
$images = [System.Collections.Generic.List[byte[]]]::new()
foreach ($size in $sizes) {
  $bitmap = [System.Drawing.Bitmap]::new($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $scale = $size / 256.0
  $graphics.ScaleTransform($scale, $scale)
  $rect = [System.Drawing.RectangleF]::new(0, 0, 256, 256)
  $round = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $round.AddArc(0, 0, 84, 84, 180, 90)
  $round.AddArc(172, 0, 84, 84, 270, 90)
  $round.AddArc(172, 172, 84, 84, 0, 90)
  $round.AddArc(0, 172, 84, 84, 90, 90)
  $round.CloseFigure()
  $tile = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(5,5,5))
  $graphics.FillPath($tile, $round)
  $glyphScale = 190.0 / 24.0
  $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 2 * $glyphScale)
  $pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $orbitX = 33 + 2 * $glyphScale
  $orbitY = 33 + 2 * $glyphScale
  $orbitDiameter = 20 * $glyphScale
  $graphics.DrawArc($pen, [float]$orbitX, [float]$orbitY,
    [float]$orbitDiameter, [float]$orbitDiameter, -33.5, 133.5)
  $graphics.DrawArc($pen, [float]$orbitX, [float]$orbitY,
    [float]$orbitDiameter, [float]$orbitDiameter, 146.5, 134.2)
  foreach ($circle in @(@(12,12,3), @(19,5,2), @(5,19,2))) {
    $cx, $cy, $radius = $circle
    $graphics.DrawEllipse($pen,
      [float](33 + ($cx - $radius) * $glyphScale),
      [float](33 + ($cy - $radius) * $glyphScale),
      [float](2 * $radius * $glyphScale),
      [float](2 * $radius * $glyphScale))
  }
  $stream = [System.IO.MemoryStream]::new()
  $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $images.Add($stream.ToArray())
  if ($size -eq 256) {
    [System.IO.File]::WriteAllBytes((Join-Path $Root 'assets/app_icon.png'), $stream.ToArray())
  }
  $stream.Dispose(); $pen.Dispose(); $tile.Dispose()
  $round.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$icoPath = Join-Path $Root 'windows/runner/resources/app_icon.ico'
$stream = [System.IO.File]::Create($icoPath)
$writer = [System.IO.BinaryWriter]::new($stream)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $sizeByte = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
  $writer.Write([byte]$sizeByte); $writer.Write([byte]$sizeByte)
  $writer.Write([byte]0); $writer.Write([byte]0)
  $writer.Write([uint16]1); $writer.Write([uint16]32)
  $writer.Write([uint32]$images[$i].Length)
  $writer.Write([uint32]$offset)
  $offset += $images[$i].Length
}
foreach ($bytes in $images) { $writer.Write($bytes) }
$writer.Dispose()
