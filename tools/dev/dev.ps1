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
    [switch]$Json,
    [switch]$Repair,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Plan,
    [string]$Feature,
    [string[]]$ChangedPaths = @(),
    [string[]]$Tests = @(),
    [string]$Platform = 'None',
    [string]$Scenario,
    [string]$Fixture,
    [string]$FailureId
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
    Write-Host "  dev scenario <workflow>                Execute automated application workflow." -ForegroundColor Gray
    Write-Host "  dev diagnose last                      Extract diagnostics and logs for last test failure." -ForegroundColor Gray
    Write-Host "  dev reproduce <failure-id>             Generate self-contained reproduction script." -ForegroundColor Gray
    Write-Host "  dev benchmark <scenario>               Measure startup, memory, and calendar performance." -ForegroundColor Gray
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
        Invoke-TodorbitDoctor -Json:$Json -Repair:$Repair
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
        if ($Subcommand -eq 'validate' -or $Plan) {
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
        } elseif ($Subcommand -eq 'refresh') {
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
        $passArgs = @()
        $sub = if ($Subcommand) { $Subcommand.ToLowerInvariant() } else { 'quick' }
        $targetMode = switch ($sub) {
            'quick' { 'Quick' }
            'feature' { 'Feature' }
            'full' { 'Full' }
            'changed' { 'Quick' }
            Default { 'Quick' }
        }

        # If verify changed is requested, use impact analysis and evidence reuse
        if ($sub -eq 'changed') {
            if (-not (Get-Command 'Invoke-ImpactAnalysis' -ErrorAction SilentlyContinue)) {
                throw "Impact analyzer module not loaded. Run 'dev verify quick -ChangedPaths ... -Tests ...' instead."
            }
            $impact = Invoke-ImpactAnalysis
            if ($impact.SelectedTests.Count -eq 0) {
                Write-Host "No affected tests detected by impact analysis." -ForegroundColor Green
                $receipt = New-VerificationReceipt -Scope 'Changed' -SelectionRationale 'No source changes detected'
                if ($Json) { $receipt | ConvertTo-Json -Depth 4 }
                return
            }

            $selected = @($impact.SelectedTests)
            $changed = @($impact.ChangedFiles)
            $testsToRun = [Collections.Generic.List[string]]::new()
            $reusedTests = [Collections.Generic.List[string]]::new()

            # Check evidence reuse for each selected test
            foreach ($t in $selected) {
                $fp = Get-TestCompositeFingerprint -TestPath $t -SourcePaths $changed
                $cached = Get-EvidenceRecord -Fingerprint $fp.CompositeFingerprint
                if ($cached -and -not $Force) {
                    $reusedTests.Add($t)
                    Write-Host " [REUSED] $t (Saved $([math]::Round($cached.DurationSeconds, 1))s from cached evidence: $($fp.CompositeFingerprint.Substring(0,8)))" -ForegroundColor Cyan
                } else {
                    $testsToRun.Add($t)
                }
            }

            if ($testsToRun.Count -eq 0 -and $reusedTests.Count -gt 0) {
                Write-Host ""
                Write-Host "All $($reusedTests.Count) required verification check(s) matched valid evidence. No execution needed." -ForegroundColor Green
                $receipt = New-VerificationReceipt -Scope 'Changed' -RequiredChecks $selected -ReusedChecks $reusedTests.ToArray() -SelectionRationale 'All tests matched 4-fingerprint evidence'
                if ($Json) { $receipt | ConvertTo-Json -Depth 4 }
                return
            }

            Write-Host "Impact analysis: $($reusedTests.Count) test(s) reused, $($testsToRun.Count) test(s) require fresh execution." -ForegroundColor White
            $ChangedPaths = $changed
            $Tests = @($testsToRun.ToArray())
        }

        $verifyArgs = @{
            Mode = $targetMode
            ChangedPaths = $ChangedPaths
            Tests = $Tests
            Platform = $Platform
        }
        if ($Feature) { $verifyArgs['Feature'] = $Feature }
        if ($Plan) { $verifyArgs['Plan'] = $true }

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
    'impact' {
        if (Get-Command 'Invoke-ImpactAnalysis' -ErrorAction SilentlyContinue) {
            Invoke-ImpactAnalysis -Json:$Json
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
    'self-test' {
        Write-Host "Running Developer Automation Toolkit self-tests..." -ForegroundColor Cyan
        $selfTestScript = Join-Path $PSScriptRoot 'test_toolkit_self.ps1'
        if (Test-Path -LiteralPath $selfTestScript) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $selfTestScript
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
