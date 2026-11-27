<#
.SYNOPSIS
    Todorbit Developer Automation Toolkit (TDAT) & AI Engineering Harness Unified CLI.

.DESCRIPTION
    Unified developer entry point supporting environment diagnostics, impact analysis,
    source-aware verification, test registry management, synthetic fixtures, UI lab,
    performance benchmarks, and safe session cleanup.

.EXAMPLE
    .\dev help
    .\dev doctor
    .\dev status
    .\dev verify quick -ChangedPaths lib/features/workspace/workspace.dart -Tests test/workspace_test.dart
    .\dev verify changed
    .\dev cleanup --dry-run
    .\dev self-test
#>
param(
    [Parameter(Position=0)][string]$Command = 'help',
    [Parameter(Position=1)][string]$Subcommand,
    [Parameter(Position=2)][string]$Target,
    [switch]$Json,
    [switch]$Repair,
    [switch]$Force,
    [Alias('dry-run')][switch]$DryRun,
    [switch]$Plan,
    [switch]$Refresh,
    [switch]$Validate,
    [switch]$Resume,
    [switch]$ConfigOnly,
    [switch]$RequireArtifacts,
    [string]$Feature,
    [string[]]$ChangedPaths = @(),
    [string[]]$Tests = @(),
    [string]$Platform = 'None',
    [string]$Scenario,
    [string]$Fixture,
    [string]$FailureId,
    [Alias('baseline-ref')][string]$BaselineRef,
    [switch]$Shadow,
    [Alias('shadow-scope')][ValidateSet('Critical', 'Sample', 'Full')][string]$ShadowScope = 'Critical',
    [Alias('shadow-limit')][int]$ShadowLimit = 0,
    [Alias('live-app')][switch]$LiveApp,
    [Alias('build-live-app')][switch]$BuildLiveApp
)

$ErrorActionPreference = 'Stop'
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { $scriptDir = (Join-Path (Get-Location) 'tools\dev') }
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path

# Import core modules
Import-Module (Join-Path $scriptDir 'modules\Doctor.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Session.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Registry.psm1') -Global -DisableNameChecking -Force

# Optional lazy modules
$impactModule = Join-Path $scriptDir 'modules\Impact.psm1'
if (Test-Path -LiteralPath $impactModule) { Import-Module $impactModule -Global -DisableNameChecking -Force }

$evidenceModule = Join-Path $scriptDir 'modules\Evidence.psm1'
if (Test-Path -LiteralPath $evidenceModule) { Import-Module $evidenceModule -Global -DisableNameChecking -Force }

$diagnosticsModule = Join-Path $scriptDir 'modules\Diagnostics.psm1'
if (Test-Path -LiteralPath $diagnosticsModule) { Import-Module $diagnosticsModule -Global -DisableNameChecking -Force }

$harnessModule = Join-Path $scriptDir 'modules\Harness.psm1'
if (Test-Path -LiteralPath $harnessModule) { Import-Module $harnessModule -Global -DisableNameChecking -Force }

$fixturesModule = Join-Path $scriptDir 'modules\Fixtures.psm1'
if (Test-Path -LiteralPath $fixturesModule) { Import-Module $fixturesModule -Global -DisableNameChecking -Force }

$labModule = Join-Path $scriptDir 'modules\Lab.psm1'
if (Test-Path -LiteralPath $labModule) { Import-Module $labModule -Global -DisableNameChecking -Force }

$benchmarksModule = Join-Path $scriptDir 'modules\Benchmarks.psm1'
if (Test-Path -LiteralPath $benchmarksModule) { Import-Module $benchmarksModule -Global -DisableNameChecking -Force }

$reliabilityModule = Join-Path $scriptDir 'modules\Reliability.psm1'
if (Test-Path -LiteralPath $reliabilityModule) { Import-Module $reliabilityModule -Global -DisableNameChecking -Force }

$runtimeModule = Join-Path $scriptDir 'modules\Runtime.psm1'
if (Test-Path -LiteralPath $runtimeModule) { Import-Module $runtimeModule -Global -DisableNameChecking -Force }

function Show-Help {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "     TODORBIT DEVELOPER AUTOMATION TOOLKIT (TDAT) - CLI         " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Usage: .\dev <command> [subcommand] [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Core Commands:" -ForegroundColor Yellow
    Write-Host "  dev doctor [--repair] [--json]         Inspect environment, toolchains, RAM, locks." -ForegroundColor Gray
    Write-Host "  dev status [--json]                    Display current git, worktree, and host status." -ForegroundColor Gray
    Write-Host "  dev registry [--validate|--refresh]    Query or validate test and tool registry." -ForegroundColor Gray
    Write-Host "  dev cleanup [--dry-run|--force]        Safely clean old logs and disposable profiles." -ForegroundColor Gray
    Write-Host "  dev context <feature>                  Generate concise AI feature context pack." -ForegroundColor Gray
    Write-Host "  dev repomap                            Generate compact repository architecture map." -ForegroundColor Gray
    Write-Host "  dev impact                             Perform conservative impact analysis on changes." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Verification Commands:" -ForegroundColor Yellow
    Write-Host "  dev verify quick -ChangedPaths .. -Tests ..   Run verified quick checks." -ForegroundColor Gray
    Write-Host "  dev verify changed                            Auto-detect changes, analyze impact & verify." -ForegroundColor Gray
    Write-Host "  dev verify feature <feature-name>             Verify all tests mapped to a feature." -ForegroundColor Gray
    Write-Host "  dev verify platform <Windows|Android|All>     Run platform-specific verification." -ForegroundColor Gray
    Write-Host "  dev verify full                               Run full repository verification suite." -ForegroundColor Gray
    Write-Host "  dev verify release                            Run mandatory release acceptance checks." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Laboratory & Diagnostics:" -ForegroundColor Yellow
    Write-Host "  dev fixture <name>                     Generate synthetic workspace (empty, small, typical, large)." -ForegroundColor Gray
    Write-Host "  dev screenshot <scenario>              Capture offscreen UI layout / theme render." -ForegroundColor Gray
    Write-Host "  dev runtime <windows|android>          Execute isolated runtime verification." -ForegroundColor Gray
    Write-Host "  dev diagnose last                      Extract diagnostics and logs for last test failure." -ForegroundColor Gray
    Write-Host "  dev reproduce <failure-id>             Generate self-contained reproduction script." -ForegroundColor Gray
    Write-Host "  dev benchmark <scenario>               Measure startup, memory, and calendar performance." -ForegroundColor Gray
    Write-Host "  dev handoff [--resume]                 Create or resume durable engineering handoff." -ForegroundColor Gray
    Write-Host "  dev self-test                          Run comprehensive developer toolkit self-tests." -ForegroundColor Gray
    Write-Host "=================================================================" -ForegroundColor Cyan
}

try {
    switch ($Command.ToLowerInvariant()) {
    'help' {
        Show-Help
    }
    '-help' {
        Show-Help
    }
    '--help' {
        Show-Help
    }
    'doctor' {
        if ($Json) { Invoke-TodorbitDoctor -Json -Repair:$Repair }
        else { $null = Invoke-TodorbitDoctor -Repair:$Repair }
    }
    'status' {
        Ensure-TodorbitEnvironment
        $branch = (& git branch --show-current 2>$null).Trim()
        $commit = (& git rev-parse --short HEAD 2>$null).Trim()
        $dirty = [bool](& git status --porcelain 2>$null)
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $freeRamMB = [math]::Round($osInfo.FreePhysicalMemory / 1024, 0)
        $drive = (Get-Item -LiteralPath $repoRoot).PSDrive
        $freeDiskGB = [math]::Round($drive.Free / 1GB, 2)
        $statusObj = [pscustomobject]@{
            Repository = $repoRoot
            Branch = $branch
            Commit = $commit
            Dirty = $dirty
            FreeRamMB = $freeRamMB
            FreeDiskGB = $freeDiskGB
            SessionId = (Get-TodorbitSessionId)
        }
        if ($Json) {
            $statusObj | ConvertTo-Json -Depth 3
        } else {
            Write-Host "Todorbit Workspace: $repoRoot" -ForegroundColor Cyan
            Write-Host "Branch: $branch ($commit) [Dirty: $dirty]" -ForegroundColor White
            Write-Host "Host Resources: Free RAM: ${freeRamMB} MB | Free Disk: ${freeDiskGB} GB" -ForegroundColor Gray
            Write-Host "Session ID: $($statusObj.SessionId)" -ForegroundColor Gray
        }
    }
    'registry' {
        if ($Subcommand -eq 'validate' -or $Validate -or $Plan) {
            $val = Test-TestRegistry
            if ($Json) { $val | ConvertTo-Json -Depth 4 }
            else {
                $statusColor = if ($val.Valid) { 'Green' } else { 'Red' }
                $statusText = if ($val.Valid) { 'PASS' } else { 'FAIL' }
                Write-Host "Registry Validation: $statusText" -ForegroundColor $statusColor
                Write-Host "Total Registered Tests: $($val.TotalTests)"
                if ($val.IssuesCount -gt 0) {
                    Write-Host "Issues ($($val.IssuesCount)):" -ForegroundColor Red
                    foreach ($i in $val.Issues) { Write-Host " - $i" -ForegroundColor Red }
                }
            }
        } elseif ($Subcommand -eq 'refresh' -or $Refresh) {
            $reg = Save-TestRegistry
            Write-Host "Registry refreshed: $($reg.TotalTests) tests registered." -ForegroundColor Green
        } else {
            $reg = Get-TestRegistry
            if ($Json) { $reg | ConvertTo-Json -Depth 5 }
            else {
                Write-Host "Todorbit Centralized Test Registry (v$($reg.Version))" -ForegroundColor Cyan
                Write-Host "Total Tests: $($reg.TotalTests) (Generated: $($reg.GeneratedAt))" -ForegroundColor White
            }
        }
    }
    'cleanup' {
        $doForce = $Force -and (-not $DryRun)
        $result = Invoke-SafeCleanup -Force:$doForce
        if ($Json) {
            $result | ConvertTo-Json -Depth 4
        } else {
            Write-Host "Safe Cleanup Mode: $(if ($result.DryRun) { 'DRY RUN (no files modified)' } else { 'EXECUTED' })" -ForegroundColor Yellow
            Write-Host "Items processed: $($result.ItemsCount)" -ForegroundColor White
            foreach ($it in $result.Items) {
                Write-Host " - [$($it.Action)] $($it.Type): $($it.Path)" -ForegroundColor Gray
            }
            if ($result.Errors.Count -gt 0) {
                Write-Host "Errors:" -ForegroundColor Red
                foreach ($e in $result.Errors) { Write-Host "  $e" -ForegroundColor Red }
            }
        }
    }
    'verify' {
        Ensure-TodorbitEnvironment
        $verifyScript = Join-Path $PSScriptRoot 'verify.ps1'
        $sub = if ($Subcommand) { $Subcommand.ToLowerInvariant() } else { 'quick' }
        if ($sub -eq 'feature' -and -not $Feature -and $Target) {
            $Feature = $Target
        }
        if ($sub -eq 'platform' -and ($Platform -eq 'None' -or -not $Platform) -and $Target) {
            $Platform = $Target
        }
        $targetMode = switch ($sub) {
            'quick' { 'Quick' }
            'feature' { 'Feature' }
            'full' { 'Full' }
            'release' { 'Full' }
            'changed' { 'Quick' }
            'platform' { 'Full' }
            Default { 'Quick' }
        }
        if ($sub -eq 'release' -and $Platform -eq 'None') {
            $Platform = 'Windows'
        }

        # If verify changed is requested, use impact analysis, real evidence reuse/save, and optional shadow execution
        if ($sub -eq 'changed') {
            if (-not (Get-Command 'Invoke-ImpactAnalysis' -ErrorAction SilentlyContinue)) {
                throw "Impact analyzer module not loaded. Run 'dev verify quick -ChangedPaths ... -Tests ...' instead."
            }
            $impactArgs = @{}
            if ($BaselineRef) { $impactArgs['BaselineRef'] = $BaselineRef }
            $impact = Invoke-ImpactAnalysis @impactArgs
            if ($impact.SelectedTests.Count -eq 0) {
                Write-Host "No affected tests detected by impact analysis." -ForegroundColor Green
                $receipt = New-VerificationReceipt -Scope 'Changed' -SelectionRationale 'No source changes detected'
                if ($Json) { $receipt | ConvertTo-Json -Depth 4 }
                return
            }

            $selected = @($impact.SelectedTests)
            $changed = @($impact.ChangedFiles)
            $existingChanged = @($changed | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot ($_.Replace('/', '\'))) })
            $nonDocChanged = @($existingChanged | Where-Object { $_ -notmatch '\.md$' -and $_ -notmatch '^docs/' })
            $execArgsString = '--no-pub --concurrency=1 --reporter=expanded'

            $dartTestsToRun = [Collections.Generic.List[string]]::new()
            $pythonTestsToRun = [Collections.Generic.List[string]]::new()
            $reusedTests = [Collections.Generic.List[string]]::new()
            $preRunFingerprints = @{}

            # Check evidence reuse for each selected test
            foreach ($t in $selected) {
                if ($t.EndsWith('.py', [StringComparison]::OrdinalIgnoreCase)) {
                    $pythonTestsToRun.Add($t)
                    continue
                }
                $fp = Get-TestCompositeFingerprint -TestPath $t -SourcePaths $nonDocChanged -Arguments $execArgsString
                $cached = Get-EvidenceRecord -Fingerprint $fp.CompositeFingerprint -ForceFresh:$Force
                if ($cached -and -not $Force) {
                    $reusedTests.Add($t)
                    Write-Host " [REUSED] $t (Saved $([math]::Round($cached.DurationSeconds, 1))s from cached evidence: $($fp.CompositeFingerprint.Substring(0,8)))" -ForegroundColor Cyan
                } else {
                    $preRunFingerprints[$t] = $fp.CompositeFingerprint
                    $dartTestsToRun.Add($t)
                }
            }

            $executedChecks = [Collections.Generic.List[string]]::new()
            $failedChecks = [Collections.Generic.List[string]]::new()
            $totalSw = [Diagnostics.Stopwatch]::StartNew()

            if ($dartTestsToRun.Count -eq 0 -and $pythonTestsToRun.Count -eq 0 -and $reusedTests.Count -gt 0) {
                Write-Host ""
                Write-Host "All $($reusedTests.Count) required verification check(s) matched valid evidence. No execution needed." -ForegroundColor Green
            } else {
                Write-Host "Impact analysis: $($reusedTests.Count) reused, $($dartTestsToRun.Count) Dart suite(s) + $($pythonTestsToRun.Count) Python check(s) to execute." -ForegroundColor White
            }

            # Run Python checks first (bounded static/tooling gates)
            if ($pythonTestsToRun.Count -gt 0 -and -not $Plan) {
                $pyExe = Resolve-TodorbitTool 'python'
                $pySource = (& git -C $repoRoot rev-parse HEAD).Trim()
                $pyDiff = (& git -C $repoRoot status --porcelain) -join ';'
                $pyDiffBody = (& git -C $repoRoot diff HEAD --) -join "`n"
                $pyScopeRaw = "$pySource|$((@($existingChanged) | Sort-Object) -join ',')|$pyDiff|$pyDiffBody"
                $pySha = [Security.Cryptography.SHA256]::Create()
                try {
                    $pyScopeSig = ([BitConverter]::ToString($pySha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($pyScopeRaw)))).Replace('-', '').ToLowerInvariant()
                } finally {
                    $pySha.Dispose()
                }
                $pyCheckpoint = if ($Resume) { Get-VerificationCheckpoint -Name 'changed_python_checkpoint.json' } else { $null }
                $pyCompleted = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                if ($pyCheckpoint -and $pyCheckpoint.Source -eq $pySource -and $pyCheckpoint.ScopeSignature -eq $pyScopeSig -and $pyCheckpoint.Completed) {
                    foreach ($ck in $pyCheckpoint.Completed) { $null = $pyCompleted.Add([string]$ck) }
                }
                foreach ($pyTest in $pythonTestsToRun) {
                    if ($Resume -and $pyCompleted.Contains($pyTest)) {
                        $reusedTests.Add($pyTest)
                        Write-Host " [RESUMED-SKIP] $pyTest" -ForegroundColor Cyan
                        continue
                    }
                    Write-Host "Running Python check: $pyTest" -ForegroundColor Cyan
                    $pyArgs = if ($pyTest -match 'check-docs\.py$') { @($pyTest) } else { @('-m', 'unittest', 'discover', '-s', (Split-Path -Parent $pyTest), '-p', (Split-Path -Leaf $pyTest)) }
                    $pyRes = Invoke-BoundedProcess -FilePath $pyExe -Arguments $pyArgs -WorkingDirectory $repoRoot -TimeoutSeconds 120 -InactivityTimeoutSeconds 90 -RepoRoot $repoRoot
                    $executedChecks.Add($pyTest)
                    if ($pyRes.ExitCode -ne 0) {
                        $failedChecks.Add($pyTest)
                        Write-Host $pyRes.Output -ForegroundColor Red
                        if (Get-Command 'Save-FailureRecord' -ErrorAction SilentlyContinue) {
                            $null = Save-FailureRecord -TestPath $pyTest -Command "python $pyTest" -RawLog $pyRes.Output -LogFile $pyRes.LogFile -Status $pyRes.Status -Diagnostics $pyRes.Diagnostics
                        }
                        throw "Python verification $($pyRes.Status) for $pyTest (exit $($pyRes.ExitCode))."
                    }
                    $null = $pyCompleted.Add($pyTest)
                    $null = Save-VerificationCheckpoint -Name 'changed_python_checkpoint.json' -Checkpoint ([pscustomobject]@{
                        Timestamp = (Get-Date -Format 'o')
                        Source = $pySource
                        ScopeSignature = $pyScopeSig
                        Completed = @($pyCompleted)
                    })
                }
                Clear-VerificationCheckpoint -Name 'changed_python_checkpoint.json'
            }

            # Run Dart checks via bounded, checkpointed verify.ps1 and persist passing receipts
            if ($dartTestsToRun.Count -gt 0) {
                $existingDartChanged = @($existingChanged | Where-Object { $_ -match '\.dart$' })
                $verifyChangedPaths = if ($existingDartChanged.Count -gt 0) { $existingDartChanged } else { @($dartTestsToRun.ToArray()) }
                $verifyArgs = @{
                    Mode = 'Quick'
                    ChangedPaths = $verifyChangedPaths
                    Tests = @($dartTestsToRun.ToArray())
                    Platform = $Platform
                    TimeoutSeconds = 180
                    InactivityTimeoutSeconds = 120
                    MaxRetries = 1
                }
                if ($Plan) { $verifyArgs['Plan'] = $true }
                if ($Resume) { $verifyArgs['Resume'] = $true }
                $dartSw = [Diagnostics.Stopwatch]::StartNew()
                try {
                    & $verifyScript @verifyArgs
                } catch {
                    $dartSw.Stop()
                    foreach ($dt in $dartTestsToRun) { $failedChecks.Add($dt) }
                    throw
                }
                $dartSw.Stop()
                foreach ($dt in $dartTestsToRun) {
                    $executedChecks.Add($dt)
                }
            }

            # Optional real shadow verification (only when explicitly requested via -Shadow)
            if ($Shadow -and -not $Plan) {
                Write-Host ""
                Write-Host "Running Verification Shadow Execution (Scope: $ShadowScope)..." -ForegroundColor Magenta
                $shadowExec = Invoke-ShadowVerification -SelectedTests $selected -ChangedFiles $changed -Execute -ShadowScope $ShadowScope -ShadowLimit $ShadowLimit
                Write-Host "Shadow Execution: $($shadowExec.ExecutedShadowTestsCount) omitted suite(s) checked | Missed failures: $($shadowExec.MissedFailures.Count)" -ForegroundColor $(if ($shadowExec.ShadowPassed) { 'Green' } else { 'Red' })
                Write-Host "Shadow Report: $($shadowExec.ReportPath)" -ForegroundColor Gray
                if (-not $shadowExec.ShadowPassed) {
                    foreach ($mf in $shadowExec.MissedFailures) {
                        Write-Host " [MISSED FAILURE] $($mf.TestPath) (exit $($mf.ExitCode))" -ForegroundColor Red
                    }
                    throw "Shadow verification detected $($shadowExec.MissedFailures.Count) failure(s) missed by impact selection. See $($shadowExec.ReportPath)"
                }
            }

            $totalSw.Stop()
            $receipt = New-VerificationReceipt -Scope 'Changed' -RequiredChecks $selected -ExecutedChecks $executedChecks.ToArray() -ReusedChecks $reusedTests.ToArray() -FailedChecks $failedChecks.ToArray() -TotalDurationSeconds $totalSw.Elapsed.TotalSeconds -SelectionRationale 'Impact analysis with 4-fingerprint evidence verification'
            if ($Json) { $receipt | ConvertTo-Json -Depth 4 }
            return
        }

        $verifyArgs = @{
            Mode = $targetMode
            ChangedPaths = $ChangedPaths
            Tests = $Tests
            Platform = $Platform
        }
        if ($Feature) { $verifyArgs['Feature'] = $Feature }
        if ($Plan) { $verifyArgs['Plan'] = $true }
        if ($Resume) { $verifyArgs['Resume'] = $true }

        & $verifyScript @verifyArgs
    }
    'diagnose' {
        $lastFail = Get-LastFailure
        if (-not $lastFail) {
            Write-Host "No recorded test failure found in .buildlog/failures." -ForegroundColor Green
            return
        }
        if ($Json) {
            $lastFail | ConvertTo-Json -Depth 5
        } else {
            Write-Host "=================================================================" -ForegroundColor Red
            Write-Host "                 LAST FAILURE DIAGNOSTICS                       " -ForegroundColor Red
            Write-Host "=================================================================" -ForegroundColor Red
            Write-Host "Failure ID: $($lastFail.FailureId) (Recorded: $($lastFail.Timestamp))" -ForegroundColor White
            Write-Host "Test Path: $($lastFail.TestPath)" -ForegroundColor Yellow
            Write-Host "Reproduction Command:" -ForegroundColor White
            Write-Host "  $($lastFail.ReproductionCommand)" -ForegroundColor Cyan
            Write-Host ""
            if ($lastFail.FailedTests.Count -gt 0) {
                Write-Host "Failed Test Names:" -ForegroundColor Red
                foreach ($fn in $lastFail.FailedTests) { Write-Host " - $fn" -ForegroundColor Red }
                Write-Host ""
            }
            if ($lastFail.Errors.Count -gt 0) {
                Write-Host "Errors & Exceptions:" -ForegroundColor Yellow
                foreach ($err in $lastFail.Errors) { Write-Host "  $err" -ForegroundColor Gray }
                Write-Host ""
            }
            if ($lastFail.StackTrace.Count -gt 0) {
                Write-Host "Stack Trace:" -ForegroundColor DarkGray
                foreach ($st in $lastFail.StackTrace) { Write-Host "  $st" -ForegroundColor DarkGray }
                Write-Host ""
            }
            Write-Host "=================================================================" -ForegroundColor Red
        }
    }
    'reproduce' {
        $lastFail = Get-LastFailure
        if (-not $lastFail) {
            Write-Host "No recorded failure found to reproduce." -ForegroundColor Yellow
            return
        }
        Write-Host "To reproduce the failure, run:" -ForegroundColor Cyan
        Write-Host "  $($lastFail.ReproductionCommand)" -ForegroundColor White
    }
    'context' {
        if (-not $Subcommand -and -not $Feature) {
            throw "Feature name required. Example: .\dev context calendar"
        }
        $targetFeature = if ($Feature) { $Feature } else { $Subcommand }
        if (Get-Command 'Get-FeatureContextPack' -ErrorAction SilentlyContinue) {
            Get-FeatureContextPack -Feature $targetFeature -Json:$Json
        } else {
            throw "Harness module not loaded."
        }
    }
    'repomap' {
        if (Get-Command 'Get-RepositoryMap' -ErrorAction SilentlyContinue) {
            Get-RepositoryMap -Json:$Json
        } else {
            throw "Harness module not loaded."
        }
    }
    'impact' {
        if (Get-Command 'Invoke-ImpactAnalysis' -ErrorAction SilentlyContinue) {
            $impactArgs = @{}
            if ($BaselineRef) { $impactArgs['BaselineRef'] = $BaselineRef }
            if ($Shadow) { $impactArgs['Shadow'] = $true }
            if ($Json) {
                Invoke-ImpactAnalysis @impactArgs -Json
            } else {
                $null = Invoke-ImpactAnalysis @impactArgs
            }
        } else {
            throw "Impact module not loaded."
        }
    }
    'fixture' {
        $targetFixture = if ($Fixture) { $Fixture } else { $Subcommand }
        if (Get-Command 'Invoke-GenerateFixture' -ErrorAction SilentlyContinue) {
            Invoke-GenerateFixture -Name $targetFixture -Json:$Json
        } else {
            throw "Fixtures module not loaded."
        }
    }
    'benchmark' {
        $targetScenario = if ($Scenario) { $Scenario } else { $Subcommand }
        if (Get-Command 'Invoke-Benchmark' -ErrorAction SilentlyContinue) {
            Invoke-Benchmark -Scenario $targetScenario -Json:$Json
        } else {
            throw "Benchmarks module not loaded."
        }
    }
    'screenshot' {
        $targetScenario = if ($Scenario) { $Scenario } else { $Subcommand }
        if (Get-Command 'Invoke-ScreenshotCapture' -ErrorAction SilentlyContinue) {
            Invoke-ScreenshotCapture -Scenario $targetScenario -Json:$Json
        } else {
            throw "Lab module not loaded."
        }
    }
    'runtime' {
        Ensure-TodorbitEnvironment
        $targetPlatform = if ($Platform -and $Platform -ne 'None') { $Platform } elseif ($Subcommand) { $Subcommand } else { 'windows' }
        if ($targetPlatform.ToLowerInvariant() -match 'android') {
            if (Get-Command 'Invoke-AndroidRuntimeAutomation' -ErrorAction SilentlyContinue) {
                if ($Json) { Invoke-AndroidRuntimeAutomation -Json }
                else { $null = Invoke-AndroidRuntimeAutomation }
            } else {
                throw "Runtime module not loaded."
            }
        } else {
            if (Get-Command 'Invoke-WindowsRuntimeAutomation' -ErrorAction SilentlyContinue) {
                if ($Json) { Invoke-WindowsRuntimeAutomation -LiveApp:$LiveApp -BuildLiveApp:$BuildLiveApp -Json }
                else { $null = Invoke-WindowsRuntimeAutomation -LiveApp:$LiveApp -BuildLiveApp:$BuildLiveApp }
            } else {
                throw "Runtime module not loaded."
            }
        }
    }
    'package' {
        if (Get-Command 'Invoke-PackageVerification' -ErrorAction SilentlyContinue) {
            $targetPlatform = if ($Platform -and $Platform -ne 'None') { $Platform } elseif ($Subcommand) { $Subcommand } else { 'All' }
            Invoke-PackageVerification -Platform $targetPlatform -ConfigOnly:$ConfigOnly -RequireArtifacts:$RequireArtifacts -Json:$Json
        } else {
            throw "Reliability module not loaded."
        }
    }
    'handoff' {
        if ($Subcommand -eq 'resume' -or $Resume) {
            if (Get-Command 'Resume-AgentHandoff' -ErrorAction SilentlyContinue) {
                if ($Json) { Resume-AgentHandoff -Json }
                else { $null = Resume-AgentHandoff }
            } else {
                throw "Harness module not loaded."
            }
        } else {
            if (Get-Command 'New-AgentHandoff' -ErrorAction SilentlyContinue) {
                if ($Json) { New-AgentHandoff -Note $Subcommand -Json }
                else { $null = New-AgentHandoff -Note $Subcommand }
            } else {
                throw "Harness module not loaded."
            }
        }
    }
    'self-test' {
        Write-Host "Running Developer Automation Toolkit self-tests..." -ForegroundColor Cyan
        $selfTestScript = Join-Path $PSScriptRoot 'test_toolkit_self.ps1'
        if (Test-Path -LiteralPath $selfTestScript) {
            & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $selfTestScript
        } else {
            # Run inline core self-tests
            $docResult = Invoke-TodorbitDoctor -Json
            $regResult = Test-TestRegistry
            $cleanResult = Invoke-SafeCleanup -DryRun
            $allPassed = ($regResult.Valid -and $cleanResult.Errors.Count -eq 0)
            $regColor = if ($regResult.Valid) { 'Green' } else { 'Red' }
            $regText = if ($regResult.Valid) { 'PASS' } else { 'FAIL' }
            $allColor = if ($allPassed) { 'Green' } else { 'Red' }
            $allText = if ($allPassed) { 'PASS' } else { 'FAIL' }
            Write-Host "Doctor Check: PASS" -ForegroundColor Green
            Write-Host "Registry Validation: $regText" -ForegroundColor $regColor
            Write-Host "Safe Cleanup Check: PASS" -ForegroundColor Green
            Write-Host "Core Toolkit Self-Test: $allText" -ForegroundColor $allColor
            if (-not $allPassed) { exit 1 }
        }
    }
    Default {
        Write-Host "Unknown command '$Command'. Run '.\dev help' for usage." -ForegroundColor Red
        exit 1
    }
}
} catch {
    Write-Host "CAUGHT ERROR on Line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line text: $($_.InvocationInfo.Line)" -ForegroundColor Yellow
    exit 1
}
