<#
.SYNOPSIS
    Todorbit Developer Automation Toolkit - Synthetic Fixture Generator Module
.DESCRIPTION
    Generates deterministic, isolated synthetic workspaces in .buildlog/fixtures/<name>/
    without touching user data in %APPDATA%\TodoPilot.
#>

$ErrorActionPreference = 'Stop'

function Invoke-GenerateFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateSet('empty', 'small', 'typical', 'large', 'calendar-stress', 'sync-conflict', 'migration')]
        [string]$Name,

        [Parameter(Position=1)]
        [string]$DestinationPath,

        [int]$Seed = 42,
        [switch]$Json
    )

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path

    if (-not $DestinationPath) {
        $DestinationPath = Join-Path $repoRoot ".buildlog\fixtures\$Name"
    }

    $genScript = Join-Path $scriptDir '..\generate_fixture.py'
    if (-not (Test-Path -LiteralPath $genScript)) {
        throw "Fixture generator script not found: $genScript"
    }

    $pythonExe = (Get-Command 'python' -ErrorAction SilentlyContinue).Source
    if (-not $pythonExe) {
        throw "Python executable not found in PATH."
    }

    $jsonOutput = & $pythonExe $genScript $Name $DestinationPath $Seed
    if ($LASTEXITCODE -ne 0) {
        throw "Fixture generator failed with exit code ${LASTEXITCODE}: $jsonOutput"
    }

    $res = $jsonOutput | ConvertFrom-Json

    if ($Json) {
        return ($res | ConvertTo-Json -Depth 4)
    }

    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "           SYNTHETIC FIXTURE GENERATED SUCCESSFULLY             " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Fixture Name:     $($res.Fixture)" -ForegroundColor White
    Write-Host "Random Seed:      $($res.Seed) (Deterministic)" -ForegroundColor Gray
    Write-Host "Database File:    $($res.DatabasePath)" -ForegroundColor Green
    Write-Host "Database Size:    $([math]::Round($res.DatabaseSizeBytes / 1024, 2)) KB" -ForegroundColor Gray
    Write-Host "Schema Version:   $($res.SchemaVersion)" -ForegroundColor White
    Write-Host "Tasks Populated:  $($res.TaskCount)" -ForegroundColor White
    Write-Host "Events Populated: $($res.EventCount)" -ForegroundColor White
    Write-Host "Generated At:     $($res.GeneratedAt)" -ForegroundColor Gray
    Write-Host "=================================================================" -ForegroundColor Cyan
}

Export-ModuleMember -Function Invoke-GenerateFixture
