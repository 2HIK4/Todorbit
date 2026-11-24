<#
.SYNOPSIS
    Todorbit Developer Automation Toolkit - Comprehensive Self-Test Suite
.DESCRIPTION
    Validates CLI parsing, doctor diagnostics, test registry integrity, impact analysis,
    evidence caching, session locking, safe cleanup, and process invocation safety.
#>

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path

Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "     RUNNING TODORBIT DEVELOPER AUTOMATION TOOLKIT SELF-TESTS    " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Import all modules
Import-Module (Join-Path $scriptDir 'modules\Doctor.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Session.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Registry.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Impact.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Evidence.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Diagnostics.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Harness.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Fixtures.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Lab.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Benchmarks.psm1') -Global -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir 'modules\Reliability.psm1') -Global -DisableNameChecking -Force

$testsPassed = 0
$testsFailed = 0

function Assert-Test {
    param(
        [string]$Name,
        [scriptblock]$Check
    )
    Write-Host "Checking: $Name ... " -NoNewline -ForegroundColor White
    try {
        $result = & $Check
        if ($result -eq $false) {
            throw "Assertion returned false"
        }
        Write-Host "PASS" -ForegroundColor Green
        $script:testsPassed++
    } catch {
        Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
        $script:testsFailed++
    }
}

# 1. Doctor Environment Diagnostics
Assert-Test "Doctor environment diagnostics and toolchain resolution" {
    $doc = Invoke-TodorbitDoctor -Json | ConvertFrom-Json
    ($doc.OverallStatus -in @('PASS', 'WARN')) -and ($doc.Errors.Count -eq 0) -and ($doc.Checks.Count -gt 0)
}

# 2. Test Registry Integrity
Assert-Test "Centralized test registry consistency (0 issues, all valid)" {
    $reg = Test-TestRegistry
    $reg.Valid -and ($reg.TotalTests -ge 220) -and ($reg.IssuesCount -eq 0)
}

# 3. Session Locking & Mutex
Assert-Test "Session ID generation and atomic lock mechanics" {
    $sid = Get-TodorbitSessionId
    [bool]$sid -and ($sid.Length -ge 8)
}

# 4. Safe Cleanup Dry-Run Protection
Assert-Test "Safe cleanup dry-run execution (path-traversal safe)" {
    $clean = Invoke-SafeCleanup -DryRun
    $clean.Errors.Count -eq 0
}

# 5. Process Invocation Safety Policy
Assert-Test "Process invocation safety (explicit .bat/.exe, non-interactive, no OpenWith)" {
    $pythonExe = (Get-Command 'python').Source
    $safetyScript = Join-Path $repoRoot 'tools\test_process_invocation_safety.py'
    $proc = Start-Process -FilePath $pythonExe -ArgumentList $safetyScript -NoNewWindow -PassThru -Wait
    $proc.ExitCode -eq 0
}

# 6. AI Feature Context Pack Generation
Assert-Test "Deterministic AI feature context pack generator" {
    $packJson = Get-FeatureContextPack -Feature 'calendar' -Json
    $pack = $packJson | ConvertFrom-Json
    ($pack.Feature -eq 'calendar') -and ($pack.Tests.Count -ge 5) -and ($pack.PrimaryRequirements.Count -gt 0)
}

# 7. Repository Architecture Map Generation
Assert-Test "Repository architecture map (topology and layer metrics)" {
    $mapJson = Get-RepositoryMap -Json
    $map = $mapJson | ConvertFrom-Json
    ($map.Metrics.DartSourceFiles -ge 200) -and ($map.Metrics.TotalExecutableSuites -ge 220)
}

# 8. Synthetic Fixture Generation
Assert-Test "Synthetic fixture generator (empty workspace)" {
    $fix = Invoke-GenerateFixture -Name 'empty' -Json | ConvertFrom-Json
    ($fix.Fixture -eq 'empty') -and ($fix.TaskCount -eq 0) -and (Test-Path -LiteralPath $fix.DatabasePath)
}

# 9. Release Package and Architecture Verification
Assert-Test "Windows x64 PE and Inno Setup package verification" {
    $pkg = Invoke-PackageVerification -Platform Windows -Json | ConvertFrom-Json
    $pkg.OverallPassed -and $pkg.Details.Windows.inno_setup.passed
}

# 10. Conservative Impact Analysis
Assert-Test "Impact analysis changed detection" {
    $imp = Invoke-ImpactAnalysis -Json | ConvertFrom-Json
    ($null -ne $imp.ChangedFilesCount) -and ($null -ne $imp.SelectedTestsCount)
}

# 11. Performance Benchmark Toolkit
Assert-Test "Performance benchmarking toolkit diagnostics" {
    $bench = Invoke-Benchmark -Scenario 'toolkit' -Json | ConvertFrom-Json
    ($bench.Scenario -eq 'toolkit') -and ($bench.Metrics.RegistryLookupMs -gt 0)
}

# 12. Adversarial Evidence Cache Safety
Assert-Test "Adversarial verification of evidence cache safety and corruption rejection" {
    $pythonExe = (Get-Command 'python').Source
    $evidenceSafetyScript = Join-Path $repoRoot 'tools\dev\test_evidence_cache_safety.py'
    $proc = Start-Process -FilePath $pythonExe -ArgumentList $evidenceSafetyScript -NoNewWindow -PassThru -Wait
    $proc.ExitCode -eq 0
}

# 13. Impact Analyzer Behavioral Safety
Assert-Test "Impact analyzer behavioral coverage (schema, UI, platform, fallback)" {
    $pythonExe = (Get-Command 'python').Source
    $impactScript = Join-Path $repoRoot 'tools\dev\test_impact_behavior.py'
    $proc = Start-Process -FilePath $pythonExe -ArgumentList $impactScript -NoNewWindow -PassThru -Wait
    $proc.ExitCode -eq 0
}

# 14. Session Ownership & Multi-Worktree Locking Safety
Assert-Test "Session ownership, cross-worktree locking, and safe cleanup boundaries" {
    $pythonExe = (Get-Command 'python').Source
    $lockingScript = Join-Path $repoRoot 'tools\dev\test_session_locking_safety.py'
    $proc = Start-Process -FilePath $pythonExe -ArgumentList $lockingScript -NoNewWindow -PassThru -Wait
    $proc.ExitCode -eq 0
}

# 15. Agent Engineering Handoff & Resumption
Assert-Test "Agent engineering handoff checkpoint and drift-aware resumption" {
    $cp = New-AgentHandoff -Note 'Self-test handoff validation' -Json | ConvertFrom-Json
    $res = Resume-AgentHandoff -Json | ConvertFrom-Json
    $res.CommitMatches -and ($res.RecordedBranch -eq $cp.Branch)
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "Self-Test Results: $testsPassed Passed, $testsFailed Failed" -ForegroundColor $(if ($testsFailed -eq 0) { 'Green' } else { 'Red' })
Write-Host "=================================================================" -ForegroundColor Cyan

if ($testsFailed -gt 0) {
    exit 1
}
