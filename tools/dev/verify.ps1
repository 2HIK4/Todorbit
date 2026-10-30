param(
  [ValidateSet('Quick','Feature','Full')][string]$Mode = 'Quick',
  [string]$Feature,
  [string[]]$ChangedPaths = @(),
  [string[]]$Tests = @(),
  [ValidateSet('None','Android','Windows','All')][string]$Platform = 'None',
  [string]$Device,
  [string]$JavaHome = $env:JAVA_HOME,
  [string]$AndroidSdk = $env:ANDROID_HOME,
  [string]$GradleUserHome = $env:GRADLE_USER_HOME,
  [switch]$AllowDebugDowngrade,
  [switch]$Plan
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$catalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'features.json') -Raw | ConvertFrom-Json
$steps = [Collections.Generic.List[object]]::new()
function Add-Step([string]$Tool, [string[]]$Arguments) {
  $steps.Add([pscustomobject]@{ tool=$Tool; arguments=$Arguments })
}
function Add-ScriptStep([string]$Script, [string[]]$Arguments) {
  Add-Step (Get-Process -Id $PID).Path (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$Script) + $Arguments)
}
if ($Feature -and $Feature -notin $catalog.PSObject.Properties.Name) {
  throw "Unknown feature '$Feature'. Choose: $($catalog.PSObject.Properties.Name -join ', ')"
}
if ($Mode -eq 'Feature' -and !$Feature) { throw 'Feature mode requires -Feature.' }
if ($Mode -eq 'Quick' -and (!$ChangedPaths.Count -or !$Tests.Count)) {
  throw 'Quick requires explicit -ChangedPaths and -Tests; tests are never guessed.'
}
if ($Mode -eq 'Full') {
  $formatPaths = @('lib','test','integration_test','test_driver')
  $analysisPaths = $formatPaths
  $testPaths = @('test')
} else {
  $formatPaths = @($ChangedPaths)
  if ($Mode -eq 'Feature') { $formatPaths += @($catalog.$Feature.paths) }
  $testPaths = @($Tests)
  if ($Mode -eq 'Feature') { $testPaths += @($catalog.$Feature.tests) }
  $formatPaths = @($formatPaths | Select-Object -Unique)
  $testPaths = @($testPaths | Select-Object -Unique)
  $analysisPaths = @($formatPaths + $testPaths | Select-Object -Unique)
}
foreach ($relative in @($formatPaths + $testPaths)) {
  $absolute = [IO.Path]::GetFullPath((Join-Path $repo $relative))
  if (!$absolute.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath $absolute)) {
    throw "Verification path must exist inside the repository: $relative"
  }
}
Add-Step 'dart' (@('format','--output=none','--set-exit-if-changed') + $formatPaths + $testPaths | Select-Object -Unique)
# Explicit source roots avoid analyzing ignored temporary checkouts and SDKs.
Add-Step 'flutter' (@('analyze','--no-pub') + $analysisPaths)
Add-Step 'flutter' (@('test','--no-pub','--concurrency=1','--reporter=expanded') + $testPaths)
if ($Mode -eq 'Full' -or $Feature -eq 'android-updates') {
  Add-Step 'python' @('-m','unittest','discover','-s','tools','-p','test_prepare_android_release.py')
}
if ($Mode -eq 'Full') {
  Add-Step 'python' @('-m','unittest','discover','-s','tools','-p','test_dev_verify.py')
  Add-Step 'python' @('tools/dev/check-docs.py')
}
if ($Platform -in @('Android','All')) {
  if (!$Device -or $Device -notmatch '^emulator-\d+$') { throw 'Android platform verification requires -Device emulator-N for an isolated disposable AVD.' }
  # Existing harness builds candidates, validates fixtures and runs native/UI integration.
  $arguments = @('-Device',$Device)
  if ($JavaHome) { $arguments += @('-JavaHome',$JavaHome) }
  if ($AndroidSdk) { $arguments += @('-AndroidSdk',$AndroidSdk) }
  if ($GradleUserHome) { $arguments += @('-GradleUserHome',$GradleUserHome) }
  if ($AllowDebugDowngrade) { $arguments += '-AllowDebugDowngrade' }
  Add-ScriptStep './tools/test-android-update.ps1' $arguments
}
if ($Platform -in @('Windows','All')) {
  Add-ScriptStep './tools/build-windows-release.ps1' @()
  Add-ScriptStep './tools/dev/native-self-test.ps1' @()
}
Add-Step 'git' @('diff','--check')
if ($Plan) { ConvertTo-Json -InputObject @($steps.ToArray()) -Depth 5; return }
Push-Location $repo
try {
  $logRoot = Join-Path $repo ('.buildlog/verify/' + (Get-Date -Format 'yyyyMMdd-HHmmss-ffff'))
  New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
  $results = [Collections.Generic.List[object]]::new()
  $source = (& git rev-parse HEAD).Trim()
  $dirty = [bool](& git status --porcelain)
  $failed = $false
  foreach ($step in $steps) {
    $log = Join-Path $logRoot "$($results.Count)-$([IO.Path]::GetFileNameWithoutExtension($step.tool)).log"
    Write-Output "$($step.tool) $($step.arguments -join ' ')"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $code = 0
    try {
      $null = Get-Command $step.tool -ErrorAction Stop
      $global:LASTEXITCODE = 0
      $ErrorActionPreference = 'Continue'
      & $step.tool @($step.arguments) *> $log
      if ($LASTEXITCODE) { $code = $LASTEXITCODE }
    } catch { $_ | Out-String | Add-Content -LiteralPath $log; $code = 1 }
    finally { $ErrorActionPreference = 'Stop' }
    $watch.Stop()
    $results.Add([pscustomobject]@{ tool=$step.tool; arguments=$step.arguments; exitCode=$code; seconds=[math]::Round($watch.Elapsed.TotalSeconds,2); log=$log })
    [pscustomobject]@{ source=$source; dirty=$dirty; mode=$Mode; feature=$Feature; platform=$Platform; steps=@($results.ToArray()) } |
      ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
    Write-Output "exit=$code seconds=$([math]::Round($watch.Elapsed.TotalSeconds,2)) log=$log"
    Get-Content -LiteralPath $log -Tail $(if ($code) {20} else {3})
    if ($code) { $failed = $true; break }
  }
  if ($failed) { throw "Verification failed. Evidence: $logRoot/result.json" }
} finally { Pop-Location }
