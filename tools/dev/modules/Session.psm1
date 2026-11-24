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

function Acquire-ResourceLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ResourceName,
        [int]$TimeoutSeconds = 10,
        [int]$LockTtlSeconds = 1800
    )

    $repoRoot = Get-RepoRoot
    $lockDir = Join-Path $repoRoot '.buildlog\locks'
    if (-not (Test-Path -LiteralPath $lockDir)) {
        New-Item -ItemType Directory -Force -Path $lockDir | Out-Null
    }

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
                    Start-Sleep -Milliseconds 500
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
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }

    return [pscustomobject]@{
        Acquired = $false
        Resource = $ResourceName
        LockFile = $lockFile
        Error = "Timed out after $TimeoutSeconds seconds waiting for lock on $ResourceName."
    }
}

function Release-ResourceLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ResourceName
    )
    $repoRoot = Get-RepoRoot
    $lockFile = Join-Path $repoRoot ".buildlog\locks\$ResourceName.lock"
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
        [Parameter(Mandatory=$true)][string]$ResourceName
    )
    $repoRoot = Get-RepoRoot
    $lockFile = Join-Path $repoRoot ".buildlog\locks\$ResourceName.lock"
    if (Test-Path -LiteralPath $lockFile) {
        try {
            $content = Get-Content -LiteralPath $lockFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
            if ($content.PID -and (Get-Process -Id $content.PID -ErrorAction SilentlyContinue)) {
                return [pscustomobject]@{
                    IsLocked = $true
                    OwnerPID = $content.PID
                    SessionId = $content.SessionId
                    Timestamp = $content.Timestamp
                }
            }
        } catch {}
    }
    return [pscustomobject]@{ IsLocked = $false }
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

Export-ModuleMember -Function Get-TodorbitSessionId, Acquire-ResourceLock, Release-ResourceLock, Test-ResourceLock, Invoke-SafeCleanup
