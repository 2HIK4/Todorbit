param(
  [string]$Executable = 'build/windows/x64/runner/Release/TodorbitWidget.exe',
  [switch]$IncludeLifecycle,
  [switch]$IncludeBenchmark
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$executablePath = (Resolve-Path -LiteralPath (Join-Path $repo $Executable)).Path
$root = Join-Path $repo ('.buildlog/native-self-test/' + [guid]::NewGuid().ToString('N'))

function Invoke-WidgetMode([string]$Flag, [string]$Label) {
  $info = [Diagnostics.ProcessStartInfo]::new()
  $info.FileName = $executablePath
  $info.Arguments = $Flag
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  $info.EnvironmentVariables['APPDATA'] = Join-Path $root 'Roaming'
  $info.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $root 'Local'
  New-Item -ItemType Directory -Force -Path $info.EnvironmentVariables['APPDATA'],$info.EnvironmentVariables['LOCALAPPDATA'] | Out-Null
  $process = [Diagnostics.Process]::Start($info)
  $outputTask = $process.StandardOutput.ReadToEndAsync()
  $errorTask = $process.StandardError.ReadToEndAsync()
  $process.WaitForExit()
  $safeName = $Flag.TrimStart('-')
  $outputTask.Result | Set-Content -LiteralPath (Join-Path $root "$safeName-stdout.log")
  $errorTask.Result | Set-Content -LiteralPath (Join-Path $root "$safeName-stderr.log")
  if ($outputTask.Result) { Write-Output $outputTask.Result }
  if ($errorTask.Result) { Write-Output $errorTask.Result }
  if ($process.ExitCode -ne 0) { throw "Native $Label ($Flag) failed ($($process.ExitCode))." }
}

Write-Output "Native self-test profile: $root"
Invoke-WidgetMode '--self-test' 'self-test'
if ($IncludeLifecycle) { Invoke-WidgetMode '--lifecycle-self-test' 'lifecycle self-test' }
if ($IncludeBenchmark) { Invoke-WidgetMode '--scroll-benchmark' 'scroll benchmark' }
Write-Output 'Native self-test passed.'
