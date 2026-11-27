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
  [switch]$Plan,
  [switch]$Resume,
  [int]$TimeoutSeconds = 180,
  [int]$InactivityTimeoutSeconds = 120,
  [int]$MaxRetries = 1
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$MaxRetries = [math]::Max(0, [math]::Min(1, $MaxRetries))
Import-Module (Join-Path $PSScriptRoot 'modules\Session.psm1') -DisableNameChecking -Force
Import-Module (Join-Path $PSScriptRoot 'modules\Diagnostics.psm1') -DisableNameChecking -Force
Import-Module (Join-Path $PSScriptRoot 'modules\Evidence.psm1') -DisableNameChecking -Force
$catalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'features.json') -Raw | ConvertFrom-Json
$steps = [Collections.Generic.List[object]]::new()
function Add-Step([string]$Tool, [string[]]$Arguments) {
  $steps.Add([pscustomobject]@{ tool=$Tool; arguments=$Arguments })
}
function Add-ScriptStep([string]$Script, [string[]]$Arguments) {
  Add-Step (Get-Process -Id $PID).Path (@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$Script) + $Arguments)
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
$dartFormatPaths = @($formatPaths | Where-Object {
  $abs = Join-Path $repo $_
  ($_ -match '\.dart$') -or (Test-Path -LiteralPath $abs -PathType Container)
} | Select-Object -Unique)
$dartAnalysisPaths = @($analysisPaths | Where-Object {
  $abs = Join-Path $repo $_
  ($_ -match '\.dart$') -or (Test-Path -LiteralPath $abs -PathType Container)
} | Select-Object -Unique)
$flutterTestPaths = @($testPaths | Where-Object {
  $abs = Join-Path $repo $_
  ($_ -match '\.dart$') -or (Test-Path -LiteralPath $abs -PathType Container)
} | Select-Object -Unique)

if ($dartFormatPaths.Count -gt 0) {
  Add-Step 'dart' (@('format','--output=none','--set-exit-if-changed') + $dartFormatPaths)
}
# Explicit source roots avoid analyzing ignored temporary checkouts and SDKs.
if ($dartAnalysisPaths.Count -gt 0) {
  Add-Step 'flutter' (@('analyze','--no-pub') + $dartAnalysisPaths)
}
if ($flutterTestPaths.Count -gt 0) {
  Add-Step 'flutter' (@('test','--no-pub','--concurrency=1','--reporter=expanded') + $flutterTestPaths)
}
if ($Mode -eq 'Full' -or $Feature -eq 'android-updates') {
  Add-Step 'python' @('-m','unittest','discover','-s','tools','-p','test_prepare_android_release.py')
}
if ($Mode -eq 'Full') {
  Add-Step 'python' @('-m','unittest','discover','-s','tools','-p','test_dev_verify.py')
  Add-Step 'python' @('-m','unittest','discover','-s','tools','-p','test_windows_sandbox_prepare.py')
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
  $checkpointName = "checkpoint_$($Mode.ToLowerInvariant())$(if ($Feature) { "_$Feature" }).json"
  $priorCheckpoint = if ($Resume) { Get-VerificationCheckpoint -Name $checkpointName } else { $null }
  $completedKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  if ($priorCheckpoint -and $priorCheckpoint.Source -eq $source -and $priorCheckpoint.Completed) {
    foreach ($ck in $priorCheckpoint.Completed) { $null = $completedKeys.Add([string]$ck) }
  }
  $executedSuites = [Collections.Generic.List[string]]::new()
  $reusedSuites = [Collections.Generic.List[string]]::new()
  $failed = $false

  # Expand multi-file `flutter test ... a_test.dart b_test.dart` into bounded single-suite steps during execution
  $execUnits = [Collections.Generic.List[object]]::new()
  foreach ($step in $steps) {
    if ($step.tool -eq 'flutter' -and $step.arguments.Count -ge 2 -and $step.arguments[0] -eq 'test') {
      $flags = [Collections.Generic.List[string]]::new()
      $targets = [Collections.Generic.List[string]]::new()
      foreach ($arg in $step.arguments) {
        if ($targets.Count -eq 0 -and ($arg -eq 'test' -or $arg.StartsWith('-'))) {
          $flags.Add($arg)
        } else {
          $targets.Add($arg)
        }
      }
      if ($targets.Count -gt 1 -and ($targets | Where-Object { $_ -match '\.dart$' }).Count -eq $targets.Count) {
        foreach ($singleTarget in $targets) {
          $execUnits.Add([pscustomobject]@{
            tool = $step.tool
            arguments = @($flags.ToArray()) + @($singleTarget)
            suiteTarget = $singleTarget
            stepKey = "flutter-test::$singleTarget"
          })
        }
        continue
      }
      $execUnits.Add([pscustomobject]@{
        tool = $step.tool
        arguments = $step.arguments
        suiteTarget = ($targets -join ' ')
        stepKey = "flutter-test::$($targets -join ',')"
      })
    } else {
      $execUnits.Add([pscustomobject]@{
        tool = $step.tool
        arguments = $step.arguments
        suiteTarget = ''
        stepKey = "$($step.tool)::$($step.arguments -join ' ')"
      })
    }
  }

  function Resolve-StepExecutable([string]$ToolName) {
    $resolvedTool = $ToolName
    $firstCmd = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($firstCmd -and $firstCmd.Extension -in @('.exe', '.bat', '.cmd', '.ps1')) {
      return $firstCmd.Source
    }
    if ($ToolName -eq 'flutter') {
      $candBat = Get-Command 'flutter.bat' -ErrorAction SilentlyContinue
      if ($candBat) { return $candBat.Source }
    }
    if ($ToolName -eq 'dart') {
      $candExe = Get-Command 'dart.exe' -ErrorAction SilentlyContinue
      if ($candExe) { return $candExe.Source }
      $candBat = Get-Command 'dart.bat' -ErrorAction SilentlyContinue
      if ($candBat) { return $candBat.Source }
    }
    return $resolvedTool
  }

  foreach ($unit in $execUnits) {
    # 1. Resume checkpoint & evidence check for single Dart suites
    $unitFp = $null
    if ($unit.suiteTarget -and $unit.suiteTarget -match '\.dart$') {
      $srcPaths = @($ChangedPaths | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $repo ($_.Replace('/','\')))) -and $_ -notmatch '\.md$' -and $_ -notmatch '^docs/' })
      $unitFp = Get-TestCompositeFingerprint -TestPath $unit.suiteTarget -SourcePaths $srcPaths -Arguments '--no-pub --concurrency=1 --reporter=expanded'
      $cached = Get-EvidenceRecord -Fingerprint $unitFp.CompositeFingerprint
      if ($cached -or ($Resume -and $completedKeys.Contains($unit.stepKey))) {
        $reusedSuites.Add($unit.suiteTarget)
        Write-Output "[REUSED] $($unit.suiteTarget) ($($unitFp.CompositeFingerprint.Substring(0,8)))"
        continue
      }
    } elseif ($Resume -and $completedKeys.Contains($unit.stepKey)) {
      Write-Output "[RESUMED-SKIP] $($unit.stepKey)"
      continue
    }

    $safeSuffix = [IO.Path]::GetFileNameWithoutExtension($unit.tool)
    if ($unit.suiteTarget) { $safeSuffix = "$safeSuffix-$([IO.Path]::GetFileNameWithoutExtension($unit.suiteTarget))" }
    $log = Join-Path $logRoot "$($results.Count)-$safeSuffix.log"
    Write-Output "$($unit.tool) $($unit.arguments -join ' ')"

    $unitTimeout = if ($unit.tool -match 'powershell' -or ($unit.suiteTarget -and $unit.suiteTarget -eq 'test')) { [math]::Max($TimeoutSeconds, 600) } elseif ($unit.tool -eq 'git' -or $unit.tool -eq 'dart') { 90 } else { $TimeoutSeconds }
    $unitIdle = [math]::Min($unitTimeout, $InactivityTimeoutSeconds)

    $attempt = 0
    $runRes = $null
    do {
      $attempt++
      $resolvedTool = Resolve-StepExecutable $unit.tool
      $null = Get-Command $resolvedTool -ErrorAction Stop
      $runRes = Invoke-BoundedProcess -FilePath $resolvedTool -Arguments @($unit.arguments) -WorkingDirectory $repo -LogFile $log -TimeoutSeconds $unitTimeout -InactivityTimeoutSeconds $unitIdle -RepoRoot $repo

      # Bounded single retry strictly on recoverable repo worker lock (e.g., sqlite3.dll held by crashed dart/flutter_tester)
      $isLockRetryable = ($runRes.ExitCode -ne 0) -and ($runRes.Output -match 'Failed to delete file at .*sqlite3\.dll|used by another process')
      if ($runRes.ExitCode -eq 0 -or -not $isLockRetryable -or $attempt -gt $MaxRetries) {
        break
      }
      Write-Output "[TDAT-RETRY] Detected transient repo asset lock ($attempt/$MaxRetries); inspecting and cleaning repo-scoped workers before retry..."
      $diagPre = Get-RepoWorkerDiagnostics -RepoRoot $repo
      foreach ($w in $diagPre.RepoWorkers) {
        if ($w.Name -match '^(dart|flutter_tester)\.exe$') {
          $null = Stop-RepoSubprocessTree -RootProcessId $w.ProcessId -RepoRoot $repo -OnlyRepoScopedDescendants
        }
      }
      Start-Sleep -Milliseconds 350
    } while ($attempt -le $MaxRetries)

    $code = $runRes.ExitCode
    $results.Add([pscustomobject]@{
      tool = $unit.tool
      arguments = $unit.arguments
      status = $runRes.Status
      exitCode = $code
      seconds = $runRes.DurationSeconds
      attempts = $attempt
      log = $log
      diagnostics = $runRes.Diagnostics
    })

    if ($code -eq 0) {
      $null = $completedKeys.Add($unit.stepKey)
      if ($unit.suiteTarget -and $unit.suiteTarget -match '\.dart$' -and $unitFp) {
        $executedSuites.Add($unit.suiteTarget)
        $srcPaths = @($ChangedPaths | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $repo ($_.Replace('/','\')))) -and $_ -notmatch '\.md$' -and $_ -notmatch '^docs/' })
        $null = Save-EvidenceRecord -TestPath $unit.suiteTarget -SourcePaths $srcPaths -Outcome 'PASS' -DurationSeconds $runRes.DurationSeconds -Arguments '--no-pub --concurrency=1 --reporter=expanded' -PreRunFingerprint $unitFp.CompositeFingerprint -LogPath $log
      }
      $null = Save-VerificationCheckpoint -Name $checkpointName -Checkpoint ([pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        Source = $source
        Mode = $Mode
        Feature = $Feature
        Completed = @($completedKeys)
      })
    } else {
      $null = Save-FailureRecord -TestPath $(if ($unit.suiteTarget) { $unit.suiteTarget } else { $unit.tool }) -Command "$($unit.tool) $($unit.arguments -join ' ')" -RawLog $runRes.Output -LogFile $log -Status $runRes.Status -Diagnostics $(if ($runRes.Diagnostics) { $runRes.Diagnostics } else { Get-RepoWorkerDiagnostics -RepoRoot $repo })
    }

    [pscustomobject]@{ source=$source; dirty=$dirty; mode=$Mode; feature=$Feature; platform=$Platform; steps=@($results.ToArray()); reused=@($reusedSuites.ToArray()) } |
      ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
    Write-Output "status=$($runRes.Status) exit=$code seconds=$($runRes.DurationSeconds) log=$log"
    Get-Content -LiteralPath $log -Tail $(if ($code) {20} else {3})
    if ($code) { $failed = $true; break }
  }
  if (-not $failed) { Clear-VerificationCheckpoint -Name $checkpointName }
  if ($failed) { throw "Verification failed. Evidence: $logRoot/result.json (re-run with -Resume after fixing to reuse passed checkpoints)" }
} finally { Pop-Location }
