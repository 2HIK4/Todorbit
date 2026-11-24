# Runtime.psm1 - Todorbit Windows & Android Runtime Verification
# Clearly distinguishes Flutter test-harness SQLite persistence checks from
# real Windows application process launch/UI/restart and Android 16 KiB emulator acceptance.
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Invoke-WindowsRuntimeAutomation {
    [CmdletBinding()]
    param(
        [switch]$LiveApp,
        [switch]$BuildLiveApp,
        [string]$ApplicationBinary = 'build\windows\x64\runner\Debug\Todorbit.exe',
        [switch]$Json
    )

    $repoRoot = Get-RepoRoot
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $receiptRoot = Join-Path $repoRoot ".buildlog/verify/profile-journeys/$stamp-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $profileRoot = Join-Path $receiptRoot 'test-profiles'

    $previousEnv = @{}
    foreach ($key in @('APPDATA', 'LOCALAPPDATA', 'PUB_CACHE', 'TODORBIT_PROFILE_JOURNEYS', 'TODORBIT_RUNTIME_PHASE', 'TODORBIT_RUNTIME_SENTINEL')) {
        $previousEnv[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
    }
    if (-not $env:PUB_CACHE -and $previousEnv['LOCALAPPDATA']) {
        $env:PUB_CACHE = Join-Path $previousEnv['LOCALAPPDATA'] 'Pub\Cache'
    }

    $flutterBat = if (Get-Command 'Resolve-TodorbitTool' -ErrorAction SilentlyContinue) {
        Resolve-TodorbitTool 'flutter'
    } else { 'flutter.bat' }

    if ($LiveApp) {
        $absBinary = Join-Path $repoRoot $ApplicationBinary
        if (-not (Test-Path -LiteralPath $absBinary) -and -not $BuildLiveApp) {
            $blocked = [pscustomobject]@{
                Platform = 'Windows (Live Application Process)'
                VerificationKind = 'WindowsLiveAppProcess_UI_Restart'
                Status = 'BLOCKED'
                Reason = "Driver-enabled Windows binary not found at '$ApplicationBinary' and -BuildLiveApp was not specified."
                NativeAppProcessLaunched = $false
                NativeUiInteractionExecuted = $false
                RealProcessRestartExecuted = $false
                Resolution = "Run '.\dev runtime windows -LiveApp -BuildLiveApp' (builds Debug driver target and executes real 2-process UI restart in isolated APPDATA)."
            }
            if ($Json) { return ($blocked | ConvertTo-Json -Depth 5) }
            Write-Host "=================================================================" -ForegroundColor Yellow
            Write-Host "        WINDOWS LIVE APP RUNTIME VERIFICATION: BLOCKED          " -ForegroundColor Yellow
            Write-Host "=================================================================" -ForegroundColor Yellow
            Write-Host "Status:     BLOCKED" -ForegroundColor Yellow
            Write-Host "Reason:     $($blocked.Reason)" -ForegroundColor Red
            Write-Host "Resolution: $($blocked.Resolution)" -ForegroundColor White
            Write-Host "=================================================================" -ForegroundColor Yellow
            return $blocked
        }

        $liveRoot = Join-Path $repoRoot ".buildlog/verify/windows-live-runtime/$stamp-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $liveProfile = Join-Path $liveRoot 'profile'
        $roaming = Join-Path $liveProfile 'Roaming'
        $local = Join-Path $liveProfile 'Local'
        New-Item -ItemType Directory -Force -Path $roaming, $local | Out-Null

        # Safety check: verify isolated profile is inside .buildlog and never user's real APPDATA
        $realAppData = [Environment]::GetFolderPath('ApplicationData')
        if ($roaming.StartsWith($realAppData, [StringComparison]::OrdinalIgnoreCase)) {
            throw "CRITICAL SAFETY VIOLATION: Isolated roaming directory resolved inside user APPDATA: $roaming"
        }

        $session1Log = Join-Path $liveRoot 'session1-create.log'
        $session2Log = Join-Path $liveRoot 'session2-restart-verify.log'
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $exit1 = 1
        $exit2 = 1

        $lockAcquired = $false
        if (Get-Command 'Acquire-ResourceLock' -ErrorAction SilentlyContinue) {
            $lockRes = Acquire-ResourceLock -ResourceName 'windows_build_and_runtime' -TimeoutSeconds 15 -Global
            if (-not $lockRes.Acquired) {
                throw "Could not acquire global Windows build/runtime lock: $($lockRes.Error)"
            }
            $lockAcquired = $true
        }

        Push-Location $repoRoot
        try {
            $env:APPDATA = $roaming
            $env:LOCALAPPDATA = $local
            $env:TODORBIT_RUNTIME_SENTINEL = "TDAT Runtime Restart Sentinel $stamp"

            # Session 1: Build/launch driver-enabled Todorbit.exe, create task via real FlutterDriver UI interaction, exit process
            $env:TODORBIT_RUNTIME_PHASE = 'create'
            $drive1Args = @('drive', '--no-pub', '--suppress-analytics', '-d', 'windows', '--target', 'test_driver/driver_main.dart', '--driver', 'test_driver/windows_runtime_workflow_test.dart')
            if ((Test-Path -LiteralPath $absBinary) -and -not $BuildLiveApp) {
                $drive1Args += @('--use-application-binary', $absBinary)
            }

            Write-Host "Session 1: Launching real Todorbit.exe in isolated profile for UI task creation..." -ForegroundColor Cyan
            Write-Host "Isolated Profile: $liveProfile" -ForegroundColor Gray
            $ErrorActionPreference = 'Continue'
            & $flutterBat @drive1Args *> $session1Log
            $exit1 = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'

            if ($exit1 -ne 0) {
                $s1Text = if (Test-Path -LiteralPath $session1Log) { Get-Content -LiteralPath $session1Log -Raw -ErrorAction SilentlyContinue } else { '' }
                if ($s1Text -match 'Building with plugins requires symlink support') {
                    $watch.Stop()
                    $blockedSymlink = [pscustomobject]@{
                        Platform = 'Windows (Live Application Process)'
                        VerificationKind = 'WindowsLiveAppProcess_UI_Restart'
                        Status = 'BLOCKED'
                        Reason = 'Windows Developer Mode (symlink support) is disabled on this host, so Flutter cannot compile/launch a local Windows plugin build.'
                        NativeAppProcessLaunched = $false
                        NativeUiInteractionExecuted = $false
                        RealProcessRestartExecuted = $false
                        LogFile = $session1Log
                        Resolution = 'Enable Windows Developer Mode (start ms-settings:developers) or supply a prebuilt driver-enabled Todorbit.exe via -ApplicationBinary.'
                    }
                    [IO.File]::WriteAllText((Join-Path $liveRoot 'result.json'), ($blockedSymlink | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
                    if ($Json) { return ($blockedSymlink | ConvertTo-Json -Depth 5) }
                    Write-Host "WINDOWS LIVE APP RUNTIME VERIFICATION: BLOCKED ($($blockedSymlink.Reason))" -ForegroundColor Yellow
                    return $blockedSymlink
                }
                throw "Windows live runtime Session 1 failed (exit $exit1). See $session1Log"
            }

            # Session 2: Relaunch a brand-new OS process using the built binary against the SAME isolated profile
            if (-not (Test-Path -LiteralPath $absBinary)) {
                throw "Expected built driver binary missing after Session 1 at $absBinary"
            }
            $env:TODORBIT_RUNTIME_PHASE = 'verify'
            $drive2Args = @('drive', '--no-pub', '--suppress-analytics', '-d', 'windows', '--use-application-binary', $absBinary, '--target', 'test_driver/driver_main.dart', '--driver', 'test_driver/windows_runtime_workflow_test.dart')
            Write-Host "Session 2: Restarting Todorbit.exe as a new OS process to verify UI persistence..." -ForegroundColor Cyan
            $ErrorActionPreference = 'Continue'
            & $flutterBat @drive2Args *> $session2Log
            $exit2 = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'

            $watch.Stop()
            $liveResult = [pscustomobject]@{
                Platform = 'Windows (Isolated Live Application Process)'
                VerificationKind = 'WindowsLiveAppProcess_UI_Restart'
                Status = if ($exit1 -eq 0 -and $exit2 -eq 0) { 'PASS' } else { 'FAIL' }
                Session1ExitCode = $exit1
                Session2ExitCode = $exit2
                DurationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
                ReceiptDir = $liveRoot
                IsolatedProfile = $liveProfile
                NativeAppProcessLaunched = $true
                NativeUiInteractionExecuted = $true
                RealProcessRestartExecuted = $true
                WorkflowsVerified = @(
                    'Real Todorbit.exe Debug+Driver process launch in isolated APPDATA/LOCALAPPDATA',
                    'Live UI interaction via FlutterDriver: New task -> task-title-field -> Create task',
                    'Process termination and fresh second OS process launch against same isolated profile',
                    'Restarted desktop UI verification of persisted sentinel task'
                )
                Limitations = @(
                    'Uses Debug driver_main.dart build rather than Release installer/portable package.',
                    'Native Win32 widget companion (TodorbitWidget.exe) requires separate Release build + --self-test.'
                )
            }
            [IO.File]::WriteAllText((Join-Path $liveRoot 'result.json'), ($liveResult | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
            if ($Json) { return ($liveResult | ConvertTo-Json -Depth 5) }

            $color = if ($liveResult.Status -eq 'PASS') { 'Green' } else { 'Red' }
            Write-Host "=================================================================" -ForegroundColor Cyan
            Write-Host "        WINDOWS LIVE APP LAUNCH & RESTART REPORT                " -ForegroundColor Cyan
            Write-Host "=================================================================" -ForegroundColor Cyan
            Write-Host "Status:           $($liveResult.Status)" -ForegroundColor $color
            Write-Host "Duration:         $($liveResult.DurationSeconds)s" -ForegroundColor Gray
            Write-Host "Isolated Profile: $liveProfile" -ForegroundColor Gray
            Write-Host "Evidence Receipt: $liveRoot\result.json" -ForegroundColor Gray
            foreach ($wf in $liveResult.WorkflowsVerified) { Write-Host " - [x] $wf" -ForegroundColor White }
            Write-Host "=================================================================" -ForegroundColor Cyan

            if ($exit2 -ne 0) {
                Get-Content -LiteralPath $session2Log -Tail 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                throw "Windows live runtime Session 2 (restart verification) failed (exit $exit2). See $session2Log"
            }
            return $liveResult
        } finally {
            foreach ($key in $previousEnv.Keys) {
                [Environment]::SetEnvironmentVariable($key, $previousEnv[$key], 'Process')
            }
            if ($lockAcquired -and (Get-Command 'Release-ResourceLock' -ErrorAction SilentlyContinue)) {
                Release-ResourceLock -ResourceName 'windows_build_and_runtime' -Global
            }
            Pop-Location
        }
    }

    # Default mode: Flutter test-harness SQLite & profile recovery checks (accurately classified)
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

        $testArgs = @('test', '--no-pub', '--suppress-analytics', '--concurrency=1', '--reporter=expanded', '--timeout=2m') + $testFiles
        Write-Host "Executing Flutter test-harness isolated profile & SQLite persistence checks..." -ForegroundColor Cyan
        Write-Host "Isolated Profile: $profileRoot" -ForegroundColor Gray

        $ErrorActionPreference = 'Continue'
        & $flutterBat @testArgs *> $log
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'

        $watch.Stop()
        $durationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)

        $result = [pscustomobject]@{
            Platform = 'Windows (Flutter Test Harness - Isolated Profile)'
            VerificationKind = 'FlutterTestHarness_SQLitePersistence'
            Status = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
            ExitCode = $exitCode
            DurationSeconds = $durationSeconds
            ReceiptDir = $receiptRoot
            LogFile = $log
            IsolatedProfile = $profileRoot
            NativeAppProcessLaunched = $false
            NativeUiInteractionExecuted = $false
            RealProcessRestartExecuted = $false
            WorkflowsVerified = @(
                'Startup recovery and isolated profile database initialization (Flutter test harness)',
                'Managed resource attachment journey assertions (Flutter test harness)',
                'Synthetic task/event SQLite CRUD, db.close(), and SQLite file reopen verification (Flutter test harness)'
            )
            Limitations = @(
                'Does NOT launch Todorbit.exe, render a desktop Win32 window, perform live UI clicks, or restart a native process.',
                'For actual Windows app launch, UI interaction, and restart verification, run: .\dev runtime windows -LiveApp -BuildLiveApp'
            )
        }

        $resultJson = $result | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText((Join-Path $receiptRoot 'result.json'), $resultJson, [Text.UTF8Encoding]::new($false))

        if ($Json) {
            return $resultJson
        }

        $color = if ($exitCode -eq 0) { 'Green' } else { 'Red' }
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "     WINDOWS TEST-HARNESS PROFILE & SQLITE PERSISTENCE REPORT    " -ForegroundColor Cyan
        Write-Host "=================================================================" -ForegroundColor Cyan
        Write-Host "Status:            $($result.Status)" -ForegroundColor $color
        Write-Host "Classification:    $($result.VerificationKind) (NOT native app launch/UI)" -ForegroundColor Yellow
        Write-Host "Duration:          $($durationSeconds)s" -ForegroundColor Gray
        Write-Host "Isolated Profile:  $profileRoot" -ForegroundColor Gray
        Write-Host "Evidence Receipt:  $receiptRoot\result.json" -ForegroundColor Gray
        Write-Host ""
        $marker = if ($exitCode -eq 0) { '[x]' } else { '[ ]' }
        Write-Host "Harness Workflows ($($result.Status)):" -ForegroundColor Yellow
        foreach ($wf in $result.WorkflowsVerified) {
            Write-Host " - $marker $wf" -ForegroundColor White
        }
        Write-Host "Limitations:" -ForegroundColor Yellow
        foreach ($lim in $result.Limitations) {
            Write-Host " - [!] $lim" -ForegroundColor Gray
        }
        Write-Host "=================================================================" -ForegroundColor Cyan

        if ($exitCode -ne 0) {
            Write-Host "Runtime failure log excerpt:" -ForegroundColor Red
            Get-Content -LiteralPath $log -Tail 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
            throw "Windows harness journey failed with exit code $exitCode. See $log"
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
        [string]$DeviceId = '',
        [switch]$Json
    )

    $repoRoot = Get-RepoRoot
    $adbExe = $null
    try {
        if (Get-Command 'Resolve-TodorbitTool' -ErrorAction SilentlyContinue) {
            $adbExe = Resolve-TodorbitTool 'adb'
        } else {
            $adbCmd = Get-Command 'adb.exe' -ErrorAction SilentlyContinue
            if ($adbCmd) { $adbExe = $adbCmd.Source }
        }
    } catch {
        $adbExe = $null
    }

    if (-not $adbExe) {
        $blockedResult = [pscustomobject]@{
            Platform = 'Android (Emulator)'
            VerificationKind = 'Android16kRuntimeAcceptance'
            Status = 'BLOCKED'
            Reason = 'adb.exe not found on PATH or under ANDROID_HOME\platform-tools.'
            DeviceId = $DeviceId
            MissingRequirements = @('adb.exe')
            Resolution = 'Configure ANDROID_HOME with platform-tools and launch an authorized API 36 16 KiB emulator.'
        }
        if ($Json) { return ($blockedResult | ConvertTo-Json -Depth 4) }
        Write-Host "ANDROID RUNTIME AUTOMATION: BLOCKED ($($blockedResult.Reason))" -ForegroundColor Yellow
        return $blockedResult
    }

    $onlineEmulators = @()
    try {
        $adbLines = & $adbExe devices 2>$null
        foreach ($line in $adbLines) {
            if ($line -match '^(emulator-\d+)\s+device\b') {
                $onlineEmulators += $Matches[1]
            }
        }
    } catch {}

    $targetDevice = if ($DeviceId) { $DeviceId } elseif ($onlineEmulators.Count -gt 0) { $onlineEmulators[0] } else { 'emulator-5554' }
    $deviceOnline = $onlineEmulators -contains $targetDevice

    $missingRequirements = [Collections.Generic.List[string]]::new()
    $detectedPageSize = 'unknown'
    $detectedApi = 'unknown'

    if (-not $deviceOnline) {
        $missingRequirements.Add("Online emulator '$targetDevice' (detected: $(if ($onlineEmulators.Count) { $onlineEmulators -join ', ' } else { 'none' }))")
    } else {
        try {
            $detectedPageSize = (& $adbExe -s $targetDevice shell getconf PAGE_SIZE 2>$null).Trim()
            $detectedApi = (& $adbExe -s $targetDevice shell getprop ro.build.version.sdk 2>$null).Trim()
        } catch {}
        if ($detectedPageSize -ne '16384') {
            $missingRequirements.Add("16 KiB emulator page size (detected PAGE_SIZE=$detectedPageSize on $targetDevice API $detectedApi; 16384 required)")
        }
    }

    $candidateApk = Join-Path $repoRoot '.buildlog\16k-runtime\candidate.apk'
    if (-not (Test-Path -LiteralPath $candidateApk)) {
        $missingRequirements.Add("Verified candidate APK at .buildlog/16k-runtime/candidate.apk")
    }
    if ([string]::IsNullOrWhiteSpace($env:APK_SHA256)) {
        $missingRequirements.Add("APK_SHA256 environment variable matching candidate.apk")
    }

    if ($missingRequirements.Count -gt 0) {
        $blockedResult = [pscustomobject]@{
            Platform = 'Android (Emulator)'
            VerificationKind = 'Android16kRuntimeAcceptance'
            Status = 'BLOCKED'
            Reason = ($missingRequirements -join '; ')
            DeviceId = $targetDevice
            OnlineEmulators = $onlineEmulators
            DetectedApi = $detectedApi
            DetectedPageSize = $detectedPageSize
            MissingRequirements = @($missingRequirements.ToArray())
            Resolution = "Supply an authorized API 36 16 KiB emulator (PAGE_SIZE=16384), .buildlog/16k-runtime/candidate.apk, and APK_SHA256."
            VerifiedSimulatedFallback = 'Host unit/widget/offscreen checks do not establish physical Android or 16 KiB emulator runtime.'
        }

        if ($Json) {
            return ($blockedResult | ConvertTo-Json -Depth 4)
        }

        Write-Host "=================================================================" -ForegroundColor Yellow
        Write-Host "           ANDROID RUNTIME AUTOMATION: BLOCKED                  " -ForegroundColor Yellow
        Write-Host "=================================================================" -ForegroundColor Yellow
        Write-Host "Status:      BLOCKED (Required Emulator / Artifacts Missing)" -ForegroundColor Yellow
        Write-Host "Target:      $targetDevice (API: $detectedApi, PAGE_SIZE: $detectedPageSize)" -ForegroundColor White
        Write-Host "Missing:" -ForegroundColor Red
        foreach ($mr in $missingRequirements) { Write-Host " - $mr" -ForegroundColor Red }
        Write-Host "Resolution:  $($blockedResult.Resolution)" -ForegroundColor White
        Write-Host "Policy:      Unavailable runtime prerequisites are reported as BLOCKED rather than claiming host tests prove native runtime." -ForegroundColor Gray
        Write-Host "=================================================================" -ForegroundColor Yellow
        return $blockedResult
    }

    # Live 16 KiB emulator and candidate APK verified: run tools/android-16k-runtime.py
    Write-Host "Android 16 KiB emulator $targetDevice is online. Executing native 16k runtime acceptance..." -ForegroundColor Cyan
    $runtimeScript = Join-Path $repoRoot 'tools/android-16k-runtime.py'
    $pyExe = if (Get-Command 'Resolve-TodorbitTool' -ErrorAction SilentlyContinue) { Resolve-TodorbitTool 'python' } else { 'python' }
    $proc = Start-Process -FilePath $pyExe -ArgumentList @($runtimeScript) -NoNewWindow -PassThru -Wait
    $code = $proc.ExitCode

    $result = [pscustomobject]@{
        Platform = 'Android (Emulator)'
        VerificationKind = 'Android16kRuntimeAcceptance'
        Status = if ($code -eq 0) { 'PASS' } else { 'FAIL' }
        ExitCode = $code
        DeviceId = $targetDevice
        DetectedApi = $detectedApi
        DetectedPageSize = $detectedPageSize
    }

    if ($Json) { return ($result | ConvertTo-Json -Depth 4) }
    return $result
}

Export-ModuleMember -Function Invoke-WindowsRuntimeAutomation, Invoke-AndroidRuntimeAutomation
