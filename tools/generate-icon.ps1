$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pngPath = Join-Path $root 'assets\app_icon.png'
$icoPath = Join-Path $root 'windows\runner\resources\app_icon.ico'
New-Item -ItemType Directory -Path (Split-Path $pngPath) -Force | Out-Null

$sizes = @(16, 32, 48, 64, 128, 256)
$frames = [System.Collections.Generic.List[byte[]]]::new()
foreach ($size in $sizes) {
  $bitmap = [System.Drawing.Bitmap]::new($size, $size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $scale = $size / 256.0
  $graphics.ScaleTransform($scale, $scale)

  $back = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 55, 71, 139))
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $path.AddArc(8, 8, 64, 64, 180, 90)
  $path.AddArc(184, 8, 64, 64, 270, 90)
  $path.AddArc(184, 184, 64, 64, 0, 90)
  $path.AddArc(8, 184, 64, 64, 90, 90)
  $path.CloseFigure()
  $graphics.FillPath($back, $path)

  $white = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 20)
  $white.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $white.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $white.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $graphics.DrawLine($white, 70, 64, 70, 192)
  $graphics.DrawLine($white, 70, 192, 178, 192)
  $accent = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 192, 205, 255), 18)
  $accent.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $accent.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $accent.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $graphics.DrawLines($accent, [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(119, 127),
    [System.Drawing.Point]::new(148, 154),
    [System.Drawing.Point]::new(200, 91)))

  $stream = [System.IO.MemoryStream]::new()
  $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $frames.Add($stream.ToArray())
  if ($size -eq 256) { $bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png) }
  $stream.Dispose(); $accent.Dispose(); $white.Dispose(); $path.Dispose()
  $back.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}

$output = [System.IO.File]::Create($icoPath)
$writer = [System.IO.BinaryWriter]::new($output)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($index = 0; $index -lt $sizes.Count; $index++) {
  $size = $sizes[$index]
  $writer.Write([byte]($size % 256)); $writer.Write([byte]($size % 256))
  $writer.Write([byte]0); $writer.Write([byte]0)
  $writer.Write([uint16]1); $writer.Write([uint16]32)
  $writer.Write([uint32]$frames[$index].Length)
  $writer.Write([uint32]$offset)
  $offset += $frames[$index].Length
}
foreach ($frame in $frames) { $writer.Write($frame) }
$writer.Dispose()
Write-Output "Wrote $pngPath and $icoPath"
