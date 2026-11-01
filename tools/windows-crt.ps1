# Application-local deployment follows Flutter's Windows deployment guidance.
$TodorbitWindowsCrtFiles = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')

function Assert-TodorbitMicrosoftCrt([string]$Path) {
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'A required Microsoft C++ runtime DLL is missing.' }
  $signature = Get-AuthenticodeSignature -LiteralPath $Path
  if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(?:^|,\s*)O=Microsoft Corporation(?:,|$)') {
    throw 'The C++ runtime DLL is not valid Microsoft-signed redistributable code.'
  }
}

function Assert-TodorbitWindowsCrtBundle([string]$Bundle) {
  $receiptPath = Join-Path $Bundle 'data/windows-crt.json'
  if (!(Test-Path -LiteralPath $receiptPath)) { throw 'C++ runtime deployment receipt missing. Stage the Windows redistributables before packaging.' }
  $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
  if ($receipt.format -ne 1 -or @($receipt.files).Count -ne $TodorbitWindowsCrtFiles.Count) { throw 'Invalid C++ runtime deployment receipt.' }
  foreach ($name in $TodorbitWindowsCrtFiles) {
    $item = @($receipt.files | Where-Object name -CEQ $name)
    if ($item.Count -ne 1) { throw 'C++ runtime receipt has an incorrect file set.' }
    $file = Join-Path $Bundle $name
    Assert-TodorbitMicrosoftCrt $file
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -cne $item[0].sha256) { throw 'C++ runtime DLL differs from its deployment receipt.' }
  }
}

function Copy-TodorbitWindowsCrt([string]$Bundle) {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
  if (!(Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio redistributable discovery is unavailable.' }
  $candidates = @(& $vswhere -latest -products '*' -find 'VC/Redist/MSVC/**/x64/Microsoft.VC*.CRT/msvcp140.dll' |
    Where-Object { $_ -and $_ -notmatch '(?i)[\\/]onecore[\\/]' } |
    Sort-Object -Property { [version]((Get-Item -LiteralPath $_).VersionInfo.FileVersion.Split(' ')[0]) } -Descending)
  if (!$candidates.Count) { throw 'The installed Visual Studio has no desktop x64 C++ redistributables.' }
  $source = Split-Path -Parent $candidates[0]
  $files = foreach ($name in $TodorbitWindowsCrtFiles) {
    $inputFile = Join-Path $source $name
    Assert-TodorbitMicrosoftCrt $inputFile
    $destination = Join-Path $Bundle $name
    Copy-Item -LiteralPath $inputFile -Destination $destination -Force
    [pscustomobject]@{
      name = $name
      version = (Get-Item -LiteralPath $destination).VersionInfo.FileVersion
      sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    }
  }
  @{format=1; files=@($files)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Bundle 'data/windows-crt.json') -Encoding UTF8
  Assert-TodorbitWindowsCrtBundle $Bundle
  Write-Output 'Staged and verified three Microsoft-signed desktop x64 C++ runtime DLLs.'
}
