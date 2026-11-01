param([string]$Bundle = 'build/windows/x64/runner/Release')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows-crt.ps1')
$bundlePath = (Resolve-Path -LiteralPath $Bundle).Path
Assert-TodorbitWindowsCrtBundle $bundlePath
$root = Join-Path ([IO.Path]::GetTempPath()) ('todorbit-crt-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $root 'data') -Force | Out-Null
function Require-Rejection([scriptblock]$Action) {
  $rejected = $false
  try { & $Action } catch { $rejected = $true }
  if (!$rejected) { throw 'Invalid C++ runtime bundle was accepted.' }
}
try {
  Require-Rejection { Assert-TodorbitWindowsCrtBundle $root }
  Copy-Item -LiteralPath (Join-Path $bundlePath 'data/windows-crt.json') -Destination (Join-Path $root 'data/windows-crt.json')
  Require-Rejection { Assert-TodorbitWindowsCrtBundle $root }
  foreach ($name in $TodorbitWindowsCrtFiles) { Copy-Item -LiteralPath (Join-Path $bundlePath $name) -Destination (Join-Path $root $name) }
  Assert-TodorbitWindowsCrtBundle $root
  $receipt = Get-Content -LiteralPath (Join-Path $root 'data/windows-crt.json') -Raw | ConvertFrom-Json
  $receipt.files[0].sha256 = '0' * 64
  $receipt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $root 'data/windows-crt.json') -Encoding UTF8
  Require-Rejection { Assert-TodorbitWindowsCrtBundle $root }
  Copy-Item -LiteralPath (Join-Path $bundlePath 'data/windows-crt.json') -Destination (Join-Path $root 'data/windows-crt.json')
  [IO.File]::WriteAllBytes((Join-Path $root 'msvcp140.dll'), [byte[]](1,2,3))
  Require-Rejection { Assert-TodorbitWindowsCrtBundle $root }
  Write-Output 'Passed CRT bundle validation: signed originals accepted; missing receipt, missing DLLs, mismatched hash and altered DLL rejected.'
} finally {
  $resolved = [IO.Path]::GetFullPath($root)
  $temporary = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
  if (!$resolved.StartsWith($temporary,[StringComparison]::OrdinalIgnoreCase)) { throw 'CRT fixture cleanup escaped its temporary root.' }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
