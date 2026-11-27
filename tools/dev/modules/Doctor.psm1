# Doctor.psm1 - Todorbit Environment Doctor & Diagnostics
# Checks toolchains, SDKs, memory/disk thresholds, locks, and worktree isolation.
$ErrorActionPreference = 'Stop'

function Ensure-TodorbitEnvironment {
    [CmdletBinding()]
    param()

    # Flutter SDK auto-discovery and session PATH configuration
    $flutterCandidates = @(
        'C:\VScode\flutter\bin',
        $(if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'Documents\Codex\Todorbit-flutter-git\bin' })
    ) | Where-Object { $_ }
    $hasFlutter = $null -ne (Get-Command 'flutter' -ErrorAction SilentlyContinue)
    if (-not $hasFlutter) {
        foreach ($cand in $flutterCandidates) {
            if (Test-Path -LiteralPath (Join-Path $cand 'flutter.bat')) {
                $dartSdk = Join-Path $cand 'cache\dart-sdk\bin'
                $env:Path = "$cand;$dartSdk;" + $env:Path
                $hasFlutter = $true
                break
            }
        }
    }

    # Android JDK auto-discovery
    if (-not $env:JAVA_HOME -or -not (Test-Path -LiteralPath $env:JAVA_HOME)) {
        $javaCandidates = @(
            'C:\Program Files\Android\openjdk\jdk-21.0.8',
            'C:\Program Files\Microsoft\jdk-11.0.16.101-hotspot'
        )
        foreach ($jc in $javaCandidates) {
            if (Test-Path -LiteralPath (Join-Path $jc 'bin\java.exe')) {
                $env:JAVA_HOME = $jc
                break
            }
        }
    }

    # Android SDK auto-discovery
    if (-not $env:ANDROID_HOME -or -not (Test-Path -LiteralPath $env:ANDROID_HOME)) {
        $sdkCandidate = 'C:\Users\User\AppData\Local\Android\sdk'
        if (Test-Path -LiteralPath $sdkCandidate) {
            $env:ANDROID_HOME = $sdkCandidate
            $env:ANDROID_SDK_ROOT = $sdkCandidate
        }
    }
    if ($env:ANDROID_HOME -and (Test-Path -LiteralPath (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'))) {
        $platformTools = Join-Path $env:ANDROID_HOME 'platform-tools'
        if (-not (($env:Path -split ';') -contains $platformTools)) {
            $env:Path = "$platformTools;" + $env:Path
        }
    }
}

function Resolve-TodorbitTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ToolName
    )
    Ensure-TodorbitEnvironment

    switch ($ToolName.ToLowerInvariant()) {
        'flutter' {
            # Strictly prefer flutter.bat on Windows to prevent OpenWith on extensionless bash script
            $cand = Get-Command 'flutter.bat' -ErrorAction SilentlyContinue
            if ($cand) { return $cand.Source }
            $raw = Get-Command 'flutter' -ErrorAction SilentlyContinue
            if ($raw -and $raw.Extension -eq '.bat') { return $raw.Source }
            $fallback = 'C:\VScode\flutter\bin\flutter.bat'
            if (Test-Path -LiteralPath $fallback) { return $fallback }
            throw "Unable to safely resolve flutter.bat on Windows (preventing extensionless shell execution)."
        }
        'dart' {
            # Strictly prefer dart.exe (or dart.bat) to prevent OpenWith on extensionless bash script
            $candExe = Get-Command 'dart.exe' -ErrorAction SilentlyContinue
            if ($candExe) { return $candExe.Source }
            $candBat = Get-Command 'dart.bat' -ErrorAction SilentlyContinue
            if ($candBat) { return $candBat.Source }
            $fallbackExe = 'C:\VScode\flutter\bin\cache\dart-sdk\bin\dart.exe'
            if (Test-Path -LiteralPath $fallbackExe) { return $fallbackExe }
            $fallbackBat = 'C:\VScode\flutter\bin\dart.bat'
            if (Test-Path -LiteralPath $fallbackBat) { return $fallbackBat }
            throw "Unable to safely resolve dart.exe or dart.bat on Windows."
        }
        'python' {
            $cand = Get-Command 'python.exe' -ErrorAction SilentlyContinue
            if ($cand) { return $cand.Source }
            return 'python'
        }
        'git' {
            $cand = Get-Command 'git.exe' -ErrorAction SilentlyContinue
            if ($cand) { return $cand.Source }
            return 'git'
        }
        'adb' {
            $cand = Get-Command 'adb.exe' -ErrorAction SilentlyContinue
            if ($cand) { return $cand.Source }
            if ($env:ANDROID_HOME) {
                $sdkAdb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
                if (Test-Path -LiteralPath $sdkAdb) { return $sdkAdb }
            }
            $defaultAdb = 'C:\Users\User\AppData\Local\Android\sdk\platform-tools\adb.exe'
            if (Test-Path -LiteralPath $defaultAdb) { return $defaultAdb }
            throw "Unable to locate adb.exe on PATH or under ANDROID_HOME."
        }
        Default {
            $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.Extension -in @('.exe', '.bat', '.cmd', '.ps1')) {
                return $cmd.Source
            }
            if ($cmd -and [string]::IsNullOrEmpty($cmd.Extension)) {
                # Extensionless file detected - NEVER invoke directly via shell on Windows!
                throw "Refusing to invoke extensionless file '$($cmd.Source)' directly on Windows. Missing executable handler."
            }
            return $ToolName
        }
    }
}

function Invoke-TodorbitDoctor {
    [CmdletBinding()]
    param(
        [switch]$Json,
        [switch]$Repair
    )

    Ensure-TodorbitEnvironment

    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $checks = [Collections.Generic.List[object]]::new()
    $warnings = [Collections.Generic.List[string]]::new()
    $errors = [Collections.Generic.List[string]]::new()

    # 1. Flutter & Dart Check (always resolve explicit .bat / .exe)
    $flutterExe = $null
    $dartExe = $null
    try { $flutterExe = Resolve-TodorbitTool 'flutter' } catch {}
    try { $dartExe = Resolve-TodorbitTool 'dart' } catch {}
    if ($flutterExe -and $dartExe) {
        $flutterVer = & $flutterExe --version 2>$null | Select-Object -First 1
        $dartVer = & $dartExe --version 2>&1 | Select-Object -First 1
        $checks.Add([pscustomobject]@{
            Category = 'Flutter'
            Name = 'Flutter and Dart SDK'
            Status = 'OK'
            Detail = "$flutterVer | $dartVer"
        })
    } else {
        $checks.Add([pscustomobject]@{
            Category = 'Flutter'
            Name = 'Flutter and Dart SDK'
            Status = 'ERROR'
            Detail = 'Flutter or Dart executable not found on PATH or known locations.'
        })
        $errors.Add('Flutter SDK is missing or not on PATH.')
    }

    # 1b. Worktree Bootstrap & Package Configuration Check
    $packageConfigPath = Join-Path $repoRoot '.dart_tool\package_config.json'
    $pubspecLockPath = Join-Path $repoRoot 'pubspec.lock'
    $pluginsDepsPath = Join-Path $repoRoot '.flutter-plugins-dependencies'
    $needsPubGet = -not (Test-Path -LiteralPath $packageConfigPath)
    if (-not $needsPubGet -and (Test-Path -LiteralPath $pubspecLockPath)) {
        $lockTime = (Get-Item -LiteralPath $pubspecLockPath).LastWriteTimeUtc
        $pkgTime = (Get-Item -LiteralPath $packageConfigPath).LastWriteTimeUtc
        if ($lockTime -gt $pkgTime) {
            $needsPubGet = $true
        }
    }
    if ($needsPubGet -and $Repair -and $flutterExe) {
        Push-Location $repoRoot
        try {
            $ErrorActionPreference = 'Continue'
            & $flutterExe pub get --enforce-lockfile 2>&1 | Out-Null
            $pubExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = 'Stop'
            Pop-Location
        }
        $needsPubGet = ($pubExit -ne 0) -or -not (Test-Path -LiteralPath $packageConfigPath)
    }
    if ($needsPubGet) {
        $checks.Add([pscustomobject]@{
            Category = 'Workspace'
            Name = 'Dart Package Configuration'
            Status = 'ERROR'
            Detail = "Missing or stale .dart_tool/package_config.json (unprepared worktree). Run '.\dev doctor --repair' or 'flutter.bat pub get --enforce-lockfile'."
        })
        $errors.Add("Worktree package configuration missing or stale. Run '.\dev doctor --repair' before running --no-pub verification or screenshots.")
    } else {
        $checks.Add([pscustomobject]@{
            Category = 'Workspace'
            Name = 'Dart Package Configuration'
            Status = 'OK'
            Detail = 'Worktree dependencies resolved (.dart_tool/package_config.json present).'
        })
    }

    if ((Test-Path -LiteralPath $pluginsDepsPath) -and (-not $Repair)) {
        try {
            $pluginManifest = Get-Content -LiteralPath $pluginsDepsPath -Raw | ConvertFrom-Json
            $winPlugins = @($pluginManifest.plugins.windows)
            $symlinkDir = Join-Path $repoRoot 'windows\flutter\ephemeral\.plugin_symlinks'
            $missingLinks = @($winPlugins | Where-Object {
                -not (Test-Path -LiteralPath (Join-Path $symlinkDir $_.name))
            } | Select-Object -ExpandProperty name)
            if ($missingLinks.Count -gt 0) {
                $checks.Add([pscustomobject]@{
                    Category = 'Workspace'
                    Name = 'Windows Plugin Junctions'
                    Status = 'WARNING'
                    Detail = "Missing ephemeral Windows plugin links: $($missingLinks -join ', '). Run '.\dev doctor --repair'."
                })
                $warnings.Add("Missing Windows plugin links ($($missingLinks -join ', ')). Run '.\dev doctor --repair'.")
            }
        } catch {}
    }

    # 2. Windows Toolchain (Visual Studio / C++ / MSVC)
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $hasVs = $false
    $vsDetail = 'Not detected'
    if (Test-Path -LiteralPath $vsWhere) {
        $vsInstall = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($vsInstall) {
            $hasVs = $true
            $vsDetail = "Visual Studio C++ detected at: $vsInstall"
        }
    }
    $checks.Add([pscustomobject]@{
        Category = 'Windows'
        Name = 'Visual Studio C++ Toolchain'
        Status = if ($hasVs) { 'OK' } else { 'WARNING' }
        Detail = $vsDetail
    })
    if (-not $hasVs) {
        $warnings.Add('Visual Studio C++ tools needed for Windows native release builds.')
    }

    # 2b. Windows Developer Mode (symlink support required by Flutter Windows plugin builds)
    $devMode = $false
    try {
        $unlock = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue
        if ($unlock -and $unlock.AllowDevelopmentWithoutDevLicense -eq 1) { $devMode = $true }
    } catch {}
    $checks.Add([pscustomobject]@{
        Category = 'Windows'
        Name = 'Windows Developer Mode (Symlink Support)'
        Status = if ($devMode) { 'OK' } else { 'WARNING' }
        Detail = if ($devMode) { 'Developer Mode enabled (AllowDevelopmentWithoutDevLicense=1).' } else { 'Developer Mode disabled; local flutter build/drive on Windows with plugins is blocked unless prebuilt binary or CI is used.' }
    })
    if (-not $devMode) {
        $warnings.Add('Windows Developer Mode disabled: local Windows Flutter builds/flutter drive require symlink support.')
    }

    # 3. Android Toolchain
    $hasJava = $false
    $javaDetail = 'JAVA_HOME not configured'
    if ($env:JAVA_HOME -and (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
        $hasJava = $true
        $javaDetail = "JDK located at: $env:JAVA_HOME"
    }
    $hasSdk = $false
    $sdkDetail = 'ANDROID_HOME not configured'
    if ($env:ANDROID_HOME -and (Test-Path -LiteralPath $env:ANDROID_HOME)) {
        $hasSdk = $true
        $sdkDetail = "Android SDK located at: $env:ANDROID_HOME"
    }
    $checks.Add([pscustomobject]@{
        Category = 'Android'
        Name = 'JDK & Android SDK'
        Status = if ($hasJava -and $hasSdk) { 'OK' } else { 'WARNING' }
        Detail = "$javaDetail; $sdkDetail"
    })
    if (-not $hasJava) { $warnings.Add('JDK not configured for Android operations.') }
    if (-not $hasSdk) { $warnings.Add('Android SDK not configured for Android operations.') }

    # 4. Host Resources: Memory & Disk
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $freeRamMB = [math]::Round($osInfo.FreePhysicalMemory / 1024, 0)
    $totalRamMB = [math]::Round($osInfo.TotalVisibleMemorySize / 1024, 0)
    $ramDetail = "Free RAM: ${freeRamMB} MB / Total: ${totalRamMB} MB"
    $ramStatus = 'OK'
    if ($freeRamMB -lt 2048) {
        $ramStatus = 'WARNING'
        $warnings.Add("Low free RAM (${freeRamMB} MB). Heavy builds or emulators may cause memory pressure.")
    }
    $checks.Add([pscustomobject]@{
        Category = 'Host'
        Name = 'Host RAM'
        Status = $ramStatus
        Detail = $ramDetail
    })

    $drive = (Get-Item -LiteralPath $repoRoot).PSDrive
    $freeDiskGB = [math]::Round($drive.Free / 1GB, 2)
    $diskStatus = 'OK'
    $diskDetail = "Free Disk on $($drive.Name):: ${freeDiskGB} GB"
    if ($freeDiskGB -lt 5.0) {
        $diskStatus = 'WARNING'
        $warnings.Add("Low disk space on drive $($drive.Name): (${freeDiskGB} GB free).")
    }
    $checks.Add([pscustomobject]@{
        Category = 'Host'
        Name = 'Disk Space'
        Status = $diskStatus
        Detail = $diskDetail
    })

    # 5. Git Isolation, Root Discovery & Worktree Hygiene
    $rawBranch = (& git -C $repoRoot branch --show-current 2>$null)
    $currentBranch = if ($rawBranch) { ($rawBranch | Out-String).Trim() } else { '(detached HEAD)' }
    $rawCommit = (& git -C $repoRoot rev-parse --short HEAD 2>$null)
    $currentCommit = if ($rawCommit) { ($rawCommit | Out-String).Trim() } else { '(unknown)' }
    $gitTopLevel = (& git -C $repoRoot rev-parse --show-toplevel 2>$null)
    $worktreeLines = @(& git -C $repoRoot worktree list --porcelain 2>$null)
    $isolationStatus = 'OK'
    $isolationDetail = "Worktree: $repoRoot | Branch: $currentBranch | Commit: $currentCommit"
    $resolvedRepoRoot = [IO.Path]::GetFullPath($repoRoot)

    if ($gitTopLevel) {
        $resolvedGitTop = [IO.Path]::GetFullPath(($gitTopLevel | Out-String).Trim())
        if ($resolvedGitTop -ine $resolvedRepoRoot) {
            $isolationStatus = 'WARNING'
            $warnings.Add("Repo root ($resolvedRepoRoot) differs from Git top-level ($resolvedGitTop).")
        }
    }

    $prunableWorktrees = @()
    $newerWorktreePaths = @()
    $currentWtPath = $null
    $currentWtBranch = $null
    $currentWtHead = $null
    $currentWtPrunable = $false
    foreach ($wtLine in ($worktreeLines + @(''))) {
        if ([string]::IsNullOrWhiteSpace($wtLine)) {
            if ($currentWtPath) {
                if ($currentWtPrunable -or -not (Test-Path -LiteralPath $currentWtPath)) {
                    $prunableWorktrees += $currentWtPath
                } elseif ([IO.Path]::GetFullPath($currentWtPath) -ine $resolvedRepoRoot -and $currentWtHead) {
                    $null = & git -C $repoRoot merge-base --is-ancestor HEAD $currentWtHead 2>$null
                    $headIsAncestorOfOther = ($LASTEXITCODE -eq 0)
                    $null = & git -C $repoRoot merge-base --is-ancestor $currentWtHead HEAD 2>$null
                    $otherIsAncestorOfHead = ($LASTEXITCODE -eq 0)
                    if ($headIsAncestorOfOther -and -not $otherIsAncestorOfHead -and $currentWtBranch) {
                        $newerWorktreePaths += "$currentWtPath ($currentWtBranch)"
                    }
                }
            }
            $currentWtPath = $null
            $currentWtBranch = $null
            $currentWtHead = $null
            $currentWtPrunable = $false
            continue
        }
        if ($wtLine -match '^worktree\s+(.+)$') { $currentWtPath = [IO.Path]::GetFullPath($Matches[1].Trim()) }
        elseif ($wtLine -match '^HEAD\s+([0-9a-fA-F]+)$') { $currentWtHead = $Matches[1].Trim() }
        elseif ($wtLine -match '^branch\s+refs/heads/(.+)$') { $currentWtBranch = $Matches[1].Trim() }
        elseif ($wtLine -match '^prunable') { $currentWtPrunable = $true }
    }

    if ($prunableWorktrees.Count -gt 0) {
        $isolationStatus = 'WARNING'
        $warnings.Add("Missing/prunable Git worktree path(s) detected: $($prunableWorktrees -join ', '). Verify active checkout before editing.")
    }
    if ($newerWorktreePaths.Count -gt 0) {
        $isolationStatus = 'WARNING'
        $warnings.Add("Ahead descendant worktree(s) exist while running from '$repoRoot': $($newerWorktreePaths -join '; '). Confirm intended worktree.")
    }
    $checks.Add([pscustomobject]@{
        Category = 'Git'
        Name = 'Worktree and Branch Isolation'
        Status = $isolationStatus
        Detail = $isolationDetail
    })

    # 5b. Workspace Path Hygiene (detect stale hardcoded workspace paths in active config/tools/skills)
    $pathCheckScript = Join-Path $repoRoot 'tools\test_workspace_paths.py'
    $pythonExe = $null
    try { $pythonExe = Resolve-TodorbitTool 'python' } catch {}
    if ((Test-Path -LiteralPath $pathCheckScript) -and $pythonExe) {
        Push-Location $repoRoot
        try {
            $ErrorActionPreference = 'Continue'
            $pathAuditOut = & $pythonExe -m unittest tools/test_workspace_paths.py 2>&1
            $pathAuditExit = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
        } finally {
            Pop-Location
        }
        if ($pathAuditExit -eq 0) {
            $checks.Add([pscustomobject]@{
                Category = 'Workspace'
                Name = 'Portable Path Hygiene'
                Status = 'OK'
                Detail = 'Active config, skills, tools, and core docs are free of stale hardcoded workspace paths.'
            })
        } else {
            $checks.Add([pscustomobject]@{
                Category = 'Workspace'
                Name = 'Portable Path Hygiene'
                Status = 'WARNING'
                Detail = 'Stale hardcoded workspace paths detected. Run: python -m unittest tools/test_workspace_paths.py'
            })
            $warnings.Add('Stale hardcoded workspace paths found in active config/docs/skills (run tools/test_workspace_paths.py).')
        }
    }

    # 6. Active Build & Contention Check
    $competingProcs = Get-Process -Name 'flutter', 'dart', 'gradle', 'MSBuild' -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID }
    $contentionStatus = 'OK'
    $contentionDetail = 'No conflicting background compiler processes.'
    if ($competingProcs.Count -gt 0) {
        $contentionStatus = 'WARNING'
        $procNames = ($competingProcs | Select-Object -ExpandProperty ProcessName -Unique) -join ', '
        $contentionDetail = "Active competing processes detected: $procNames"
        $warnings.Add("Active compiler/build processes detected ($procNames). Heavy workloads should coordinate locks.")
    }
    $checks.Add([pscustomobject]@{
        Category = 'Concurrency'
        Name = 'Active Process Contention'
        Status = $contentionStatus
        Detail = $contentionDetail
    })

    # 7. Safe Repair Execution
    if ($Repair) {
        # Prepare plugin symlinks / junctions if needed
        $prepScript = Join-Path $repoRoot 'tools\dev\prepare-windows-plugins.ps1'
        if (Test-Path -LiteralPath $prepScript) {
            try {
                & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $prepScript | Out-Null
                $checks.Add([pscustomobject]@{
                    Category = 'Repair'
                    Name = 'Windows Plugin Junctions'
                    Status = 'OK'
                    Detail = 'Verified/repaired Windows plugin ephemeral junctions.'
                })
            } catch {
                $warnings.Add("Repair failed for plugin junctions: $_")
            }
        }
    }

    $overallStatus = if ($errors.Count -gt 0) { 'FAIL' } elseif ($warnings.Count -gt 0) { 'WARN' } else { 'PASS' }

    $report = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        OverallStatus = $overallStatus
        Checks = @($checks.ToArray())
        Warnings = @($warnings.ToArray())
        Errors = @($errors.ToArray())
    }

    if ($Json) {
        return ($report | ConvertTo-Json -Depth 5)
    }

    # Human-readable format
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "       TODORBIT ENVIRONMENT DOCTOR REPORT                 " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    $statusColor = 'Red'
    if ($overallStatus -eq 'PASS') { $statusColor = 'Green' }
    elseif ($overallStatus -eq 'WARN') { $statusColor = 'Yellow' }
    Write-Host "Status: $overallStatus" -ForegroundColor $statusColor
    Write-Host ""
    foreach ($c in $checks) {
        $color = switch ($c.Status) {
            'OK' { 'Green' }
            'WARNING' { 'Yellow' }
            'ERROR' { 'Red' }
            Default { 'White' }
        }
        Write-Host " [$($c.Status)] " -ForegroundColor $color -NoNewline
        Write-Host "$($c.Category) - $($c.Name): " -ForegroundColor White -NoNewline
        Write-Host "$($c.Detail)" -ForegroundColor Gray
    }
    Write-Host ""
    if ($warnings.Count -gt 0) {
        Write-Host "Warnings:" -ForegroundColor Yellow
        foreach ($w in $warnings) { Write-Host "  - $w" -ForegroundColor Yellow }
        Write-Host ""
    }
    if ($errors.Count -gt 0) {
        Write-Host "Errors:" -ForegroundColor Red
        foreach ($e in $errors) { Write-Host "  - $e" -ForegroundColor Red }
        Write-Host ""
    }
    Write-Host "============================================================" -ForegroundColor Cyan

    return $report
}

Export-ModuleMember -Function Ensure-TodorbitEnvironment, Resolve-TodorbitTool, Invoke-TodorbitDoctor
