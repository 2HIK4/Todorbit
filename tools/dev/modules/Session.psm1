# Session.psm1 - Todorbit Session Ownership, Resource Locking & Safe Cleanup
# Ensures process safety, 16GB host memory protection, and zero-data-loss cleanup.
$ErrorActionPreference = 'Stop'

function Get-TodorbitSessionId {
    [CmdletBinding()]
    param()
    if (-not $script:TodorbitSessionId) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $script:TodorbitSessionId = "tdat-$PID-$timestamp"
    }
    return $script:TodorbitSessionId
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Get-LockDirectory([switch]$Global) {
    if ($Global) {
        $dir = Join-Path ([IO.Path]::GetTempPath()) 'todorbit_global_locks'
    } else {
        $dir = Join-Path (Get-RepoRoot) '.buildlog\locks'
    }
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    return $dir
}

function Acquire-ResourceLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ResourceName,
        [int]$TimeoutSeconds = 10,
        [int]$LockTtlSeconds = 1800,
        [switch]$Global
    )

    $lockDir = Get-LockDirectory -Global:$Global
    $lockFile = Join-Path $lockDir "$ResourceName.lock"
    $sessionId = Get-TodorbitSessionId
    $watch = [Diagnostics.Stopwatch]::StartNew()

    while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        # Check existing lock
        if (Test-Path -LiteralPath $lockFile) {
            try {
                $content = Get-Content -LiteralPath $lockFile -Raw -ErrorAction Stop | ConvertFrom-Json
                $lockPid = $content.PID
                $lockCreated = [datetime]$content.Timestamp
                $ageSeconds = (Get-Date).Subtract($lockCreated).TotalSeconds

                # Is owning process still running?
                $procRunning = $false
                if ($lockPid) {
                    $proc = Get-Process -Id $lockPid -ErrorAction SilentlyContinue
                    if ($proc) { $procRunning = $true }
                }

                # If process is dead or lock has expired past TTL, reclaim lock
                if (-not $procRunning -or $ageSeconds -gt $LockTtlSeconds) {
                    Write-Verbose "Reclaiming stale lock on $ResourceName (PID: $lockPid dead=$(-not $procRunning), age=$([int]$ageSeconds)s)"
                    Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
                } else {
                    Start-Sleep -Milliseconds 250
                    continue
                }
            } catch {
                # Corrupted lock file, clear safely
                Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
            }
        }

        # Attempt to acquire lock atomically
        try {
            $lockData = [pscustomobject]@{
                Resource = $ResourceName
                SessionId = $sessionId
                PID = $PID
                Timestamp = (Get-Date -Format 'o')
                User = $env:USERNAME
                Worktree = (Get-RepoRoot)
                Global = [bool]$Global
            } | ConvertTo-Json -Depth 3

            # Create file with exclusive write
            $stream = [IO.File]::Open($lockFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $writer = [IO.StreamWriter]::new($stream, [Text.Encoding]::UTF8)
            $writer.Write($lockData)
            $writer.Flush()
            $writer.Close()
            $stream.Close()

            return [pscustomobject]@{
                Acquired = $true
                Resource = $ResourceName
                LockFile = $lockFile
                SessionId = $sessionId
                Global = [bool]$Global
            }
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }

    return [pscustomobject]@{
        Acquired = $false
        Resource = $ResourceName
        LockFile = $lockFile
        Global = [bool]$Global
        Error = "Timed out after $TimeoutSeconds seconds waiting for lock on $ResourceName."
    }
}

function Release-ResourceLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ResourceName,
        [switch]$Global
    )
    $lockDir = Get-LockDirectory -Global:$Global
    $lockFile = Join-Path $lockDir "$ResourceName.lock"
    if (Test-Path -LiteralPath $lockFile) {
        try {
            $content = Get-Content -LiteralPath $lockFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            # Only remove if this process owns it or process is dead
            if ($content.PID -eq $PID -or -not (Get-Process -Id $content.PID -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-ResourceLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ResourceName,
        [switch]$Global
    )
    $lockDir = Get-LockDirectory -Global:$Global
    $lockFile = Join-Path $lockDir "$ResourceName.lock"
    if (Test-Path -LiteralPath $lockFile) {
        try {
            $content = Get-Content -LiteralPath $lockFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($content.PID -and (Get-Process -Id $content.PID -ErrorAction SilentlyContinue)) {
                return [pscustomobject]@{
                    IsLocked = $true
                    OwnerPID = $content.PID
                    SessionId = $content.SessionId
                    Timestamp = $content.Timestamp
                    Worktree = $content.Worktree
                    Global = [bool]$Global
                }
            }
        } catch {}
    }
    return [pscustomobject]@{ IsLocked = $false }
}

function Get-HostResourceStatus {
    [CmdletBinding()]
    param()

    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalRamMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 0)
    $freeRamMB = [math]::Round($os.FreePhysicalMemory / 1024, 0)
    $isLowMemory = ($freeRamMB -lt 1500)
    $concurrencyLimit = if ($isLowMemory) { 1 } else { [math]::Min(4, [Environment]::ProcessorCount) }

    return [pscustomobject]@{
        TotalRamMB = $totalRamMB
        FreeRamMB = $freeRamMB
        IsLowMemory = $isLowMemory
        RecommendedConcurrency = $concurrencyLimit
        ProcessorCount = [Environment]::ProcessorCount
    }
}

function Invoke-SafeCleanup {
    [CmdletBinding()]
    param(
        [switch]$DryRun = $true,
        [switch]$Force,
        [string[]]$Targets = @('verify-logs', 'disposable-profiles', 'locks')
    )

    $repoRoot = Get-RepoRoot
    $cleanedItems = [Collections.Generic.List[object]]::new()
    $errors = [Collections.Generic.List[string]]::new()

    # Safety validator: path must strictly reside within repo's .buildlog or temporary disposable profile paths
    function Assert-SafePath([string]$Path) {
        $abs = [IO.Path]::GetFullPath($Path)
        $allowedPrefixes = @(
            [IO.Path]::GetFullPath((Join-Path $repoRoot '.buildlog')),
            [IO.Path]::GetFullPath((Join-Path $repoRoot 'build\disposable_profile')),
            [IO.Path]::GetFullPath((Join-Path $repoRoot 'build\test_profile'))
        )
        # Explicit protection against personal appdata paths
        $forbiddenPaths = @(
            [IO.Path]::GetFullPath([Environment]::GetFolderPath('ApplicationData')),
            [IO.Path]::GetFullPath([Environment]::GetFolderPath('LocalApplicationData')),
            [IO.Path]::GetFullPath([Environment]::GetFolderPath('UserProfile')),
            $repoRoot
        )
        foreach ($forbidden in $forbiddenPaths) {
            if ($abs.Equals($forbidden, [StringComparison]::OrdinalIgnoreCase)) {
                throw "CRITICAL SAFETY VIOLATION: Refusing to clean forbidden non-disposable path: $abs"
            }
        }
        $isAllowed = $false
        foreach ($prefix in $allowedPrefixes) {
            if ($abs.StartsWith($prefix + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
                $abs.Equals($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                $isAllowed = $true
                break
            }
        }
        if (-not $isAllowed) {
            throw "CRITICAL SAFETY VIOLATION: Path '$abs' is not within an authorized disposable directory."
        }
        return $abs
    }

    # 1. Clean verify logs older than 24 hours in .buildlog/verify
    if ($Targets -contains 'verify-logs') {
        $verifyDir = Join-Path $repoRoot '.buildlog\verify'
        if (Test-Path -LiteralPath $verifyDir) {
            $threshold = (Get-Date).AddHours(-24)
            $oldLogs = Get-ChildItem -LiteralPath $verifyDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $threshold }
            foreach ($dir in $oldLogs) {
                try {
                    $safe = Assert-SafePath $dir.FullName
                    $cleanedItems.Add([pscustomobject]@{
                        Type = 'VerifyLog'
                        Path = $safe
                        AgeHours = [math]::Round(((Get-Date) - $dir.LastWriteTime).TotalHours, 1)
                        Action = if ($Force) { 'DELETED' } else { 'WOULD_DELETE' }
                    })
                    if ($Force) {
                        Remove-Item -LiteralPath $safe -Recurse -Force -ErrorAction Stop
                    }
                } catch {
                    $errors.Add("Failed cleaning log $($dir.FullName): $_")
                }
            }
        }
    }

    # 2. Clean stale locks
    if ($Targets -contains 'locks') {
        $lockDir = Join-Path $repoRoot '.buildlog\locks'
        if (Test-Path -LiteralPath $lockDir) {
            $lockFiles = Get-ChildItem -LiteralPath $lockDir -Filter *.lock -File -ErrorAction SilentlyContinue
            foreach ($lf in $lockFiles) {
                try {
                    $content = Get-Content -LiteralPath $lf.FullName -Raw | ConvertFrom-Json
                    $isDead = $true
                    if ($content.PID) {
                        $proc = Get-Process -Id $content.PID -ErrorAction SilentlyContinue
                        if ($proc) { $isDead = $false }
                    }
                    if ($isDead) {
                        $safe = Assert-SafePath $lf.FullName
                        $cleanedItems.Add([pscustomobject]@{
                            Type = 'StaleLock'
                            Path = $safe
                            Action = if ($Force) { 'DELETED' } else { 'WOULD_DELETE' }
                        })
                        if ($Force) {
                            Remove-Item -LiteralPath $safe -Force -ErrorAction Stop
                        }
                    }
                } catch {
                    $errors.Add("Error evaluating lock file $($lf.FullName): $_")
                }
            }
        }
    }

    # 3. Clean disposable test profiles
    if ($Targets -contains 'disposable-profiles') {
        $profileDirs = @(
            (Join-Path $repoRoot '.buildlog\profiles'),
            (Join-Path $repoRoot 'build\disposable_profile')
        )
        foreach ($pDir in $profileDirs) {
            if (Test-Path -LiteralPath $pDir) {
                $candidates = Get-ChildItem -LiteralPath $pDir -Directory -ErrorAction SilentlyContinue
                foreach ($c in $candidates) {
                    try {
                        $safe = Assert-SafePath $c.FullName
                        $cleanedItems.Add([pscustomobject]@{
                            Type = 'DisposableProfile'
                            Path = $safe
                            Action = if ($Force) { 'DELETED' } else { 'WOULD_DELETE' }
                        })
                        if ($Force) {
                            # Safely handle junctions vs directories: unlink junctions without deleting targets!
                            $item = Get-Item -LiteralPath $safe
                            if ($item.LinkType) {
                                [IO.Directory]::Delete($safe) # Unlinks junction in .NET
                            } else {
                                Remove-Item -LiteralPath $safe -Recurse -Force -ErrorAction Stop
                            }
                        }
                    } catch {
                        $errors.Add("Error cleaning profile $($c.FullName): $_")
                    }
                }
            }
        }
    }

    $report = [pscustomobject]@{
        DryRun = (-not $Force)
        ItemsCount = $cleanedItems.Count
        Items = @($cleanedItems.ToArray())
        Errors = @($errors.ToArray())
    }

    return $report
}

function ConvertTo-Win32Arg([string]$Arg) {
    if ($null -eq $Arg -or $Arg -eq '') { return '""' }
    if ($Arg -notmatch '[\s"]') { return $Arg }
    $escaped = $Arg -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Test-ProcessInRepoScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]$ProcessInfo,
        [Parameter(Mandatory=$true)][string]$RepoRoot
    )
    if (-not $ProcessInfo) { return $false }
    $normRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
    $repoName = Split-Path -Leaf $normRoot
    $cmd = if ($ProcessInfo.CommandLine) { [string]$ProcessInfo.CommandLine } else { '' }
    $exe = if ($ProcessInfo.ExecutablePath) { [string]$ProcessInfo.ExecutablePath } else { '' }
    # Strictly exclude installed production app directories or unrelated checkouts
    if ($exe -match '\\AppData\\Local\\Programs\\Life Manager\\' -or $cmd -match '\\AppData\\Local\\Programs\\Life Manager\\') {
        return $false
    }
    if ($exe -and $exe.StartsWith($normRoot, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($cmd -and ($cmd.IndexOf($normRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0)) { return $true }
    if ($repoName -and $cmd -match 'database_startup_worker\.dart' -and $cmd.IndexOf($repoName, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    return $false
}

function Get-RepoWorkerDiagnostics {
    [CmdletBinding()]
    param(
        [string]$RepoRoot = (Get-RepoRoot)
    )
    $workers = [Collections.Generic.List[object]]::new()
    try {
        $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match '^(dart|dartvm|flutter|flutter_tester|Todorbit|TodorbitWidget|adb|python|powershell|pwsh|cmd)\.exe$'
        }
        foreach ($p in $procs) {
            if (Test-ProcessInRepoScope -ProcessInfo $p -RepoRoot $RepoRoot) {
                $workers.Add([pscustomobject]@{
                    ProcessId = [int]$p.ProcessId
                    ParentProcessId = [int]$p.ParentProcessId
                    Name = [string]$p.Name
                    ExecutablePath = [string]$p.ExecutablePath
                    CommandLine = if ($p.CommandLine -and $p.CommandLine.Length -gt 240) { $p.CommandLine.Substring(0, 240) + '...' } else { [string]$p.CommandLine }
                })
            }
        }
    } catch {}

    $lockedFiles = [Collections.Generic.List[object]]::new()
    $candidateFiles = [Collections.Generic.List[string]]::new()
    $dllPath = Join-Path $RepoRoot 'build\native_assets\windows\sqlite3.dll'
    if (Test-Path -LiteralPath $dllPath) { $candidateFiles.Add($dllPath) }
    $buildlogDir = Join-Path $RepoRoot '.buildlog'
    if (Test-Path -LiteralPath $buildlogDir) {
        Get-ChildItem -LiteralPath $buildlogDir -Filter '*.sqlite*' -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 20 | ForEach-Object { $candidateFiles.Add($_.FullName) }
    }
    foreach ($cf in $candidateFiles) {
        try {
            $fs = [IO.File]::Open($cf, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            $fs.Close()
        } catch {
            $lockedFiles.Add([pscustomobject]@{
                Path = $cf
                Error = $_.Exception.Message
            })
        }
    }

    return [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        RepoRoot = $RepoRoot
        RepoWorkerCount = $workers.Count
        RepoWorkers = @($workers.ToArray())
        LockedFileCount = $lockedFiles.Count
        LockedFiles = @($lockedFiles.ToArray())
    }
}

function Stop-RepoSubprocessTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][int]$RootProcessId,
        [string]$RepoRoot = (Get-RepoRoot),
        [switch]$OnlyRepoScopedDescendants
    )
    $stopped = [Collections.Generic.List[int]]::new()
    $allProcs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $byPid = @{}
    foreach ($p in $allProcs) { $byPid[[int]$p.ProcessId] = $p }

    # Collect descendant tree from RootProcessId cleanly (bottom-up kill)
    $tree = [Collections.Generic.List[int]]::new()
    $queue = [Collections.Generic.Queue[int]]::new()
    $queue.Enqueue($RootProcessId)
    $seen = [Collections.Generic.HashSet[int]]::new()
    $null = $seen.Add($RootProcessId)

    while ($queue.Count -gt 0) {
        $curr = $queue.Dequeue()
        $tree.Add($curr)
        foreach ($p in $allProcs) {
            $cpid = [int]$p.ProcessId
            if ([int]$p.ParentProcessId -eq $curr -and -not $seen.Contains($cpid)) {
                $null = $seen.Add($cpid)
                $queue.Enqueue($cpid)
            }
        }
    }

    $reversed = @($tree.ToArray())
    [array]::Reverse($reversed)
    foreach ($targetPid in $reversed) {
        if ($targetPid -eq $PID) { continue }
        $info = $byPid[$targetPid]
        if ($info) {
            # Never touch external production app binaries even by accident
            $exe = [string]$info.ExecutablePath
            if ($exe -match '\\AppData\\Local\\Programs\\Life Manager\\') { continue }
            if ($OnlyRepoScopedDescendants -and ($targetPid -ne $RootProcessId) -and -not (Test-ProcessInRepoScope -ProcessInfo $info -RepoRoot $RepoRoot)) {
                continue
            }
        }
        try {
            Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue
            $stopped.Add($targetPid)
        } catch {}
    }
    return @($stopped.ToArray())
}

function Invoke-BoundedProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = (Get-RepoRoot),
        [string]$LogFile = '',
        [int]$TimeoutSeconds = 180,
        [int]$InactivityTimeoutSeconds = 120,
        [string]$RepoRoot = (Get-RepoRoot),
        [hashtable]$Environment = $null
    )

    if (-not $LogFile) {
        $tmpLogDir = Join-Path $RepoRoot '.buildlog\verify\bounded-logs'
        if (-not (Test-Path -LiteralPath $tmpLogDir)) { New-Item -ItemType Directory -Force -Path $tmpLogDir | Out-Null }
        $LogFile = Join-Path $tmpLogDir ("proc-$(Get-Date -Format 'yyyyMMdd-HHmmss-ffff').log")
    } else {
        $parentDir = Split-Path -Parent $LogFile
        if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
            New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
        }
    }

    $ext = [IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    $launchExe = $FilePath
    $psiArgs = (($Arguments | ForEach-Object { ConvertTo-Win32Arg $_ }) -join ' ')
    if ($ext -in @('.bat', '.cmd')) {
        $launchExe = $env:ComSpec
        if (-not $launchExe) { $launchExe = 'C:\WINDOWS\system32\cmd.exe' }
        $cmdLineParts = @((ConvertTo-Win32Arg $FilePath)) + @($Arguments | ForEach-Object { ConvertTo-Win32Arg $_ })
        $psiArgs = '/d /s /c "' + ($cmdLineParts -join ' ') + '"'
    }

    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $launchExe
    $psi.Arguments = $psiArgs
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    if ($Environment) {
        foreach ($key in $Environment.Keys) {
            if ($null -eq $Environment[$key]) {
                if ($psi.EnvironmentVariables.ContainsKey($key)) { $psi.EnvironmentVariables.Remove($key) }
            } else {
                $psi.EnvironmentVariables[$key] = [string]$Environment[$key]
            }
        }
    }

    $logWriter = [IO.StreamWriter]::new($LogFile, $false, [Text.UTF8Encoding]::new($false))
    $syncState = [hashtable]::Synchronized(@{
        LastActivityUtc = [DateTime]::UtcNow
        LineCount = 0
    })

    $proc = [Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $proc.EnableRaisingEvents = $true

    $outSub = Register-ObjectEvent -InputObject $proc -EventName 'OutputDataReceived' -MessageData @{ Writer = $logWriter; State = $syncState } -Action {
        $data = $EventArgs.Data
        if ($null -ne $data) {
            $w = $Event.MessageData.Writer
            $s = $Event.MessageData.State
            [System.Threading.Monitor]::Enter($w)
            try {
                $w.WriteLine($data)
                $s.LastActivityUtc = [DateTime]::UtcNow
                $s.LineCount = [int]$s.LineCount + 1
            } finally {
                [System.Threading.Monitor]::Exit($w)
            }
        }
    }
    $errSub = Register-ObjectEvent -InputObject $proc -EventName 'ErrorDataReceived' -MessageData @{ Writer = $logWriter; State = $syncState } -Action {
        $data = $EventArgs.Data
        if ($null -ne $data) {
            $w = $Event.MessageData.Writer
            $s = $Event.MessageData.State
            [System.Threading.Monitor]::Enter($w)
            try {
                $w.WriteLine($data)
                $s.LastActivityUtc = [DateTime]::UtcNow
                $s.LineCount = [int]$s.LineCount + 1
            } finally {
                [System.Threading.Monitor]::Exit($w)
            }
        }
    }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    $stalled = $false
    $diagSnapshot = $null
    $lastCpuMs = 0.0
    $exitCode = 1

    try {
        if (-not $proc.Start()) {
            throw "Failed to start process: $launchExe"
        }
        try { $proc.StandardInput.Close() } catch {}
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        while (-not $proc.WaitForExit(250)) {
            $nowUtc = [DateTime]::UtcNow
            try {
                $cpuMs = $proc.TotalProcessorTime.TotalMilliseconds
                if ($cpuMs -gt $lastCpuMs + 5.0) {
                    $lastCpuMs = $cpuMs
                    $syncState.LastActivityUtc = $nowUtc
                }
            } catch {}

            $elapsedSec = $sw.Elapsed.TotalSeconds
            $idleSec = ($nowUtc - [DateTime]$syncState.LastActivityUtc).TotalSeconds

            if ($TimeoutSeconds -gt 0 -and $elapsedSec -ge $TimeoutSeconds) {
                $timedOut = $true
                break
            }
            if ($InactivityTimeoutSeconds -gt 0 -and $idleSec -ge $InactivityTimeoutSeconds) {
                $stalled = $true
                break
            }
        }

        if ($timedOut -or $stalled) {
            $reason = if ($stalled) { "INACTIVITY STALL (${InactivityTimeoutSeconds}s idle)" } else { "EXECUTION TIMEOUT (${TimeoutSeconds}s limit)" }
            $diagSnapshot = Get-RepoWorkerDiagnostics -RepoRoot $RepoRoot
            $killedPids = Stop-RepoSubprocessTree -RootProcessId $proc.Id -RepoRoot $RepoRoot
            try { $proc.WaitForExit(2000) | Out-Null } catch {}
            $exitCode = 124
            [System.Threading.Monitor]::Enter($logWriter)
            try {
                $logWriter.WriteLine("")
                $logWriter.WriteLine("[TDAT-WATCHDOG] Process terminated due to $reason. RootPID=$($proc.Id) KilledPIDs=$($killedPids -join ',')")
                if ($diagSnapshot.LockedFileCount -gt 0) {
                    $logWriter.WriteLine("[TDAT-WATCHDOG] Locked files detected: $(($diagSnapshot.LockedFiles | ForEach-Object { $_.Path }) -join '; ')")
                }
            } finally {
                [System.Threading.Monitor]::Exit($logWriter)
            }
        } else {
            # Bound post-exit async stream drain so surviving grandchildren inheriting pipes cannot hang forever
            try { $null = $proc.WaitForExit(2000) } catch {}
            $exitCode = $proc.ExitCode
        }
    } finally {
        $sw.Stop()
        try { $proc.CancelOutputRead() } catch {}
        try { $proc.CancelErrorRead() } catch {}
        Start-Sleep -Milliseconds 100
        Unregister-Event -SourceIdentifier $outSub.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $errSub.Name -ErrorAction SilentlyContinue
        Remove-Job -Id $outSub.Id -Force -ErrorAction SilentlyContinue
        Remove-Job -Id $errSub.Id -Force -ErrorAction SilentlyContinue
        try {
            $logWriter.Flush()
            $logWriter.Close()
            $logWriter.Dispose()
        } catch {}
        try { $proc.Dispose() } catch {}
    }

    $rawOutput = if (Test-Path -LiteralPath $LogFile) { Get-Content -LiteralPath $LogFile -Raw -ErrorAction SilentlyContinue } else { '' }
    $status = if ($stalled) { 'STALLED' } elseif ($timedOut) { 'TIMEOUT' } elseif ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }

    return [pscustomobject]@{
        Status = $status
        ExitCode = $exitCode
        TimedOut = $timedOut
        Stalled = $stalled
        DurationSeconds = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        LogFile = $LogFile
        Output = $rawOutput
        Diagnostics = $diagSnapshot
    }
}

Export-ModuleMember -Function Get-TodorbitSessionId, Acquire-ResourceLock, Release-ResourceLock, Test-ResourceLock, Get-HostResourceStatus, Invoke-SafeCleanup, Get-RepoRoot, Get-LockDirectory, Get-RepoWorkerDiagnostics, Stop-RepoSubprocessTree, Invoke-BoundedProcess
