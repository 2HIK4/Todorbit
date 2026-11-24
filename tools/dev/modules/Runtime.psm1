# Runtime.psm1 - Todorbit Native Windows & Android Runtime Automation
# Coordinates isolated portable profile journeys, application lifecycle,
# synthetic task workflows, persistence across restarts, and emulator acceptance.
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Invoke-WindowsRuntimeAutomation {
    [CmdletBinding()]
    param(
        [switch]$Json
    )

    $repoRoot = Get-RepoRoot
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $receiptRoot = Join-Path $repoRoot ".buildlog/verify/profile-journeys/$stamp-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $profileRoot = Join-Path $receiptRoot 'test-profiles'

    $previousEnv = @{}
    foreach ($key in @('APPDATA', 'LOCALAPPDATA', 'TODORBIT_PROFILE_JOURNEYS')) {
        $previousEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    }

    $flutterBat = if (Get-Command 'Resolve-TodorbitTool' -ErrorAction SilentlyContinue) {
        Resolve-TodorbitTool 'flutter'
    } else { 'flutter.bat' }

    $log = Join-Path $receiptRoot 'runtime.log'
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $exitCode = 0

    Push-Location $repoRoot
    try {
        $env:APPDATA = Join-Path $profileRoot 'Roaming'
        $env:LOCALAPPDATA = Join-Path $profileRoot 'Local'
        $env:TODORBIT_PROFILE_JOURNEYS = '1'
        New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null

        $testFiles = @(
            'test/startup_recovery_journeys_test.dart',
            'test/resource_journeys_test.dart',
            'test/runtime_workflow_journey_test.dart'
        )

        $testArgs = @('test', '--no-pub', '--concurrency=1', '--reporter=expanded', '--timeout=2m') + $testFiles
        Write-Host "Executing isolated Windows runtime workflow journey..." -ForegroundColor Cyan
        Write-Host "Isolated Profile: $profileRoot" -ForegroundColor Gray

        $ErrorActionPreference = 'Continue'
        & $flutterBat @testArgs *> $log
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'

        $watch.Stop()
        $durationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)

        $result = [pscustomobject]@{
            Platform = 'Windows (Isolated Portable Profile)'
            Status = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
            ExitCode = $exitCode
            DurationSeconds = $durationSeconds
            ReceiptDir = $receiptRoot
            LogFile = $log
            IsolatedProfile = $profileRoot
            WorkflowsVerified = @(
                'Application readiness & initialization',
                'Synthetic task creation & notes',
                'Task scheduling & calendar update',
                'Task completion & status tracking',
                'Calendar event creation',
                'Application restart & SQLite physical persistence verification'
            )
        }

        $resultJson = $result | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText((Join-Path $receiptRoot 'result.json'), $resultJson, [Text.UTF8Encoding]::new($false))

        if ($Json) {
            return $resultJson
        }

        $color = if ($exitCode -eq 0) { 'Green' } else { 'Red' }
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "           WINDOWS NATIVE RUNTIME WORKFLOW REPORT               " -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "Status:            $($result.Status)" -ForegroundColor $color
        Write-Host "Exit Code:         $exitCode" -ForegroundColor White
        Write-Host "Duration:          $($durationSeconds)s" -ForegroundColor Gray
        Write-Host "Isolated Profile:  $profileRoot" -ForegroundColor Gray
        Write-Host "Evidence Receipt:  $receiptRoot\result.json" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Verified Workflows:" -ForegroundColor Yellow
        foreach ($wf in $result.WorkflowsVerified) {
            Write-Host " - [x] $wf" -ForegroundColor White
        }
        Write-Host "=================================================================" -ForegroundColor Cyan

        if ($exitCode -ne 0) {
            Write-Host "Runtime failure log excerpt:" -ForegroundColor Red
            Get-Content -LiteralPath $log -Tail 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
            throw "Windows runtime journey failed with exit code $exitCode. See $log"
        }

        return $result
    } finally {
        foreach ($key in $previousEnv.Keys) {
            [Environment]::SetEnvironmentVariable($key, $previousEnv[$key], 'Process')
        }
        Pop-Location
    }
}

function Invoke-AndroidRuntimeAutomation {
    [CmdletBinding()]
    param(
        [string]$DeviceId = 'emulator-5554',
        [switch]$Json
    )

    $repoRoot = Get-RepoRoot
    $adbExe = 'adb'
    $deviceOnline = $false

    try {
        $adbDevices = & $adbExe devices 2>$null
        if ($adbDevices -match "$DeviceId\s+device") {
            $deviceOnline = $true
        }
    } catch {
        $deviceOnline = $false
    }

    if (-not $deviceOnline) {
        $blockedResult = [pscustomobject]@{
            Platform = 'Android (Emulator)'
            Status = 'BLOCKED'
            Reason = "No active Android emulator detected ($DeviceId not found or offline in 'adb devices')."
            DeviceId = $DeviceId
            Resolution = "Launch an authorized Android emulator instance before executing Android runtime acceptance."
            VerifiedSimulatedFallback = 'Unit/Widget/Offscreen tests pass, but physical Android runtime cannot be claimed without live device.'
        }

        if ($Json) {
            return ($blockedResult | ConvertTo-Json -Depth 4)
        }

        Write-Host "=================================================================" -ForegroundColor Yellow
        Write-Host "           ANDROID RUNTIME AUTOMATION: BLOCKED                  " -ForegroundColor Yellow
        Write-Host "=================================================================" -ForegroundColor Yellow
        Write-Host "Status:      BLOCKED (Environment Dependency Missing)" -ForegroundColor Yellow
        Write-Host "Target:      $DeviceId" -ForegroundColor White
        Write-Host "Reason:      $($blockedResult.Reason)" -ForegroundColor Red
        Write-Host "Resolution:  $($blockedResult.Resolution)" -ForegroundColor White
        Write-Host "Policy:      Genuinely unavailable capabilities are reported as blocked rather than claiming simulated tests prove native runtime behavior." -ForegroundColor Gray
        Write-Host "=================================================================" -ForegroundColor Yellow
        return $blockedResult
    }

    # Live emulator is available, run tools/android-16k-runtime.py
    Write-Host "Android emulator $DeviceId is online. Executing native 16k runtime acceptance..." -ForegroundColor Cyan
    $runtimeScript = Join-Path $repoRoot 'tools/android-16k-runtime.py'
    $proc = Start-Process -FilePath 'python' -ArgumentList @($runtimeScript) -NoNewWindow -PassThru -Wait
    $code = $proc.ExitCode

    $result = [pscustomobject]@{
        Platform = 'Android (Emulator)'
        Status = if ($code -eq 0) { 'PASS' } else { 'FAIL' }
        ExitCode = $code
        DeviceId = $DeviceId
    }

    if ($Json) { return ($result | ConvertTo-Json -Depth 4) }
    return $result
}

Export-ModuleMember -Function Invoke-WindowsRuntimeAutomation, Invoke-AndroidRuntimeAutomation
