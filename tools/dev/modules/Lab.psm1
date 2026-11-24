<#
.SYNOPSIS
    Todorbit Developer Automation Toolkit - Application & UI Laboratory Module
.DESCRIPTION
    Provides headless offscreen UI rendering, responsive viewport verification,
    and screenshot capture across desktop and mobile layouts.
#>

$ErrorActionPreference = 'Stop'

function Invoke-ScreenshotCapture {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Scenario = 'all',

        [string]$OutputDir,
        [switch]$Json
    )

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path

    if (-not $OutputDir) {
        $OutputDir = Join-Path $repoRoot '.buildlog\lab\screenshots'
    }
    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $flutterBat = Resolve-TodorbitTool -Tool 'flutter'
    $testScript = Join-Path $repoRoot 'test\lab_render_test.dart'

    # Set UIUX_CAPTURE_DIR environment variable for test process
    $env:UIUX_CAPTURE_DIR = $OutputDir

    $filterArg = if ($Scenario -and $Scenario -ne 'all') { @('--plain-name', $Scenario) } else { @() }
    $testArgs = @('test', $testScript, '--no-pub') + $filterArg

    $startTime = Get-Date
    $output = & $flutterBat @testArgs 2>&1
    $exitCode = $LASTEXITCODE
    $durationMs = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds, 0)

    $capturedFiles = @(Get-ChildItem -Path $OutputDir -Filter '*.png' -ErrorAction SilentlyContinue)

    $result = [pscustomobject]@{
        Scenario = $Scenario
        Success = ($exitCode -eq 0)
        ExitCode = $exitCode
        DurationMs = $durationMs
        ScreenshotsCaptured = $capturedFiles.Count
        OutputDir = $OutputDir
        Screenshots = @($capturedFiles | Select-Object -ExpandProperty Name)
    }

    if ($Json) {
        return ($result | ConvertTo-Json -Depth 4)
    }

    $statusColor = if ($result.Success) { 'Green' } else { 'Red' }
    $statusText = if ($result.Success) { 'PASS' } else { 'FAIL' }

    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "           APPLICATION LAB: OFFSCREEN UI RENDER CHECK           " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Scenario:              $($result.Scenario)" -ForegroundColor White
    Write-Host "Status:                $statusText" -ForegroundColor $statusColor
    Write-Host "Duration:              $($result.DurationMs) ms" -ForegroundColor Gray
    Write-Host "Output Directory:      $($result.OutputDir)" -ForegroundColor Gray
    Write-Host "Screenshots Captured:  $($result.ScreenshotsCaptured)" -ForegroundColor Green
    foreach ($sc in $result.Screenshots) {
        Write-Host " - $sc" -ForegroundColor White
    }
    Write-Host "=================================================================" -ForegroundColor Cyan

    if (-not $result.Success) {
        Write-Host "Render error output:" -ForegroundColor Red
        $output | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        throw "UI render check failed for scenario: $Scenario"
    }
}

Export-ModuleMember -Function Invoke-ScreenshotCapture
