# Evidence.psm1 - Todorbit Source-Aware Verification Evidence Reuse & Receipts
# Implements content-addressed 4-fingerprint hashing, evidence caching, and diagnostics.
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Get-EvidenceDir {
    $dir = Join-Path (Get-RepoRoot) '.buildlog\evidence'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    return $dir
}

function Get-FileContentHash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '0000000000000000' }
    $sha256 = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    $hashBytes = $sha256.ComputeHash($stream)
    $stream.Close()
    $sha256.Dispose()
    return -join ($hashBytes | ForEach-Object { '{0:x2}' -f $_ })
}

$script:CachedToolchainHash = $null

function Get-ToolchainHash {
    if ($script:CachedToolchainHash) {
        return $script:CachedToolchainHash
    }

    # Ensure environment is configured
    if (Get-Command 'Ensure-TodorbitEnvironment' -ErrorAction SilentlyContinue) {
        Ensure-TodorbitEnvironment
    }

    $flutterExe = if (Get-Command 'Resolve-TodorbitTool' -ErrorAction SilentlyContinue) {
        Resolve-TodorbitTool 'flutter'
    } else { 'flutter.bat' }

    $dartExe = if (Get-Command 'Resolve-TodorbitTool' -ErrorAction SilentlyContinue) {
        Resolve-TodorbitTool 'dart'
    } else { 'dart.exe' }

    $flutterVer = 'unknown'
    $dartVer = 'unknown'
    try {
        $flutterVer = (& $flutterExe --version 2>$null | Select-Object -First 1)
        $dartVer = (& $dartExe --version 2>&1 | Select-Object -First 1)
    } catch {}
    $os = [Environment]::OSVersion.VersionString
    $combined = "$flutterVer|$dartVer|$os"
    $bytes = [Text.Encoding]::UTF8.GetBytes($combined)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    $hash = -join ($sha256.ComputeHash($bytes) | ForEach-Object { '{0:x2}' -f $_ })
    $sha256.Dispose()

    $script:CachedToolchainHash = $hash
    return $hash
}

function Get-TestCompositeFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TestPath,
        [string[]]$SourcePaths = @()
    )

    $repoRoot = Get-RepoRoot

    # 1. Test implementation hash
    $absTest = Join-Path $repoRoot ($TestPath.Replace('/', '\'))
    $testHash = Get-FileContentHash $absTest

    # 2. Source code content hash
    $sourceHashes = [Collections.Generic.List[string]]::new()
    foreach ($sp in $SourcePaths) {
        $absSource = Join-Path $repoRoot ($sp.Replace('/', '\'))
        if (Test-Path -LiteralPath $absSource) {
            $sourceHashes.Add((Get-FileContentHash $absSource))
        }
    }
    $sourceCombined = $sourceHashes -join ':'

    # 3. Transitive dependency lockfile hash (pubspec.lock)
    $lockfilePath = Join-Path $repoRoot 'pubspec.lock'
    $lockHash = Get-FileContentHash $lockfilePath

    # 4. Toolchain / environment hash
    $toolchainHash = Get-ToolchainHash

    # Composite SHA-256
    $compositeRaw = "$TestPath|$testHash|$sourceCombined|$lockHash|$toolchainHash"
    $bytes = [Text.Encoding]::UTF8.GetBytes($compositeRaw)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    $compositeHash = -join ($sha256.ComputeHash($bytes) | ForEach-Object { '{0:x2}' -f $_ })
    $sha256.Dispose()

    return [pscustomobject]@{
        CompositeFingerprint = $compositeHash
        TestPath = $TestPath
        TestHash = $testHash
        SourceHashes = $sourceHashes.ToArray()
        LockfileHash = $lockHash
        ToolchainHash = $toolchainHash
    }
}

function Get-EvidenceRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Fingerprint
    )
    $evidenceDir = Get-EvidenceDir
    $evidenceFile = Join-Path $evidenceDir "$Fingerprint.json"
    if (Test-Path -LiteralPath $evidenceFile) {
        try {
            $record = Get-Content -LiteralPath $evidenceFile -Raw -ErrorAction Stop | ConvertFrom-Json
            # Evidence validation: must be PASS and non-corrupt
            if ($record.Fingerprint -eq $Fingerprint -and $record.Outcome -eq 'PASS') {
                return $record
            }
        } catch {
            # Corrupted evidence, remove
            Remove-Item -LiteralPath $evidenceFile -Force -ErrorAction SilentlyContinue
        }
    }
    return $null
}

function Save-EvidenceRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TestPath,
        [string[]]$SourcePaths = @(),
        [Parameter(Mandatory=$true)][ValidateSet('PASS','FAIL','FLAKY','BLOCKED','TIMEOUT','SKIPPED')][string]$Outcome,
        [double]$DurationSeconds = 0.0,
        [string]$LogExcerpt = '',
        [string]$LogPath = ''
    )

    $fpInfo = Get-TestCompositeFingerprint -TestPath $TestPath -SourcePaths $SourcePaths
    $fingerprint = $fpInfo.CompositeFingerprint

    # Redact sensitive paths or tokens from log excerpt if any
    $sanitizedExcerpt = $LogExcerpt
    if ($sanitizedExcerpt) {
        $sanitizedExcerpt = $sanitizedExcerpt -replace '(?i)(bearer\s+[a-zA-Z0-9_\-\.]+)', 'Bearer [REDACTED]'
        $sanitizedExcerpt = $sanitizedExcerpt -replace '(?i)(key\s*=\s*[a-zA-Z0-9_\-]+)', 'key=[REDACTED]'
        $sanitizedExcerpt = $sanitizedExcerpt -replace '(?i)(password\s*=\s*\S+)', 'password=[REDACTED]'
    }

    $record = [pscustomobject]@{
        Fingerprint = $fingerprint
        TestPath = $TestPath
        Outcome = $Outcome
        DurationSeconds = $DurationSeconds
        Timestamp = (Get-Date -Format 'o')
        TestHash = $fpInfo.TestHash
        LockfileHash = $fpInfo.LockfileHash
        ToolchainHash = $fpInfo.ToolchainHash
        LogExcerpt = $sanitizedExcerpt
        LogPath = $LogPath
    }

    # Only save passing results into reusable evidence cache (failures are never cached as passes)
    if ($Outcome -eq 'PASS') {
        $evidenceDir = Get-EvidenceDir
        $evidenceFile = Join-Path $evidenceDir "$fingerprint.json"
        $json = $record | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText($evidenceFile, $json, [Text.Encoding]::UTF8)
    }

    return $record
}

function Clear-StaleEvidence {
    [CmdletBinding()]
    param(
        [int]$MaxAgeDays = 7
    )
    $evidenceDir = Get-EvidenceDir
    $threshold = (Get-Date).AddDays(-$MaxAgeDays)
    $files = Get-ChildItem -LiteralPath $evidenceDir -Filter *.json -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $threshold }
    $count = 0
    foreach ($f in $files) {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        $count++
    }
    return $count
}

Export-ModuleMember -Function Get-TestCompositeFingerprint, Get-EvidenceRecord, Save-EvidenceRecord, Clear-StaleEvidence
