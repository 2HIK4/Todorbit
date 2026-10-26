param([switch]$VerifyDownloadOnly, [string]$VerifyCompilerPath = '')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
function Assert-InnoCompilerVersion([string]$Path) {
  # Read the complete response before checking exit status. A native command
  # piped into Select-Object -First can be terminated early by PowerShell 7.
  $info = [Diagnostics.ProcessStartInfo]::new($Path, '--version')
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.WindowStyle = 'Hidden'
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $probe = [Diagnostics.Process]::Start($info)
  try {
    $version = $probe.StandardOutput.ReadToEnd().Trim()
    $diagnostic = $probe.StandardError.ReadToEnd().Trim()
    $probe.WaitForExit()
    if ($probe.ExitCode -ne 0 -or $version -ne '7.1.0') {
      throw "Compiler version mismatch: exit $($probe.ExitCode), version [$version], stderr [$diagnostic]."
    }
    Write-Host "PASS: compiler reports $version with exit 0."
  } finally { $probe.Dispose() }
}
if ($VerifyCompilerPath) {
  Assert-InnoCompilerVersion $VerifyCompilerPath
  return
}
if (-not $env:RUNNER_TEMP -and -not $VerifyDownloadOnly) {
  throw 'Compiler installation is CI-only. Use -VerifyDownloadOnly for a local integrity check.'
}
$tempBase = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$root = Join-Path $tempBase 'Todorbit-InnoSetup-7.1.0'
New-Item -ItemType Directory -Path $root -Force | Out-Null
$setup = Join-Path $root 'innosetup-7.1.0-x64.exe'
# Official release linked from https://jrsoftware.org/isdl.php. Pin the
# immutable vendor GitHub asset digest rather than a changing package feed.
$uri = 'https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe'
$expectedHash = '0362A383ED217D4C4239B5933866DD96D3EB2102737DA92F80F6057A4B40DF2F'
Invoke-WebRequest -Uri $uri -OutFile $setup -UseBasicParsing
if ((Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash -ne $expectedHash) {
  throw 'Official Inno Setup download did not match the pinned SHA-256.'
}
Write-Host 'PASS: official Inno Setup 7.1.0 x64 download matches its pinned SHA-256.'
if ($VerifyDownloadOnly) { return }

$destination = Join-Path $root 'compiler'
$process = Start-Process -FilePath $setup -ArgumentList @(
  '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-',
  ('/DIR="{0}"' -f $destination)
) -WindowStyle Hidden -PassThru -Wait
if ($process.ExitCode -ne 0) { throw "Inno Setup installation failed ($($process.ExitCode))." }
$compiler = Join-Path $destination 'ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Installed compiler is missing.' }
Assert-InnoCompilerVersion $compiler
if (-not $env:GITHUB_ENV) { throw 'GitHub Actions environment file is unavailable.' }
"TODORBIT_ISCC=$compiler" | Out-File -LiteralPath $env:GITHUB_ENV -Encoding utf8 -Append
