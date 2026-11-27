# Impact.psm1 - Todorbit Intelligent Impact Analysis & Verification Planning
# Resolves changed files, reverse Dart dependencies, features, critical boundaries,
# conservative fallbacks, and real Verification Shadow Mode.
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $cwdTop = (& git rev-parse --show-toplevel 2>$null)
    if ($cwdTop -and $LASTEXITCODE -eq 0) {
        return (Resolve-Path ($cwdTop | Out-String).Trim()).Path
    }
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function ConvertFrom-GitPorcelainPath([string]$RawPath) {
    $p = $RawPath.Trim()
    if ($p.StartsWith('"') -and $p.EndsWith('"') -and $p.Length -ge 2) {
        $p = $p.Substring(1, $p.Length - 2)
        $p = $p -replace '\\"', '"' -replace '\\\\', '\'
    }
    return $p.Replace('\', '/')
}

function Get-ChangedRepositoryFiles {
    [CmdletBinding()]
    param(
        [string]$BaselineRef = ''
    )
    $changed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    $repoRoot = Get-RepoRoot

    # 1. Unstaged, staged, untracked (-uall), deleted, and renamed git changes
    $statusLines = & git -C $repoRoot status --porcelain -uall 2>$null
    if ($statusLines) {
        foreach ($line in $statusLines) {
            if ($line.Length -ge 4) {
                $raw = $line.Substring(3).Trim()
                if ($raw -match '^(.+?)\s+->\s+(.+)$') {
                    # Record BOTH old and new paths on renames so mappings/dependents on either side trigger
                    $oldPath = ConvertFrom-GitPorcelainPath $Matches[1]
                    $newPath = ConvertFrom-GitPorcelainPath $Matches[2]
                    foreach ($rp in @($oldPath, $newPath)) {
                        if ($rp -and $rp -notmatch '^\.buildlog' -and $rp -notmatch '^build/' -and $rp -notmatch '^\.dart_tool') {
                            $changed.Add($rp) | Out-Null
                        }
                    }
                } else {
                    $path = ConvertFrom-GitPorcelainPath $raw
                    if ($path -and $path -notmatch '^\.buildlog' -and $path -notmatch '^build/' -and $path -notmatch '^\.dart_tool') {
                        $changed.Add($path) | Out-Null
                    }
                }
            }
        }
    }

    # 2. Baseline comparison: union committed branch diff with working tree unless BaselineRef is explicitly 'HEAD'
    $targetBaseline = $BaselineRef
    if (-not $targetBaseline) {
        try {
            $upstream = (& git -C $repoRoot rev-parse --abbrev-ref '@{u}' 2>$null)
            if ($upstream -and $LASTEXITCODE -eq 0) {
                $targetBaseline = ($upstream | Out-String).Trim()
            }
        } catch {}

        if (-not $targetBaseline) {
            try {
                $symHead = (& git -C $repoRoot symbolic-ref --short refs/remotes/origin/HEAD 2>$null)
                if ($symHead -and $LASTEXITCODE -eq 0) {
                    $mb = (& git -C $repoRoot merge-base HEAD ($symHead | Out-String).Trim() 2>$null)
                    if ($mb -and $LASTEXITCODE -eq 0) { $targetBaseline = ($mb | Out-String).Trim() }
                }
            } catch {}
        }
        if (-not $targetBaseline) {
            foreach ($candidate in @('origin/main', 'main', 'HEAD~1')) {
                try {
                    $mb = (& git -C $repoRoot merge-base HEAD $candidate 2>$null)
                    if ($mb -and $LASTEXITCODE -eq 0) {
                        $targetBaseline = ($mb | Out-String).Trim()
                        break
                    }
                } catch {}
            }
        }
    }

    if ($targetBaseline -and $targetBaseline -ne 'HEAD') {
        $diffFiles = & git -C $repoRoot diff --name-only "$targetBaseline...HEAD" 2>$null
        if ($diffFiles) {
            foreach ($df in $diffFiles) {
                $dfClean = ConvertFrom-GitPorcelainPath $df
                if ($dfClean -and $dfClean -notmatch '^\.buildlog' -and $dfClean -notmatch '^build/' -and $dfClean -notmatch '^\.dart_tool') {
                    $changed.Add($dfClean) | Out-Null
                }
            }
        }
    }

    return @($changed)
}

function Get-ReverseDartDependencyMap {
    [CmdletBinding()]
    param([string]$RepoRoot)

    $reverseMap = [Collections.Generic.Dictionary[string, Collections.Generic.HashSet[string]]]::new([StringComparer]::OrdinalIgnoreCase)
    $allTestSuites = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    $searchRoots = @('lib', 'test', 'integration_test')
    foreach ($rootName in $searchRoots) {
        $dirPath = Join-Path $RepoRoot $rootName
        if (-not (Test-Path -LiteralPath $dirPath)) { continue }
        $dartFiles = Get-ChildItem -Path $dirPath -Recurse -File -Filter '*.dart' -ErrorAction SilentlyContinue
        foreach ($df in $dartFiles) {
            $rel = ($df.FullName.Substring($RepoRoot.Length + 1)).Replace('\', '/')
            if ($rel -match '^(?:test/.*_test\.dart|integration_test/.*\.dart)$') {
                $allTestSuites.Add($rel) | Out-Null
            }
            $raw = Get-Content -LiteralPath $df.FullName -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }
            $noComments = [regex]::Replace($raw, '(?m)//.*$', '')
            $fileDir = $df.DirectoryName
            $matches = [regex]::Matches($noComments, "(?ms)(?:^|;|\r|\n)\s*(?:import|export|part)\s+(?:['""]([^'""]+)['""])")
            foreach ($m in $matches) {
                $uri = $m.Groups[1].Value
                $targetRel = $null
                if ($uri.StartsWith('package:life_manager/')) {
                    $targetRel = 'lib/' + $uri.Substring('package:life_manager/'.Length)
                } elseif ($uri -notmatch '^dart:' -and $uri -notmatch '^package:') {
                    try {
                        $abs = [IO.Path]::GetFullPath((Join-Path $fileDir $uri))
                        if ($abs.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
                            $targetRel = ($abs.Substring($RepoRoot.Length + 1)).Replace('\', '/')
                        }
                    } catch {}
                }
                if ($targetRel) {
                    if (-not $reverseMap.ContainsKey($targetRel)) {
                        $reverseMap[$targetRel] = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                    }
                    $reverseMap[$targetRel].Add($rel) | Out-Null
                }
            }
        }
    }

    return [pscustomobject]@{
        ReverseMap = $reverseMap
        TestSuites = $allTestSuites
    }
}

function Resolve-ImpactedTestsFromReverseDeps {
    param(
        [string]$ChangedRelPath,
        $ReverseGraph
    )
    $impactedTests = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if (-not $ReverseGraph -or -not $ReverseGraph.ReverseMap.ContainsKey($ChangedRelPath)) {
        return @()
    }
    $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $queue = [Collections.Generic.Queue[string]]::new()
    $visited.Add($ChangedRelPath) | Out-Null
    $queue.Enqueue($ChangedRelPath)
    while ($queue.Count -gt 0) {
        $curr = $queue.Dequeue()
        if ($ReverseGraph.TestSuites.Contains($curr)) {
            $impactedTests.Add($curr) | Out-Null
        }
        if ($ReverseGraph.ReverseMap.ContainsKey($curr)) {
            foreach ($importer in $ReverseGraph.ReverseMap[$curr]) {
                if ($visited.Add($importer)) {
                    $queue.Enqueue($importer)
                }
            }
        }
    }
    return @($impactedTests)
}

function Invoke-ImpactAnalysis {
    [CmdletBinding()]
    param(
        [string[]]$ExplicitFiles = @(),
        [string]$BaselineRef = '',
        [switch]$Shadow,
        [switch]$ExecuteShadow,
        [ValidateSet('Critical', 'Sample', 'Full')][string]$ShadowScope = 'Critical',
        [int]$ShadowLimit = 0,
        [switch]$Json
    )

    $repoRoot = Get-RepoRoot
    $featuresJsonPath = Join-Path $repoRoot 'tools\dev\features.json'
    $featureCatalog = $null
    if (Test-Path -LiteralPath $featuresJsonPath) {
        $featureCatalog = Get-Content -LiteralPath $featuresJsonPath -Raw | ConvertFrom-Json
    }

    # Determine files to analyze
    $changedFiles = if ($PSBoundParameters.ContainsKey('ExplicitFiles')) { $ExplicitFiles } else { Get-ChangedRepositoryFiles -BaselineRef $BaselineRef }

    $selectedTests = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $affectedFeatures = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $deletedFiles = [Collections.Generic.List[string]]::new()
    $unmappedFiles = [Collections.Generic.List[string]]::new()
    $isCritical = $false
    $isSharedUI = $false
    $isPlatformChange = $false
    $isConfigChange = $false
    $isInfraChange = $false
    $requiresBroadRegression = $false
    $platforms = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $rationale = [Collections.Generic.List[object]]::new()

    function Add-SelectedTest([string]$TestPath, [string]$SourceFile, [string]$Reason, [string]$Category) {
        $normTest = $TestPath.Replace('\', '/')
        $absTest = Join-Path $repoRoot ($normTest.Replace('/', '\'))
        # Do not schedule deleted or non-existent test files for execution
        if (-not (Test-Path -LiteralPath $absTest)) {
            return
        }
        if (-not $selectedTests.ContainsKey($normTest)) {
            $selectedTests.Add($normTest, $Reason)
            $rationale.Add([pscustomobject]@{
                File = $SourceFile
                Reason = $Reason
                SelectedTest = $normTest
                Category = $Category
            })
        }
    }

    # Empty diff handling: zero changes = zero selected tests
    if ($changedFiles.Count -eq 0) {
        $emptyResult = [pscustomobject]@{
            Timestamp = (Get-Date -Format 'o')
            ChangedFilesCount = 0
            ChangedFiles = @()
            DeletedFiles = @()
            UnmappedFiles = @()
            AffectedFeatures = @()
            IsCritical = $false
            IsSharedUI = $false
            IsPlatformChange = $false
            IsConfigChange = $false
            IsInfraChange = $false
            RequiresBroadRegression = $false
            RecommendedMode = 'None'
            Platforms = @()
            SelectedTestsCount = 0
            SelectedTests = @()
            Rationale = @()
            ShadowMode = [bool]($Shadow -or $ExecuteShadow)
        }
        if ($Json) { return ($emptyResult | ConvertTo-Json -Depth 5) }
        return $emptyResult
    }

    $hasDartChanges = [bool](@($changedFiles | Where-Object { $_ -match '\.dart$' }).Count -gt 0)
    $reverseGraph = if ($hasDartChanges) { Get-ReverseDartDependencyMap -RepoRoot $repoRoot } else { $null }

    foreach ($file in $changedFiles) {
        $clean = $file.Replace('\', '/')
        $absFile = Join-Path $repoRoot ($clean.Replace('/', '\'))
        $fileExists = Test-Path -LiteralPath $absFile
        if (-not $fileExists) {
            $deletedFiles.Add($clean)
        }
        $fileMapped = $false

        # 1. Direct test file edit (executable test vs support helper)
        if ($clean -match '^test/.*_test\.dart$' -or $clean -match '^integration_test/.*\.dart$') {
            $fileMapped = $true
            if ($fileExists) {
                Add-SelectedTest -TestPath $clean -SourceFile $clean -Reason "Direct test modification: $clean" -Category 'DirectTest'
            } else {
                # Deleted test file: verify docs/registry consistency instead of running deleted test
                Add-SelectedTest -TestPath 'tools/dev/check-docs.py' -SourceFile $clean -Reason "Deleted test file integrity check: $clean" -Category 'DeletedTestCheck'
                Add-SelectedTest -TestPath 'tools/test_registry_sync.py' -SourceFile $clean -Reason "Deleted test registry sync check: $clean" -Category 'DeletedTestCheck'
            }
            continue
        }

        if ($clean -match '^test/.*\.dart$') {
            # Test support helper changed/deleted: resolve all tests importing it
            if ($reverseGraph) {
                $revTests = Resolve-ImpactedTestsFromReverseDeps -ChangedRelPath $clean -ReverseGraph $reverseGraph
                foreach ($rt in $revTests) {
                    $fileMapped = $true
                    Add-SelectedTest -TestPath $rt -SourceFile $clean -Reason "Test helper dependency: $clean" -Category 'TestHelperDependency'
                }
            }
            if (-not $fileMapped) {
                $unmappedFiles.Add($clean)
            }
            continue
        }

        # 2. Developer tool test edit
        if ($clean -match '^tools/.*test_.*\.py$') {
            $fileMapped = $true
            if ($fileExists) {
                Add-SelectedTest -TestPath $clean -SourceFile $clean -Reason "Developer tool test modification: $clean" -Category 'ToolTest'
            }
            continue
        }

        # 3. Critical Data / Schema / Persistence / Security / Privacy / Backup Boundary
        if ($clean -match 'lib/data/app_database\.dart|lib/data/sync_schema\.dart|lib/data/migration_gate\.dart|lib/data/life_repository.*\.dart|lib/data/migrations/|lib/data/backup_service\.dart|lib/data/privacy.*\.dart|lib/app/privacy.*\.dart|lib/data/profile_.*\.dart') {
            $isCritical = $true
            $fileMapped = $true
            $criticalTests = @(
                'test/database_initialization_test.dart',
                'test/database_migration_recovery_test.dart',
                'test/migration_gate_test.dart',
                'test/repository_test.dart',
                'test/sync_journal_test.dart',
                'test/task_revision_concurrency_test.dart',
                'test/backup_service_test.dart',
                'test/cross_platform_backup_test.dart',
                'test/privacy_test.dart',
                'test/profile_isolation_test.dart'
            )
            foreach ($ct in $criticalTests) {
                Add-SelectedTest -TestPath $ct -SourceFile $clean -Reason "Critical data persistence/security boundary: $clean" -Category 'CriticalData'
            }
        }

        # 4. Core Application Wiring / Domain Models (high blast radius)
        if ($clean -match '^lib/main\.dart$|^lib/app/app_controller\.dart$|^lib/domain/models\.dart$') {
            $isCritical = $true
            $requiresBroadRegression = $true
            $fileMapped = $true
            $coreTests = @(
                'test/workspace_test.dart',
                'test/mobile_workspace_test.dart',
                'test/repository_test.dart',
                'test/database_initialization_test.dart',
                'test/migration_gate_test.dart',
                'test/sync_controller_test.dart',
                'test/sync_apply_repository_test.dart',
                'test/calendar_test.dart',
                'test/event_recurrence_test.dart',
                'test/alarm_test.dart',
                'test/backup_service_test.dart',
                'test/android_platform_test.dart',
                'test/native_widget_service_test.dart',
                'test/desktop_widget_test.dart'
            )
            foreach ($coreTest in $coreTests) {
                Add-SelectedTest -TestPath $coreTest -SourceFile $clean -Reason "Core application entrypoint/model boundary: $clean" -Category 'CoreBoundary'
            }
        }

        # 5. Shared UI / Design System Boundary
        if ($clean -match 'lib/features/shared/|lib/domain/theme_tokens|app_layout\.dart|app_spacing\.dart|app_task_row\.dart|settings_section\.dart|app_theme.*\.dart|app_modal_shell\.dart') {
            $isSharedUI = $true
            $fileMapped = $true
            $uiTests = @(
                'test/app_task_row_test.dart',
                'test/settings_ui_quality_test.dart',
                'test/today_workspace_redesign_test.dart',
                'test/calendar_card_contrast_test.dart',
                'test/lab_render_test.dart'
            )
            foreach ($ut in $uiTests) {
                Add-SelectedTest -TestPath $ut -SourceFile $clean -Reason "Shared UI design system or component change: $clean" -Category 'SharedUI'
            }
        }

        # 6. Dependency configuration changes
        if ($clean -match '^pubspec\.yaml$' -or $clean -match '^pubspec\.lock$') {
            $isConfigChange = $true
            $isCritical = $true
            $requiresBroadRegression = $true
            $fileMapped = $true
            $configTests = @(
                'test/workspace_test.dart',
                'test/mobile_workspace_test.dart',
                'test/repository_test.dart',
                'test/database_initialization_test.dart',
                'test/migration_gate_test.dart',
                'test/sync_journal_test.dart',
                'test/backup_service_test.dart',
                'test/calendar_test.dart'
            )
            foreach ($cft in $configTests) {
                Add-SelectedTest -TestPath $cft -SourceFile $clean -Reason "Dependency configuration change: $clean" -Category 'DependencyConfig'
            }
        }

        # 7. Test, Toolkit & CI infrastructure changes
        if ($clean -match '^tools/' -or $clean -match '^\.github/workflows/' -or $clean -match '^dev\.(ps1|cmd)$') {
            $isInfraChange = $true
            $fileMapped = $true
            $infraTests = @(
                'tools/test_process_invocation_safety.py',
                'tools/test_dev_verify.py',
                'tools/test_ci_workflows.py',
                'tools/test_architecture_boundaries.py',
                'tools/test_registry_sync.py',
                'tools/dev/check-docs.py'
            )
            if ($clean -match '^tools/dev/(modules/|dev\.ps1|registry\.json|features\.json|test_)') {
                $infraTests += @(
                    'tools/dev/test_evidence_cache_safety.py',
                    'tools/dev/test_impact_behavior.py',
                    'tools/dev/test_session_locking_safety.py'
                )
            }
            foreach ($ift in $infraTests) {
                Add-SelectedTest -TestPath $ift -SourceFile $clean -Reason "Developer/CI infrastructure change: $clean" -Category 'TestInfrastructure'
            }
        }

        # 8. Feature Catalog Mapping (note: feature tests may be directory paths like test/cloud)
        if ($featureCatalog) {
            foreach ($prop in $featureCatalog.PSObject.Properties) {
                $featName = $prop.Name
                $paths = @($prop.Value.paths)
                $tests = @($prop.Value.tests)
                $matched = $false
                foreach ($p in $paths) {
                    $pNorm = $p.TrimEnd('/')
                    if ($clean.Equals($pNorm, [StringComparison]::OrdinalIgnoreCase) -or
                        $clean.StartsWith($pNorm + '/', [StringComparison]::OrdinalIgnoreCase)) {
                        $matched = $true
                        break
                    }
                }
                if ($matched) {
                    $fileMapped = $true
                    $affectedFeatures.Add($featName) | Out-Null
                    foreach ($t in $tests) {
                        $tAbs = Join-Path $repoRoot ($t.Replace('/', '\'))
                        if (Test-Path -LiteralPath $tAbs -PathType Container) {
                            $dirTests = Get-ChildItem -LiteralPath $tAbs -Recurse -File -Filter '*_test.dart'
                            foreach ($dt in $dirTests) {
                                $dtRel = ($dt.FullName.Substring($repoRoot.Length + 1)).Replace('\', '/')
                                Add-SelectedTest -TestPath $dtRel -SourceFile $clean -Reason "Feature '$featName' path match: $clean" -Category 'FeatureMapping'
                            }
                        } else {
                            Add-SelectedTest -TestPath $t -SourceFile $clean -Reason "Feature '$featName' path match: $clean" -Category 'FeatureMapping'
                        }
                    }
                }
            }
        }

        # 9. Platform Specific Changes
        if ($clean -match '^android/|lib/platform/android/') {
            $isPlatformChange = $true
            $fileMapped = $true
            $platforms.Add('Android') | Out-Null
            foreach ($at in @('test/android_platform_test.dart', 'test/android_widget_action_test.dart', 'test/mobile_workspace_test.dart')) {
                Add-SelectedTest -TestPath $at -SourceFile $clean -Reason "Android platform file change: $clean" -Category 'PlatformAndroid'
            }
        }
        if ($clean -match '^windows/|lib/platform/windows/|experiments/widget-shell-probe/') {
            $isPlatformChange = $true
            $fileMapped = $true
            $platforms.Add('Windows') | Out-Null
            foreach ($wt in @('test/native_widget_service_test.dart', 'test/desktop_widget_test.dart', 'test/widget_release_audit_test.dart', 'tools/test_background_sync_schema.py')) {
                Add-SelectedTest -TestPath $wt -SourceFile $clean -Reason "Windows platform or widget shell change: $clean" -Category 'PlatformWindows'
            }
        }

        # 9b. Flutter Driver scripts
        if ($clean -match '^test_driver/') {
            $fileMapped = $true
            foreach ($dt in @('test/runtime_workflow_journey_test.dart', 'test/workspace_test.dart', 'tools/test_architecture_boundaries.py')) {
                Add-SelectedTest -TestPath $dt -SourceFile $clean -Reason "Flutter driver acceptance script change: $clean" -Category 'DriverScript'
            }
        }

        # 10. Reverse Transitive Dart Dependency Discovery
        if ($clean -match '\.dart$' -and $reverseGraph) {
            $revTests = Resolve-ImpactedTestsFromReverseDeps -ChangedRelPath $clean -ReverseGraph $reverseGraph
            if ($revTests.Count -gt 0) {
                $fileMapped = $true
                foreach ($rt in $revTests) {
                    Add-SelectedTest -TestPath $rt -SourceFile $clean -Reason "Transitive Dart importer of $clean" -Category 'ReverseDependency'
                }
            }
        }

        # 11. Documentation-only files
        if ($clean -match '\.md$' -or $clean -match '^docs/') {
            $fileMapped = $true
            Add-SelectedTest -TestPath 'tools/dev/check-docs.py' -SourceFile $clean -Reason "Documentation integrity check: $clean" -Category 'Documentation'
        }

        if (-not $fileMapped) {
            $unmappedFiles.Add($clean)
        }
    }

    # 12. Conservative fallback when any non-doc file could not be confidently mapped
    # or when zero tests were selected for non-empty changes.
    if ($unmappedFiles.Count -gt 0 -or ($changedFiles.Count -gt 0 -and $selectedTests.Count -eq 0)) {
        $hasUnmappedDart = [bool](@($unmappedFiles | Where-Object { $_ -match '^lib/.*\.dart$' }).Count -gt 0)
        if ($hasUnmappedDart) {
            $requiresBroadRegression = $true
        }
        $fallbackTests = @(
            @{ Path = 'test/workspace_test.dart'; Reason = 'Conservative desktop workspace fallback for unmapped changes' },
            @{ Path = 'test/mobile_workspace_test.dart'; Reason = 'Conservative mobile workspace fallback for unmapped changes' },
            @{ Path = 'test/repository_test.dart'; Reason = 'Conservative data persistence fallback for unmapped changes' },
            @{ Path = 'test/database_initialization_test.dart'; Reason = 'Conservative schema initialization fallback for unmapped changes' },
            @{ Path = 'test/migration_gate_test.dart'; Reason = 'Conservative migration safety fallback for unmapped changes' },
            @{ Path = 'test/task_revision_concurrency_test.dart'; Reason = 'Conservative CAS concurrency fallback for unmapped changes' },
            @{ Path = 'test/sync_journal_test.dart'; Reason = 'Conservative sync journal fallback for unmapped changes' },
            @{ Path = 'test/sync_apply_repository_test.dart'; Reason = 'Conservative sync apply fallback for unmapped changes' },
            @{ Path = 'test/backup_service_test.dart'; Reason = 'Conservative backup safety fallback for unmapped changes' },
            @{ Path = 'test/privacy_test.dart'; Reason = 'Conservative security/privacy fallback for unmapped changes' },
            @{ Path = 'test/profile_isolation_test.dart'; Reason = 'Conservative profile isolation fallback for unmapped changes' },
            @{ Path = 'test/event_recurrence_test.dart'; Reason = 'Conservative recurrence math fallback for unmapped changes' },
            @{ Path = 'test/alarm_test.dart'; Reason = 'Conservative alarm safety fallback for unmapped changes' },
            @{ Path = 'test/android_platform_test.dart'; Reason = 'Conservative Android platform fallback for unmapped changes' },
            @{ Path = 'test/native_widget_service_test.dart'; Reason = 'Conservative Windows native widget fallback for unmapped changes' },
            @{ Path = 'test/desktop_widget_test.dart'; Reason = 'Conservative desktop widget fallback for unmapped changes' },
            @{ Path = 'test/app_task_row_test.dart'; Reason = 'Conservative shared UI component fallback for unmapped changes' },
            @{ Path = 'tools/test_architecture_boundaries.py'; Reason = 'Conservative architecture boundary fallback for unmapped changes' }
        )
        $fallbackSource = if ($unmappedFiles.Count -gt 0) { ($unmappedFiles -join ', ') } else { 'Multiple' }
        foreach ($fb in $fallbackTests) {
            Add-SelectedTest -TestPath $fb.Path -SourceFile $fallbackSource -Reason $fb.Reason -Category 'ConservativeFallback'
        }
    }

    $recommendedMode = if ($requiresBroadRegression) { 'Full' } elseif ($isCritical) { 'Critical' } else { 'Changed' }

    # 13. Verification Shadow Mode (static candidate comparison or optional broader execution)
    $shadowReport = $null
    if ($Shadow -or $ExecuteShadow) {
        $shadowReport = Invoke-ShadowVerification -SelectedTests @($selectedTests.Keys) -ChangedFiles $changedFiles -Execute:$ExecuteShadow -ShadowScope $ShadowScope -ShadowLimit $ShadowLimit
    }

    $result = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        ChangedFilesCount = $changedFiles.Count
        ChangedFiles = @($changedFiles)
        DeletedFiles = @($deletedFiles.ToArray())
        UnmappedFiles = @($unmappedFiles.ToArray())
        AffectedFeatures = @($affectedFeatures)
        IsCritical = $isCritical
        IsSharedUI = $isSharedUI
        IsPlatformChange = $isPlatformChange
        IsConfigChange = $isConfigChange
        IsInfraChange = $isInfraChange
        RequiresBroadRegression = $requiresBroadRegression
        RecommendedMode = $recommendedMode
        Platforms = @($platforms)
        SelectedTestsCount = $selectedTests.Count
        SelectedTests = @($selectedTests.Keys)
        Rationale = @($rationale.ToArray())
        ShadowMode = [bool]($Shadow -or $ExecuteShadow)
        ShadowReport = $shadowReport
    }

    if ($Json) {
        return ($result | ConvertTo-Json -Depth 6)
    }

    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "             TODORBIT IMPACT ANALYSIS REPORT                    " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Changed Files ($($result.ChangedFilesCount)):" -ForegroundColor White
    foreach ($f in $result.ChangedFiles) { Write-Host "  - $f" -ForegroundColor Gray }
    if ($result.DeletedFiles.Count -gt 0) {
        Write-Host "Deleted Files ($($result.DeletedFiles.Count)):" -ForegroundColor Yellow
        foreach ($df in $result.DeletedFiles) { Write-Host "  - $df" -ForegroundColor Yellow }
    }
    if ($result.UnmappedFiles.Count -gt 0) {
        Write-Host "Unmapped Files Triggering Conservative Expansion ($($result.UnmappedFiles.Count)):" -ForegroundColor Yellow
        foreach ($uf in $result.UnmappedFiles) { Write-Host "  - $uf" -ForegroundColor Yellow }
    }
    Write-Host ""
    Write-Host "Affected Features: $(if ($result.AffectedFeatures.Count) { $result.AffectedFeatures -join ', ' } else { 'None directly mapped' })" -ForegroundColor Yellow
    Write-Host "Flags: Critical=$($result.IsCritical) | SharedUI=$($result.IsSharedUI) | Platform=$($result.IsPlatformChange) | Config=$($result.IsConfigChange) | BroadRegression=$($result.RequiresBroadRegression)" -ForegroundColor White
    Write-Host ""
    Write-Host "Selected Verification Checks ($($result.SelectedTestsCount)):" -ForegroundColor Green
    foreach ($t in $result.SelectedTests) {
        $r = $selectedTests[$t]
        Write-Host "  - $t " -ForegroundColor White -NoNewline
        Write-Host "($r)" -ForegroundColor DarkGray
    }
    if ($result.ShadowMode) {
        Write-Host ""
        if ($shadowReport -and $shadowReport.Executed) {
            $shadowColor = if ($shadowReport.ShadowPassed) { 'Green' } else { 'Red' }
            Write-Host "Verification Shadow Execution: $($shadowReport.ExecutedShadowTestsCount) omitted suite(s) run | Missed failures: $($shadowReport.MissedFailures.Count)" -ForegroundColor $shadowColor
        } else {
            Write-Host "Verification Shadow Mode: Active (static candidate comparison recorded; pass -ExecuteShadow or run 'dev verify changed -Shadow' to execute omitted suites)" -ForegroundColor Magenta
        }
    }
    Write-Host "=================================================================" -ForegroundColor Cyan

    return $result
}

function Invoke-ShadowVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string[]]$SelectedTests,
        [string[]]$ChangedFiles = @(),
        [switch]$Execute,
        [ValidateSet('Critical', 'Sample', 'Full')][string]$ShadowScope = 'Critical',
        [int]$ShadowLimit = 0,
        [string[]]$CandidateOverride = @(),
        [string]$ShadowRunnerCommand = '',
        [switch]$Json
    )
    $repoRoot = Get-RepoRoot
    $registryPath = Join-Path $repoRoot 'tools\dev\registry.json'
    $candidateEntries = @()
    if ($CandidateOverride.Count -gt 0) {
        $candidateEntries = @($CandidateOverride | ForEach-Object { [pscustomobject]@{ Path = $_; Type = 'flutter_test'; Tier = 'Level2_Critical'; EvidenceReuse = 'Eligible' } })
    } elseif (Test-Path -LiteralPath $registryPath) {
        $reg = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        $candidateEntries = @($reg.Tests | Where-Object { $_.Type -eq 'flutter_test' -and $_.EvidenceReuse -ne 'Ineligible' })
    }

    $candidateTests = @($candidateEntries | Select-Object -ExpandProperty Path)
    $impactSet = [Collections.Generic.HashSet[string]]::new($SelectedTests, [StringComparer]::OrdinalIgnoreCase)
    $omittedEntries = @($candidateEntries | Where-Object { -not $impactSet.Contains($_.Path) })
    $omittedCandidates = @($omittedEntries | Select-Object -ExpandProperty Path)

    $shadowDir = Join-Path $repoRoot '.buildlog\shadow'
    if (-not (Test-Path -LiteralPath $shadowDir)) {
        New-Item -ItemType Directory -Force -Path $shadowDir | Out-Null
    }
    $shadowFile = Join-Path $shadowDir "shadow-$((Get-Date).ToString('yyyyMMdd-HHmmss-fff')).json"

    $executedShadowTests = [Collections.Generic.List[string]]::new()
    $missedFailures = [Collections.Generic.List[object]]::new()
    $discrepancies = [Collections.Generic.List[object]]::new()
    $ruleSuggestions = [Collections.Generic.List[object]]::new()

    if ($Execute -and $omittedEntries.Count -gt 0) {
        # Determine shadow execution set without making ordinary dev runs expensive
        $toExecute = switch ($ShadowScope) {
            'Critical' { @($omittedEntries | Where-Object { $_.Tier -eq 'Level2_Critical' } | Select-Object -ExpandProperty Path) }
            'Sample'   { @($omittedEntries | Where-Object { $_.Tier -in @('Level1_Fast', 'Level2_Critical') } | Select-Object -ExpandProperty Path) }
            'Full'     { @($omittedCandidates) }
        }
        if ($toExecute.Count -eq 0) {
            $toExecute = @($omittedCandidates)
        }
        if ($ShadowLimit -gt 0 -and $toExecute.Count -gt $ShadowLimit) {
            $toExecute = @($toExecute | Select-Object -First $ShadowLimit)
        }

        $runnerBat = $null
        if ([string]::IsNullOrWhiteSpace($ShadowRunnerCommand)) {
            if (Get-Command 'Resolve-TodorbitTool' -ErrorAction SilentlyContinue) {
                $runnerBat = Resolve-TodorbitTool 'flutter'
            } else {
                $runnerBat = 'flutter.bat'
            }
        }

        # Run in bounded batches of 10; if a batch fails, isolate individual failing test(s)
        $batchSize = 10
        for ($i = 0; $i -lt $toExecute.Count; $i += $batchSize) {
            $end = [Math]::Min($i + $batchSize - 1, $toExecute.Count - 1)
            $batch = @($toExecute[$i..$end])
            foreach ($bt in $batch) { $executedShadowTests.Add($bt) }

            $batchExit = 0
            $batchOutput = ''
            Push-Location $repoRoot
            try {
                $ErrorActionPreference = 'Continue'
                if (-not [string]::IsNullOrWhiteSpace($ShadowRunnerCommand)) {
                    $batchOutput = ((& $ShadowRunnerCommand @batch 2>&1 | ForEach-Object { $_.ToString() }) -join "`n")
                } else {
                    $batchOutput = ((& $runnerBat test --no-pub --concurrency=1 --reporter=expanded @batch 2>&1 | ForEach-Object { $_.ToString() }) -join "`n")
                }
                $batchExit = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = 'Stop'
                Pop-Location
            }

            if ($batchExit -ne 0) {
                # Isolate exact failing test(s) inside the failed batch
                foreach ($singleTest in $batch) {
                    $singleExit = 0
                    $singleOutput = ''
                    Push-Location $repoRoot
                    try {
                        $ErrorActionPreference = 'Continue'
                        if (-not [string]::IsNullOrWhiteSpace($ShadowRunnerCommand)) {
                            $singleOutput = ((& $ShadowRunnerCommand $singleTest 2>&1 | ForEach-Object { $_.ToString() }) -join "`n")
                        } else {
                            $singleOutput = ((& $runnerBat test --no-pub --concurrency=1 --reporter=expanded $singleTest 2>&1 | ForEach-Object { $_.ToString() }) -join "`n")
                        }
                        $singleExit = $LASTEXITCODE
                    } finally {
                        $ErrorActionPreference = 'Stop'
                        Pop-Location
                    }
                    if ($singleExit -ne 0) {
                        $tailLines = ($singleOutput -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 8) -join "`n"
                        $missedFailures.Add([pscustomobject]@{
                            TestPath = $singleTest
                            ExitCode = $singleExit
                            OutputExcerpt = $tailLines
                        })
                        $discrepancies.Add([pscustomobject]@{
                            Type = 'MissedFailure'
                            TestPath = $singleTest
                            ChangedFiles = $ChangedFiles
                            Message = "Omitted test '$singleTest' failed under shadow verification (impact selection gap)."
                        })
                        $ruleSuggestions.Add([pscustomobject]@{
                            Timestamp = (Get-Date -Format 'o')
                            MissedTest = $singleTest
                            ChangedFiles = $ChangedFiles
                            SuggestedAction = "Map changed source path(s) in tools/dev/features.json or Impact.psm1 to include '$singleTest'."
                        })
                    }
                }
            }
        }
    }

    if ($ruleSuggestions.Count -gt 0) {
        $gapsPath = Join-Path $shadowDir 'rule-gaps.json'
        $existingGaps = @()
        if (Test-Path -LiteralPath $gapsPath) {
            try { $existingGaps = @(Get-Content -LiteralPath $gapsPath -Raw | ConvertFrom-Json) } catch {}
        }
        $mergedGaps = @($existingGaps) + @($ruleSuggestions.ToArray())
        $gapsJson = ConvertTo-Json -InputObject $mergedGaps -Depth 5
        [IO.File]::WriteAllText($gapsPath, $gapsJson, [Text.UTF8Encoding]::new($false))
    }

    $report = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        Executed = [bool]$Execute
        ShadowScope = $ShadowScope
        ChangedFiles = $ChangedFiles
        SelectedTests = $SelectedTests
        SelectedTestsCount = $SelectedTests.Count
        TotalCandidates = $candidateTests.Count
        OmittedCandidatesCount = $omittedCandidates.Count
        OmittedCandidates = $omittedCandidates
        ExecutedShadowTestsCount = $executedShadowTests.Count
        ExecutedShadowTests = @($executedShadowTests.ToArray())
        MissedFailures = @($missedFailures.ToArray())
        Discrepancies = @($discrepancies.ToArray())
        SelectionRuleSuggestions = @($ruleSuggestions.ToArray())
        ShadowPassed = ($missedFailures.Count -eq 0)
        ReportPath = $shadowFile
    }

    $shadowJson = $report | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($shadowFile, $shadowJson, [Text.UTF8Encoding]::new($false))

    if ($Json) { return $shadowJson }
    return $report
}

Export-ModuleMember -Function Get-ChangedRepositoryFiles, Get-ReverseDartDependencyMap, Resolve-ImpactedTestsFromReverseDeps, Invoke-ImpactAnalysis, Invoke-ShadowVerification
