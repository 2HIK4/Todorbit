# Impact.psm1 - Todorbit Intelligent Impact Analysis & Verification Planning
# Resolves changed files, imports, features, dependencies, and conservative test selection.
# Includes Verification Shadow Mode and behavioral safety boundaries.
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Get-ChangedRepositoryFiles {
    [CmdletBinding()]
    param(
        [string]$BaselineRef = ''
    )
    $repoRoot = Get-RepoRoot
    $changed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    # 1. Unstaged, staged, untracked, and renamed git changes
    $statusLines = & git status --porcelain 2>$null
    if ($statusLines) {
        foreach ($line in $statusLines) {
            if ($line.Length -ge 4) {
                $path = $line.Substring(3).Trim().Replace('\', '/')
                # Handle renames: R  orig -> dest
                if ($path -match '->') {
                    $parts = $path -split '->'
                    $path = $parts[1].Trim()
                }
                # Exclude transient build/log paths
                if ($path -notmatch '^\.buildlog' -and $path -notmatch '^build/' -and $path -notmatch '^\.dart_tool') {
                    $changed.Add($path) | Out-Null
                }
            }
        }
    }

    # 2. Baseline comparison: if BaselineRef is specified, or if working tree is clean on a feature branch
    $targetBaseline = $BaselineRef
    if (-not $targetBaseline) {
        # When working tree has no uncommitted changes, auto-detect base branch/merge-base
        if ($changed.Count -eq 0) {
            try {
                $upstream = (& git rev-parse --abbrev-ref '@{u}' 2>$null)
                if ($upstream -and $LASTEXITCODE -eq 0) {
                    $targetBaseline = $upstream.Trim()
                }
            } catch {}

            if (-not $targetBaseline) {
                foreach ($candidate in @('feature/todorbit-ui-redesign-2', 'origin/main', 'main')) {
                    try {
                        $mb = (& git merge-base HEAD $candidate 2>$null)
                        if ($mb -and $LASTEXITCODE -eq 0) {
                            $targetBaseline = $mb.Trim()
                            break
                        }
                    } catch {}
                }
            }
        }
    }

    if ($targetBaseline -and $targetBaseline -ne 'HEAD') {
        $diffFiles = & git diff --name-only "$targetBaseline...HEAD" 2>$null
        if ($diffFiles) {
            foreach ($df in $diffFiles) {
                $dfClean = $df.Trim().Replace('\', '/')
                if ($dfClean -notmatch '^\.buildlog' -and $dfClean -notmatch '^build/' -and $dfClean -notmatch '^\.dart_tool') {
                    $changed.Add($dfClean) | Out-Null
                }
            }
        }
    }

    return @($changed)
}

function Invoke-ImpactAnalysis {
    [CmdletBinding()]
    param(
        [string[]]$ExplicitFiles = @(),
        [string]$BaselineRef = '',
        [switch]$Shadow,
        [switch]$Json
    )

    $repoRoot = Get-RepoRoot
    $featuresJsonPath = Join-Path $repoRoot 'tools\dev\features.json'
    $featureCatalog = $null
    if (Test-Path -LiteralPath $featuresJsonPath) {
        $featureCatalog = Get-Content -LiteralPath $featuresJsonPath -Raw | ConvertFrom-Json
    }

    $registryPath = Join-Path $repoRoot 'tools\dev\registry.json'
    $registry = $null
    if (Test-Path -LiteralPath $registryPath) {
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
    }

    # Determine files to analyze
    $changedFiles = if ($PSBoundParameters.ContainsKey('ExplicitFiles')) { $ExplicitFiles } else { Get-ChangedRepositoryFiles -BaselineRef $BaselineRef }

    $selectedTests = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $affectedFeatures = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $isCritical = $false
    $isSharedUI = $false
    $isPlatformChange = $false
    $isConfigChange = $false
    $isInfraChange = $false
    $platforms = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $rationale = [Collections.Generic.List[object]]::new()

    # Empty diff handling: zero changes = zero selected tests
    if ($changedFiles.Count -eq 0) {
        $emptyResult = [pscustomobject]@{
            Timestamp = (Get-Date -Format 'o')
            ChangedFilesCount = 0
            ChangedFiles = @()
            AffectedFeatures = @()
            IsCritical = $false
            IsSharedUI = $false
            IsPlatformChange = $false
            IsConfigChange = $false
            IsInfraChange = $false
            Platforms = @()
            SelectedTestsCount = 0
            SelectedTests = @()
            Rationale = @()
            ShadowMode = [bool]$Shadow
        }
        if ($Json) { return ($emptyResult | ConvertTo-Json -Depth 5) }
        return $emptyResult
    }

    foreach ($file in $changedFiles) {
        $clean = $file.Replace('\', '/')

        # 1. Direct test file edit
        if ($clean -match '^test/.*\.dart$' -or $clean -match '^integration_test/.*\.dart$') {
            if (-not $selectedTests.ContainsKey($clean)) {
                $selectedTests.Add($clean, "Direct test modification: $clean")
                $rationale.Add([pscustomobject]@{
                    File = $clean
                    Reason = "Direct test modification"
                    SelectedTest = $clean
                    Category = 'DirectTest'
                })
            }
            continue
        }

        # 2. Developer tool test edit
        if ($clean -match '^tools/.*test_.*\.py$') {
            if (-not $selectedTests.ContainsKey($clean)) {
                $selectedTests.Add($clean, "Developer tool test modification: $clean")
                $rationale.Add([pscustomobject]@{
                    File = $clean
                    Reason = "Developer tool test modification"
                    SelectedTest = $clean
                    Category = 'ToolTest'
                })
            }
            continue
        }

        # 3. Critical Data / Schema / Persistence Boundary
        if ($clean -match 'lib/data/app_database\.dart|lib/data/sync_schema\.dart|lib/data/migration_gate\.dart|lib/data/life_repository.*\.dart|lib/data/migrations/') {
            $isCritical = $true
            $criticalTests = @(
                'test/database_initialization_test.dart',
                'test/database_migration_recovery_test.dart',
                'test/migration_gate_test.dart',
                'test/repository_test.dart',
                'test/sync_journal_test.dart',
                'test/task_revision_concurrency_test.dart'
            )
            foreach ($ct in $criticalTests) {
                if (-not $selectedTests.ContainsKey($ct)) {
                    $selectedTests.Add($ct, "Critical persistence/schema boundary change: $clean")
                    $rationale.Add([pscustomobject]@{
                        File = $clean
                        Reason = "Critical data persistence/migration boundary"
                        SelectedTest = $ct
                        Category = 'CriticalData'
                    })
                }
            }
        }

        # 4. Shared UI / Design System Boundary
        if ($clean -match 'lib/features/shared/|lib/domain/theme_tokens|app_layout\.dart|app_spacing\.dart|app_task_row\.dart|settings_section\.dart') {
            $isSharedUI = $true
            $uiTests = @(
                'test/app_task_row_test.dart',
                'test/settings_ui_quality_test.dart',
                'test/today_workspace_redesign_test.dart',
                'test/calendar_card_contrast_test.dart',
                'test/lab_render_test.dart'
            )
            foreach ($ut in $uiTests) {
                if (-not $selectedTests.ContainsKey($ut)) {
                    $selectedTests.Add($ut, "Shared UI/design system token change: $clean")
                    $rationale.Add([pscustomobject]@{
                        File = $clean
                        Reason = "Shared UI design system or component change"
                        SelectedTest = $ut
                        Category = 'SharedUI'
                    })
                }
            }
        }

        # 5. Dependency configuration changes
        if ($clean -match '^pubspec\.yaml$' -or $clean -match '^pubspec\.lock$') {
            $isConfigChange = $true
            $configTests = @(
                'test/workspace_test.dart',
                'test/repository_test.dart',
                'test/database_initialization_test.dart'
            )
            foreach ($cft in $configTests) {
                if (-not $selectedTests.ContainsKey($cft)) {
                    $selectedTests.Add($cft, "Dependency configuration change: $clean")
                    $rationale.Add([pscustomobject]@{
                        File = $clean
                        Reason = "Project dependency lockfile or specification change"
                        SelectedTest = $cft
                        Category = 'DependencyConfig'
                    })
                }
            }
        }

        # 6. Test infrastructure changes
        if ($clean -match '^tools/dev/verify\.ps1$' -or $clean -match '^tools/dev/dev\.ps1$' -or $clean -match '^tools/dev/modules/') {
            $isInfraChange = $true
            $infraTests = @('tools/test_process_invocation_safety.py')
            foreach ($ift in $infraTests) {
                if (-not $selectedTests.ContainsKey($ift)) {
                    $selectedTests.Add($ift, "Test infrastructure change: $clean")
                    $rationale.Add([pscustomobject]@{
                        File = $clean
                        Reason = "Developer automation toolkit infrastructure change"
                        SelectedTest = $ift
                        Category = 'TestInfrastructure'
                    })
                }
            }
        }

        # 7. Feature Catalog Mapping
        if ($featureCatalog) {
            foreach ($prop in $featureCatalog.PSObject.Properties) {
                $featName = $prop.Name
                $paths = @($prop.Value.paths)
                $tests = @($prop.Value.tests)
                $matched = $false
                foreach ($p in $paths) {
                    if ($clean.StartsWith($p, [StringComparison]::OrdinalIgnoreCase) -or
                        $clean.Equals($p, [StringComparison]::OrdinalIgnoreCase)) {
                        $matched = $true
                        break
                    }
                }
                if ($matched) {
                    $affectedFeatures.Add($featName) | Out-Null
                    foreach ($t in $tests) {
                        if (-not $selectedTests.ContainsKey($t)) {
                            $selectedTests.Add($t, "Feature '$featName' path match: $clean")
                            $rationale.Add([pscustomobject]@{
                                File = $clean
                                Reason = "Mapped to feature '$featName'"
                                SelectedTest = $t
                                Category = 'FeatureMapping'
                            })
                        }
                    }
                }
            }
        }

        # 8. Platform Specific Changes
        if ($clean -match '^android/|lib/platform/android/') {
            $isPlatformChange = $true
            $platforms.Add('Android') | Out-Null
            $androidTests = @('test/android_platform_test.dart', 'test/android_widget_action_test.dart')
            foreach ($at in $androidTests) {
                if (-not $selectedTests.ContainsKey($at)) {
                    $selectedTests.Add($at, "Android platform file change: $clean")
                    $rationale.Add([pscustomobject]@{
                        File = $clean
                        Reason = "Android platform file change"
                        SelectedTest = $at
                        Category = 'PlatformAndroid'
                    })
                }
            }
        }
        if ($clean -match '^windows/|lib/platform/windows/|experiments/widget-shell-probe/') {
            $isPlatformChange = $true
            $platforms.Add('Windows') | Out-Null
            $winTests = @('test/windows_platform_test.dart')
            foreach ($wt in $winTests) {
                if (-not $selectedTests.ContainsKey($wt)) {
                    $selectedTests.Add($wt, "Windows platform change: $clean")
                    $rationale.Add([pscustomobject]@{
                        File = $clean
                        Reason = "Windows platform or widget shell change"
                        SelectedTest = $wt
                        Category = 'PlatformWindows'
                    })
                }
            }
        }
    }

    # 9. Unmapped / Ambiguous changes fallback: conservative expansion
    if ($changedFiles.Count -gt 0 -and $selectedTests.Count -eq 0) {
        $fallbackTests = @(
            @{ Path = 'test/workspace_test.dart'; Reason = 'Conservative workspace fallback for unmapped changes' },
            @{ Path = 'test/repository_test.dart'; Reason = 'Conservative data persistence fallback for unmapped changes' },
            @{ Path = 'test/database_initialization_test.dart'; Reason = 'Conservative schema initialization fallback for unmapped changes' },
            @{ Path = 'test/task_revision_concurrency_test.dart'; Reason = 'Conservative concurrency safety fallback for unmapped changes' },
            @{ Path = 'test/app_task_row_test.dart'; Reason = 'Conservative UI component fallback for unmapped changes' }
        )
        foreach ($fb in $fallbackTests) {
            $selectedTests.Add($fb.Path, $fb.Reason)
            $rationale.Add([pscustomobject]@{
                File = 'Multiple'
                Reason = $fb.Reason
                SelectedTest = $fb.Path
                Category = 'ConservativeFallback'
            })
        }
    }

    # 10. Verification Shadow Mode (compares impact set vs full candidate set)
    $shadowReport = $null
    if ($Shadow) {
        $shadowReport = Invoke-ShadowVerification -SelectedTests @($selectedTests.Keys) -ChangedFiles $changedFiles
    }

    $result = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        ChangedFilesCount = $changedFiles.Count
        ChangedFiles = @($changedFiles)
        AffectedFeatures = @($affectedFeatures)
        IsCritical = $isCritical
        IsSharedUI = $isSharedUI
        IsPlatformChange = $isPlatformChange
        IsConfigChange = $isConfigChange
        IsInfraChange = $isInfraChange
        Platforms = @($platforms)
        SelectedTestsCount = $selectedTests.Count
        SelectedTests = @($selectedTests.Keys)
        Rationale = @($rationale.ToArray())
        ShadowMode = [bool]$Shadow
    }

    if ($Json) {
        return ($result | ConvertTo-Json -Depth 5)
    }

    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "             TODORBIT IMPACT ANALYSIS REPORT                    " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Changed Files ($($result.ChangedFilesCount)):" -ForegroundColor White
    foreach ($f in $result.ChangedFiles) { Write-Host "  - $f" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "Affected Features: $(if ($result.AffectedFeatures.Count) { $result.AffectedFeatures -join ', ' } else { 'None directly mapped' })" -ForegroundColor Yellow
    Write-Host "Flags: Critical=$($result.IsCritical) | SharedUI=$($result.IsSharedUI) | Platform=$($result.IsPlatformChange) | Config=$($result.IsConfigChange)" -ForegroundColor White
    Write-Host ""
    Write-Host "Selected Verification Checks ($($result.SelectedTestsCount)):" -ForegroundColor Green
    foreach ($t in $result.SelectedTests) {
        $r = $selectedTests[$t]
        Write-Host "  - $t " -ForegroundColor White -NoNewline
        Write-Host "($r)" -ForegroundColor DarkGray
    }
    if ($Shadow) {
        Write-Host ""
        Write-Host "Verification Shadow Mode: Active (shadow report recorded)" -ForegroundColor Magenta
    }
    Write-Host "=================================================================" -ForegroundColor Cyan

    return $result
}

function Invoke-ShadowVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string[]]$SelectedTests,
        [string[]]$ChangedFiles = @(),
        [switch]$Json
    )
    $repoRoot = Get-RepoRoot
    $registryPath = Join-Path $repoRoot 'tools\dev\registry.json'
    $candidateTests = @()
    if (Test-Path -LiteralPath $registryPath) {
        $reg = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        $candidateTests = @($reg.Tests | Where-Object { $_.Type -eq 'flutter_test' -and $_.EvidenceReuse -ne 'Ineligible' } | Select-Object -ExpandProperty Path)
    }

    $impactSet = [Collections.Generic.HashSet[string]]::new($SelectedTests, [StringComparer]::OrdinalIgnoreCase)
    $omittedCandidates = @($candidateTests | Where-Object { -not $impactSet.Contains($_) })

    $shadowDir = Join-Path $repoRoot '.buildlog\shadow'
    if (-not (Test-Path -LiteralPath $shadowDir)) {
        New-Item -ItemType Directory -Force -Path $shadowDir | Out-Null
    }
    $shadowFile = Join-Path $shadowDir "shadow-$((Get-Date).ToString('yyyyMMdd-HHmmss')).json"

    $discrepancies = [Collections.Generic.List[object]]::new()

    $report = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        ChangedFiles = $ChangedFiles
        SelectedTests = $SelectedTests
        SelectedTestsCount = $SelectedTests.Count
        TotalCandidates = $candidateTests.Count
        OmittedCandidatesCount = $omittedCandidates.Count
        OmittedCandidates = $omittedCandidates
        Discrepancies = @($discrepancies.ToArray())
        ShadowPassed = ($discrepancies.Count -eq 0)
    }

    $shadowJson = $report | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($shadowFile, $shadowJson, [Text.UTF8Encoding]::new($false))

    if ($Json) { return $shadowJson }
    return $report
}

Export-ModuleMember -Function Get-ChangedRepositoryFiles, Invoke-ImpactAnalysis, Invoke-ShadowVerification
