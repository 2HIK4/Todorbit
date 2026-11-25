# Evidence.psm1 - Todorbit Source-Aware Verification Evidence Reuse & Receipts
# Implements content-addressed 4-fingerprint hashing, transitive dependency discovery,
# evidence caching, corruption protection, and verification receipts.
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Get-EvidenceDir {
    if ($env:TODORBIT_EVIDENCE_DIR) {
        $dir = $env:TODORBIT_EVIDENCE_DIR
    } else {
        $dir = Join-Path (Get-RepoRoot) '.buildlog\evidence'
    }
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    return $dir
}

function Get-FileContentHash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '0000000000000000' }
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $stream = [IO.File]::OpenRead($Path)
        $hashBytes = $sha256.ComputeHash($stream)
        $stream.Close()
        return -join ($hashBytes | ForEach-Object { '{0:x2}' -f $_ })
    } catch {
        return '0000000000000000'
    } finally {
        $sha256.Dispose()
    }
}

$script:CachedToolchainHash = $null

function Get-ToolchainHash {
    if ($script:CachedToolchainHash) {
        return $script:CachedToolchainHash
    }

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

function Get-VerificationConfigHash {
    $repoRoot = Get-RepoRoot
    $configFiles = @(
        'tools\dev\verify.ps1',
        'tools\dev\dev.ps1',
        'tools\dev\features.json',
        'tools\dev\modules\Evidence.psm1',
        'tools\dev\modules\Impact.psm1',
        'tools\dev\modules\Registry.psm1'
    )
    $hashes = [Collections.Generic.List[string]]::new()
    foreach ($cf in $configFiles) {
        $abs = Join-Path $repoRoot $cf
        if (Test-Path -LiteralPath $abs) {
            $hashes.Add((Get-FileContentHash $abs))
        }
    }
    # Hash normalized registry test metadata (excluding volatile GeneratedAt timestamp)
    # so `dev registry --refresh` preserves valid cached evidence while eligibility/tier changes invalidate it.
    $regPath = Join-Path $repoRoot 'tools\dev\registry.json'
    if (Test-Path -LiteralPath $regPath) {
        try {
            $regObj = Get-Content -LiteralPath $regPath -Raw | ConvertFrom-Json
            $normalizedTests = @($regObj.Tests | Sort-Object Path | ForEach-Object { "$($_.Path)|$($_.Type)|$($_.Tier)|$($_.EvidenceReuse)" }) -join "`n"
            $hashes.Add($normalizedTests)
        } catch {
            $hashes.Add((Get-FileContentHash $regPath))
        }
    }
    $combined = $hashes -join ':'
    $bytes = [Text.Encoding]::UTF8.GetBytes($combined)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    $res = -join ($sha256.ComputeHash($bytes) | ForEach-Object { '{0:x2}' -f $_ })
    $sha256.Dispose()
    return $res
}

function Get-EnvironmentFingerprint {
    $envKeys = @(
        'TODORBIT_PROFILE_JOURNEYS',
        'TODORBIT_PRIVATE_DRIVE_TEST',
        'TODORBIT_GOOGLE_DRIVE_CONFIG',
        'TODORBIT_NATIVE_SERVICE_EXE',
        'TODORBIT_REFINEMENT_EXE',
        'UIUX_CAPTURE_DIR',
        'CI',
        'FLUTTER_TEST'
    )
    $pairs = [Collections.Generic.List[string]]::new()
    foreach ($k in $envKeys) {
        $val = [Environment]::GetEnvironmentVariable($k, 'Process')
        if (-not [string]::IsNullOrEmpty($val)) {
            $pairs.Add("$k=$val")
        }
    }
    $raw = $pairs -join ';'
    $bytes = [Text.Encoding]::UTF8.GetBytes($raw)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    $res = -join ($sha256.ComputeHash($bytes) | ForEach-Object { '{0:x2}' -f $_ })
    $sha256.Dispose()
    return $res
}

function Get-DartImports([string]$FilePath, [string]$RepoRoot) {
    if (-not (Test-Path -LiteralPath $FilePath)) { return @() }
    $resolved = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $fileDir = [IO.Path]::GetDirectoryName($FilePath)
    $rawText = Get-Content -LiteralPath $FilePath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($rawText)) { return @() }

    # Strip single-line comments to avoid false matches in comments, while supporting multi-line import/export/part statements
    $noComments = [regex]::Replace($rawText, '(?m)//.*$', '')
    $directiveMatches = [regex]::Matches($noComments, "(?ms)(?:^|;|\r|\n)\s*(?:import|export|part)\s+(?:['""]([^'""]+)['""])")
    foreach ($m in $directiveMatches) {
        $uri = $m.Groups[1].Value
        if ($uri.StartsWith('package:life_manager/')) {
            $rel = 'lib/' + $uri.Substring('package:life_manager/'.Length)
            $abs = Join-Path $RepoRoot ($rel.Replace('/', '\'))
            if (Test-Path -LiteralPath $abs) {
                $resolved.Add($abs) | Out-Null
            }
        } elseif ($uri -notmatch '^dart:' -and $uri -notmatch '^package:') {
            try {
                $abs = [IO.Path]::GetFullPath((Join-Path $fileDir $uri))
                if ($abs.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $abs)) {
                    $resolved.Add($abs) | Out-Null
                }
            } catch {}
        }
    }
    return @($resolved)
}

function Resolve-AllTransitiveDependencies([string[]]$FilePaths, [string]$RepoRoot, [int]$MaxDepth = 2500) {
    $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $queue = [Collections.Generic.Queue[string]]::new()
    foreach ($fp in $FilePaths) {
        $abs = if ([IO.Path]::IsPathRooted($fp)) { $fp } else { Join-Path $RepoRoot ($fp.Replace('/', '\')) }
        if (Test-Path -LiteralPath $abs) {
            if ($visited.Add($abs)) {
                $queue.Enqueue($abs)
            }
        }
    }
    $processed = 0
    while ($queue.Count -gt 0 -and $processed -lt $MaxDepth) {
        $current = $queue.Dequeue()
        $processed++
        if ($current.EndsWith('.dart', [StringComparison]::OrdinalIgnoreCase)) {
            $imports = Get-DartImports -FilePath $current -RepoRoot $RepoRoot
            foreach ($imp in $imports) {
                if ($visited.Add($imp)) {
                    $queue.Enqueue($imp)
                }
            }
        }
    }
    if ($queue.Count -gt 0) {
        # Fail-closed signal: if dependency graph exceeds safety limit, do not silently omit dependencies
        $visited.Add('__TRUNCATED_DEPENDENCY_GRAPH__') | Out-Null
    }
    return @($visited)
}

function Test-IsTestEligibleForReuse([string]$TestPath) {
    $norm = $TestPath.Replace('\', '/')
    # Non-Dart tests (Python, scripts, integration tests) or side-effect/env-gated tests:
    # disable caching when dependencies cannot be established safely via Dart import graph.
    if (-not $norm.EndsWith('.dart', [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    if ($norm -match '^integration_test/') {
        return $false
    }
    if ($norm -match 'runtime_workflow_journey_test\.dart$|startup_recovery_journeys_test\.dart$|resource_journeys_test\.dart$|native_widget_launch_integration_test\.dart$|performance_benchmark_test\.dart$|lab_render_test\.dart$|published_update_discovery_test\.dart$') {
        return $false
    }
    if (-not [string]::IsNullOrEmpty($env:UIUX_CAPTURE_DIR)) {
        return $false
    }

    $repoRoot = Get-RepoRoot
    $registryPath = Join-Path $repoRoot 'tools\dev\registry.json'
    if (Test-Path -LiteralPath $registryPath) {
        try {
            $reg = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
            foreach ($t in $reg.Tests) {
                if ($t.Path -eq $norm) {
                    if ($t.EvidenceReuse -eq 'Ineligible' -or $t.deterministic -eq $false) {
                        return $false
                    }
                    return $true
                }
            }
        } catch {}
    }
    return $true
}

function Get-TestCompositeFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TestPath,
        [string[]]$SourcePaths = @(),
        [string]$Arguments = '',
        [switch]$IncludeTransitive = $true
    )

    $repoRoot = Get-RepoRoot

    # 1. Test implementation hash
    $absTest = Join-Path $repoRoot ($TestPath.Replace('/', '\'))
    $testHash = Get-FileContentHash $absTest

    # 2. Source code content hashes (including transitive Dart dependencies)
    $allFilesToHash = [Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $absTest) {
        $allFilesToHash.Add($absTest)
    }
    $sourceHashes = [Collections.Generic.List[string]]::new()
    foreach ($sp in $SourcePaths) {
        $absSource = Join-Path $repoRoot ($sp.Replace('/', '\'))
        if (Test-Path -LiteralPath $absSource) {
            $allFilesToHash.Add($absSource)
        } else {
            $rel = $sp.Replace('\', '/')
            $sourceHashes.Add("$($rel):MISSING_OR_DELETED")
        }
    }

    if ($IncludeTransitive) {
        $resolvedDeps = Resolve-AllTransitiveDependencies -FilePaths $allFilesToHash.ToArray() -RepoRoot $repoRoot
    } else {
        $resolvedDeps = $allFilesToHash.ToArray()
    }

    $dependenciesTruncated = $false
    $filteredDeps = [Collections.Generic.List[string]]::new()
    foreach ($dep in $resolvedDeps) {
        if ($dep -eq '__TRUNCATED_DEPENDENCY_GRAPH__') {
            $dependenciesTruncated = $true
        } else {
            $filteredDeps.Add($dep)
        }
    }

    # Sort files deterministically for stable hashing
    $sortedDeps = $filteredDeps.ToArray() | Sort-Object
    foreach ($depFile in $sortedDeps) {
        $rel = $depFile.Substring($repoRoot.Length).TrimStart('\', '/').Replace('\', '/')
        $hash = Get-FileContentHash $depFile
        $sourceHashes.Add("$($rel):$($hash)")
    }
    $sourceCombined = $sourceHashes -join ';'

    # 3. Transitive dependency lockfile hash (pubspec.lock)
    $lockfilePath = Join-Path $repoRoot 'pubspec.lock'
    $lockHash = Get-FileContentHash $lockfilePath

    # 4. Toolchain / environment hash
    $toolchainHash = Get-ToolchainHash
    $envHash = Get-EnvironmentFingerprint

    # 5. Verification config and script hash
    $configHash = Get-VerificationConfigHash

    # Composite SHA-256
    $compositeRaw = "$TestPath|$testHash|$sourceCombined|$lockHash|$toolchainHash|$envHash|$configHash|$Arguments"
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
        EnvironmentHash = $envHash
        ConfigHash = $configHash
        Arguments = $Arguments
        DependenciesCount = $sortedDeps.Count
        DependenciesTruncated = $dependenciesTruncated
    }
}

function Get-EvidenceRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Fingerprint,
        [switch]$ForceFresh
    )
    if ($ForceFresh) {
        return $null
    }

    $evidenceDir = Get-EvidenceDir
    $evidenceFile = Join-Path $evidenceDir "$Fingerprint.json"
    if (Test-Path -LiteralPath $evidenceFile) {
        try {
            $content = Get-Content -LiteralPath $evidenceFile -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($content)) {
                Remove-Item -LiteralPath $evidenceFile -Force -ErrorAction SilentlyContinue
                return $null
            }
            $record = $content | ConvertFrom-Json

            # Schema and integrity verification:
            # 1. Fingerprint must match exact filename
            # 2. Outcome must be strictly PASS
            # 3. SchemaVersion must be 2
            # 4. TestPath must be non-empty
            if ($record.Fingerprint -eq $Fingerprint -and
                $record.Outcome -eq 'PASS' -and
                $record.SchemaVersion -eq 2 -and
                -not [string]::IsNullOrWhiteSpace($record.TestPath)) {
                # Check eligibility
                if (-not (Test-IsTestEligibleForReuse -TestPath $record.TestPath)) {
                    return $null
                }
                return $record
            } else {
                # Malformed or non-passing record in cache: purge
                Remove-Item -LiteralPath $evidenceFile -Force -ErrorAction SilentlyContinue
            }
        } catch {
            # Corrupted JSON: purge immediately
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
        [string]$LogPath = '',
        [string]$Arguments = '',
        [string]$PreRunFingerprint = '',
        [switch]$ForceFresh
    )

    $fpInfo = Get-TestCompositeFingerprint -TestPath $TestPath -SourcePaths $SourcePaths -Arguments $Arguments
    $fingerprint = $fpInfo.CompositeFingerprint

    # Detect source/test/config mutation during test execution
    $mutatedDuringRun = (-not [string]::IsNullOrWhiteSpace($PreRunFingerprint)) -and ($fingerprint -ne $PreRunFingerprint)

    # Redact sensitive tokens from log excerpt
    $sanitizedExcerpt = $LogExcerpt
    if ($sanitizedExcerpt) {
        $sanitizedExcerpt = $sanitizedExcerpt -replace '(?i)(bearer\s+[a-zA-Z0-9_\-\.]+)', 'Bearer [REDACTED]'
        $sanitizedExcerpt = $sanitizedExcerpt -replace '(?i)(key\s*=\s*[a-zA-Z0-9_\-]+)', 'key=[REDACTED]'
        $sanitizedExcerpt = $sanitizedExcerpt -replace '(?i)(password\s*=\s*\S+)', 'password=[REDACTED]'
    }

    $cacheSkippedReason = ''
    if ($mutatedDuringRun) {
        $cacheSkippedReason = 'SourceModifiedDuringExecution'
    } elseif ($fpInfo.DependenciesTruncated) {
        $cacheSkippedReason = 'DependencyGraphTruncated'
    } elseif ($ForceFresh) {
        $cacheSkippedReason = 'ForceFresh'
    } elseif (-not (Test-IsTestEligibleForReuse -TestPath $TestPath)) {
        $cacheSkippedReason = 'IneligibleForReuse'
    }

    $record = [pscustomobject]@{
        SchemaVersion = 2
        Fingerprint = $fingerprint
        TestPath = $TestPath
        Outcome = $Outcome
        DurationSeconds = $DurationSeconds
        Timestamp = (Get-Date -Format 'o')
        TestHash = $fpInfo.TestHash
        LockfileHash = $fpInfo.LockfileHash
        ToolchainHash = $fpInfo.ToolchainHash
        EnvironmentHash = $fpInfo.EnvironmentHash
        ConfigHash = $fpInfo.ConfigHash
        Arguments = $Arguments
        DependenciesCount = $fpInfo.DependenciesCount
        DependenciesTruncated = $fpInfo.DependenciesTruncated
        CacheSaved = $false
        CacheSkippedReason = $cacheSkippedReason
        LogExcerpt = $sanitizedExcerpt
        LogPath = $LogPath
    }

    # STRICT CACHING RULES:
    # 1. ONLY 'PASS' outcomes are ever saved into the reusable evidence cache.
    # 2. FAIL, FLAKY, BLOCKED, TIMEOUT, and SKIPPED outcomes are NEVER cached as passing evidence.
    # 3. Tests marked Ineligible or nondeterministic are never cached.
    # 4. Mandatory fresh runs ($ForceFresh) bypass cache writing.
    # 5. Any source/test/config modification during test execution or truncated dependency graph prevents caching.
    if ($Outcome -eq 'PASS' -and -not $ForceFresh -and -not $mutatedDuringRun -and -not $fpInfo.DependenciesTruncated) {
        if (Test-IsTestEligibleForReuse -TestPath $TestPath) {
            $evidenceDir = Get-EvidenceDir
            $evidenceFile = Join-Path $evidenceDir "$fingerprint.json"
            $tempFile = Join-Path $evidenceDir "$fingerprint.tmp.$([Guid]::NewGuid().ToString('N'))"
            $record.CacheSaved = $true
            $json = $record | ConvertTo-Json -Depth 6
            # Atomic write to prevent partially-written corrupted files
            [IO.File]::WriteAllText($tempFile, $json, [Text.UTF8Encoding]::new($false))
            Move-Item -LiteralPath $tempFile -Destination $evidenceFile -Force
        }
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

Export-ModuleMember -Function Get-TestCompositeFingerprint, Get-EvidenceRecord, Save-EvidenceRecord, Clear-StaleEvidence, Get-DartImports, Resolve-AllTransitiveDependencies, Test-IsTestEligibleForReuse, Get-RepoRoot, Get-EvidenceDir, Get-VerificationConfigHash, Get-ToolchainHash, Get-EnvironmentFingerprint
