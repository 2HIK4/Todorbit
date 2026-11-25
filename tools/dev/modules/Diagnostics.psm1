# Diagnostics.psm1 - Todorbit Structured Receipts & Failure Diagnostics
# Captures failure stack traces, logs, creates reproduction scripts, and builds receipts.
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Get-FailuresDir {
    $dir = Join-Path (Get-RepoRoot) '.buildlog\failures'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    return $dir
}

function Sanitize-LogContent([string]$Text) {
    if (-not $Text) { return '' }
    $clean = $Text -replace '(?i)(bearer\s+[a-zA-Z0-9_\-\.]+)', 'Bearer [REDACTED]'
    $clean = $clean -replace '(?i)(key\s*=\s*[a-zA-Z0-9_\-]+)', 'key=[REDACTED]'
    $clean = $clean -replace '(?i)(password\s*=\s*\S+)', 'password=[REDACTED]'
    $clean = $clean -replace '(?i)(token\s*=\s*[a-zA-Z0-9_\-]+)', 'token=[REDACTED]'
    return $clean
}

function Extract-FailureDiagnostics([string]$LogContent, [string]$TestPath) {
    $clean = Sanitize-LogContent $LogContent
    $lines = $clean -split "`r?`n"

    $errors = [Collections.Generic.List[string]]::new()
    $stackTrace = [Collections.Generic.List[string]]::new()
    $failedTestNames = [Collections.Generic.List[string]]::new()

    $inFailure = $false
    $inStack = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Flutter test failure marker: "00:05 +1 -1: test description [E]"
        if ($line -match '^\d+:\d+\s+\+\d+\s+\-(\d+):\s+(.*?)\s+\[E\]$') {
            $failedTestNames.Add($Matches[2])
            $inFailure = $true
            continue
        }

        # Expected / Actual diff
        if ($line -match 'Expected:.*' -or $line -match '  Actual:.*') {
            $errors.Add($line.Trim())
            continue
        }

        # Exception message
        if ($line -match '^\s*(TestFailure|Exception|Error|StateError|ArgumentError|FileSystemException):\s+(.*)$') {
            $errors.Add($line.Trim())
            $inStack = $true
            continue
        }

        # Stack trace line: package:life_manager/..., test/..., dart:...
        if ($inStack -and ($line -match '^\s*(package:|dart:|test/|lib/).*\.dart\s+\d+:\d+')) {
            $stackTrace.Add($line.Trim())
            if ($stackTrace.Count -ge 8) { $inStack = $false }
            continue
        }
    }

    # If no structured marker found, grab last 20 lines of log
    if ($errors.Count -eq 0) {
        $tail = $lines | Select-Object -Last 15
        foreach ($tl in $tail) {
            if ($tl.Trim()) { $errors.Add($tl.Trim()) }
        }
    }

    return [pscustomobject]@{
        TestPath = $TestPath
        FailedTests = @($failedTestNames.ToArray())
        Errors = @($errors.ToArray())
        StackTrace = @($stackTrace.ToArray())
    }
}

function Save-FailureRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TestPath,
        [Parameter(Mandatory=$true)][string]$Command,
        [string]$RawLog = '',
        [string]$LogFile = ''
    )

    $repoRoot = Get-RepoRoot
    $failuresDir = Get-FailuresDir
    $failureId = "fail-" + (Get-Date -Format 'yyyyMMdd-HHmmss-ffff')

    $diagnostics = Extract-FailureDiagnostics -LogContent $RawLog -TestPath $TestPath

    # Create self-contained reproduction command and script
    $reproCmd = "$Command"
    if ($diagnostics.FailedTests.Count -gt 0) {
        $firstName = $diagnostics.FailedTests[0]
        # Quote test name for reproduction targeting
        $reproCmd = "$Command --name `"$firstName`""
    }

    $failureData = [pscustomobject]@{
        FailureId = $failureId
        Timestamp = (Get-Date -Format 'o')
        TestPath = $TestPath
        Command = $Command
        ReproductionCommand = $reproCmd
        FailedTests = $diagnostics.FailedTests
        Errors = $diagnostics.Errors
        StackTrace = $diagnostics.StackTrace
        LogFile = $LogFile
    }

    $recordFile = Join-Path $failuresDir "$failureId.json"
    $json = $failureData | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($recordFile, $json, [Text.Encoding]::UTF8)

    # Also update 'last_failure.json' symlink/pointer
    $lastFile = Join-Path $failuresDir 'last_failure.json'
    [IO.File]::WriteAllText($lastFile, $json, [Text.Encoding]::UTF8)

    return $failureData
}

function Get-LastFailure {
    [CmdletBinding()]
    param()
    $failuresDir = Get-FailuresDir
    $lastFile = Join-Path $failuresDir 'last_failure.json'
    if (Test-Path -LiteralPath $lastFile) {
        try {
            return (Get-Content -LiteralPath $lastFile -Raw | ConvertFrom-Json)
        } catch {}
    }
    return $null
}

function New-VerificationReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Scope,
        [string[]]$RequiredChecks = @(),
        [string[]]$ExecutedChecks = @(),
        [string[]]$ReusedChecks = @(),
        [string[]]$FailedChecks = @(),
        [string[]]$SkippedChecks = @(),
        [double]$TotalDurationSeconds = 0.0,
        [string]$SelectionRationale = '',
        [object[]]$Failures = @()
    )

    $overallOutcome = 'PASS'
    if ($FailedChecks.Count -gt 0) { $overallOutcome = 'FAIL' }
    elseif ($ExecutedChecks.Count -eq 0 -and $ReusedChecks.Count -gt 0) { $overallOutcome = 'REUSED' }
    elseif ($RequiredChecks.Count -eq 0) { $overallOutcome = 'PASS' }

    $receipt = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        Scope = $Scope
        OverallOutcome = $overallOutcome
        TotalDurationSeconds = [math]::Round($TotalDurationSeconds, 2)
        ChecksSummary = [pscustomobject]@{
            Required = $RequiredChecks.Count
            Executed = $ExecutedChecks.Count
            Reused = $ReusedChecks.Count
            Failed = $FailedChecks.Count
            Skipped = $SkippedChecks.Count
        }
        RequiredChecks = $RequiredChecks
        ExecutedChecks = $ExecutedChecks
        ReusedChecks = $ReusedChecks
        FailedChecks = $FailedChecks
        SkippedChecks = $SkippedChecks
        SelectionRationale = $SelectionRationale
        Failures = $Failures
        RemainingMandatoryGates = if ($overallOutcome -eq 'FAIL') { @("Fix $($FailedChecks.Count) failing check(s)") } else { @() }
    }

    return $receipt
}

Export-ModuleMember -Function Extract-FailureDiagnostics, Save-FailureRecord, Get-LastFailure, New-VerificationReceipt, Sanitize-LogContent
