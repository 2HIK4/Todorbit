<#
.SYNOPSIS
    Todorbit Developer Automation Toolkit - AI Engineering Harness Module
.DESCRIPTION
    Generates deterministic feature context packs and compact repository maps
    to minimize AI agent token consumption and eliminate repetitive file searching.
#>

$ErrorActionPreference = 'Stop'

function Get-FeatureContextPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Feature,
        [switch]$Json
    )

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
    $contextsPath = Join-Path $scriptDir '..\feature_contexts.json'

    if (-not (Test-Path -LiteralPath $contextsPath)) {
        throw "Feature contexts configuration not found: $contextsPath"
    }

    $allContexts = Get-Content -LiteralPath $contextsPath -Raw -Encoding utf8 | ConvertFrom-Json

    $normalizedFeature = $Feature.ToLowerInvariant().Trim()
    $featureProp = $allContexts.PSObject.Properties[$normalizedFeature]

    if (-not $featureProp) {
        # Check alias / substring
        $candidates = @($allContexts.PSObject.Properties | Where-Object { $_.Name -like "*$normalizedFeature*" })
        if ($candidates.Count -eq 1) {
            $featureProp = $candidates[0]
            $normalizedFeature = $featureProp.Name
        } else {
            $available = ($allContexts.PSObject.Properties | Select-Object -ExpandProperty Name) -join ', '
            throw "Feature '$Feature' not found in registry. Available features: $available"
        }
    }

    $ctx = $featureProp.Value

    $pack = [pscustomobject]@{
        Feature = $normalizedFeature
        Summary = $ctx.summary
        PrimaryRequirements = @($ctx.primaryRequirements)
        EntryPoints = $ctx.entryPoints
        ArchitectureBoundaries = @($ctx.architectureBoundaries)
        DesignSystemTokens = @($ctx.designSystemTokens)
        Tests = @($ctx.tests)
        HistoricalInvariants = @($ctx.historicalInvariants)
        ApplicableSkills = @($ctx.applicableSkills)
        Documentation = @($ctx.documentation)
        Fixtures = @($ctx.fixtures)
        RecommendedVerification = ".\dev verify feature $normalizedFeature"
    }

    if ($Json) {
        return ($pack | ConvertTo-Json -Depth 6)
    }

    # Format human-readable / AI-context-friendly markdown
    $q = [char]96 # markdown backtick
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Feature Context Pack: $normalizedFeature")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Summary")
    [void]$sb.AppendLine($pack.Summary)
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Primary Requirements & Invariants")
    foreach ($req in $pack.PrimaryRequirements) {
        [void]$sb.AppendLine("- $req")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Entry Points & Key Files")
    foreach ($group in $pack.EntryPoints.PSObject.Properties) {
        [void]$sb.AppendLine("### $($group.Name)")
        foreach ($file in $group.Value) {
            [void]$sb.AppendLine("- ${q}${file}${q}")
        }
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Architectural Boundaries")
    foreach ($b in $pack.ArchitectureBoundaries) {
        [void]$sb.AppendLine("- $b")
    }
    if ($pack.DesignSystemTokens.Count -gt 0) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Design System & UI Presentation")
        foreach ($tok in $pack.DesignSystemTokens) {
            [void]$sb.AppendLine("- $tok")
        }
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Verification & Tests")
    [void]$sb.AppendLine("Primary command: ${q}$($pack.RecommendedVerification)${q}")
    [void]$sb.AppendLine("Associated test files:")
    foreach ($t in $pack.Tests) {
        [void]$sb.AppendLine("- ${q}${t}${q}")
    }
    if ($pack.HistoricalInvariants.Count -gt 0) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Critical Historical Regressions & Invariants")
        foreach ($hi in $pack.HistoricalInvariants) {
            [void]$sb.AppendLine("- $hi")
        }
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Applicable Skills & Documentation")
    foreach ($sk in $pack.ApplicableSkills) {
        [void]$sb.AppendLine("- Skill: ${q}${sk}${q}")
    }
    foreach ($doc in $pack.Documentation) {
        [void]$sb.AppendLine("- Doc: ${q}${doc}${q}")
    }
    if ($pack.Fixtures.Count -gt 0) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("## Recommended Fixtures")
        foreach ($fix in $pack.Fixtures) {
            [void]$sb.AppendLine("- ${q}dev fixture $fix${q}")
        }
    }

    return $sb.ToString()
}

function Get-RepositoryMap {
    [CmdletBinding()]
    param([switch]$Json)

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path

    $dartFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'lib') -Recurse -Filter '*.dart' -ErrorAction SilentlyContinue)
    $testFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'test') -Recurse -Filter '*_test.dart' -ErrorAction SilentlyContinue)

    $registryPath = Join-Path $repoRoot 'tools\dev\registry.json'
    $reg = $null
    if (Test-Path -LiteralPath $registryPath) {
        try { $reg = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json } catch {}
    }

    $metrics = [pscustomobject]@{
        DartSourceFiles = $dartFiles.Count
        TotalExecutableSuites = if ($reg -and $reg.Metrics) { $reg.Metrics.TotalExecutableSuites } else { $testFiles.Count }
        DartUnitAndWidgetSuites = if ($reg -and $reg.Metrics) { $reg.Metrics.DartUnitAndWidgetSuites } else { $testFiles.Count }
        IntegrationSuites = if ($reg -and $reg.Metrics) { $reg.Metrics.IntegrationSuites } else { 3 }
        ToolTestSuites = if ($reg -and $reg.Metrics) { $reg.Metrics.ToolTestSuites } else { 10 }
        SupportHelperFiles = if ($reg -and $reg.Metrics) { $reg.Metrics.SupportHelperFiles } else { 14 }
        EstimatedIndividualTestCases = if ($reg -and $reg.Metrics) { $reg.Metrics.EstimatedIndividualTestCases } else { 1100 }
        TotalRegisteredFeatures = 20
    }

    $topology = [pscustomobject]@{
        ApplicationLayers = [pscustomobject]@{
            "State Coordination" = [pscustomobject]@{
                Path = "lib/app/"
                Role = "Coordinates application lifecycle, state flow, AppController, SyncController, and SyncRuntime."
                KeyFiles = @("lib/app/app_controller.dart", "lib/app/sync_controller.dart", "lib/app/sync_runtime.dart")
            }
            "Domain Logic" = [pscustomobject]@{
                Path = "lib/domain/"
                Role = "Pure business logic, calculations, recurrence, models, and sync exchange formats. Strictly zero UI imports."
                KeyFiles = @("lib/domain/models.dart", "lib/domain/recurrence.dart", "lib/domain/scheduling_engine.dart", "lib/domain/habits.dart", "lib/domain/goals.dart", "lib/domain/alarms.dart")
            }
            "Data & Persistence" = [pscustomobject]@{
                Path = "lib/data/"
                Role = "SQLite access via Drift, transactions, LifeRepository and parts, schema forward migrations, sync journals, and update downloads."
                KeyFiles = @("lib/data/app_database.dart", "lib/data/life_repository.dart", "lib/data/migration_gate.dart", "lib/data/sync_repository.dart")
            }
            "Presentation (UI)" = [pscustomobject]@{
                Path = "lib/features/"
                Role = "Responsive desktop (Windows) and mobile (Android) views, shared components (lib/features/shared/), and settings hub."
                KeyFiles = @("lib/features/workspace/workspace.dart", "lib/features/calendar/calendar_view.dart", "lib/features/shared/app_task_row.dart", "lib/features/shared/app_modal_shell.dart")
            }
            "Platform Adapters" = [pscustomobject]@{
                Path = "lib/platform/"
                Role = "Android MethodChannel adapters, native surfaces, and update services."
                KeyFiles = @("lib/platform/android/android_platform.dart", "lib/platform/android/android_surfaces.dart")
            }
            "Windows Native Companion" = [pscustomobject]@{
                Path = "experiments/widget-shell-probe/"
                Role = "Production C# / Win32 native widget companion with narrow SQLite reader/writer. Never migrates schemas."
                KeyFiles = @("experiments/widget-shell-probe/Program.cs", "experiments/widget-shell-probe/LifeManagerWidget.cs")
            }
            "Android Native Companion" = [pscustomobject]@{
                Path = "android/app/src/main/kotlin/io/github/hik4/todorbit/"
                Role = "Kotlin AppWidget, AlarmManager, and Doze background delivery."
                KeyFiles = @("android/app/src/main/kotlin/io/github/hik4/todorbit/AndroidSurfaces.kt", "android/app/src/main/kotlin/io/github/hik4/todorbit/AlarmDelivery.kt")
            }
        }
        DataFlows = @(
            "User UI Action -> AppController -> LifeRepository (SQLite transaction, stable UUID, UTC timestamp) -> notifyListeners -> UI update",
            "Local Mutation -> Sync Journal -> SyncController/SyncEngine -> Google Drive AppData (CAS tokens, workspace v2, tombstones)",
            "Remote Changes -> Pull Sync Batch -> CAS Verification -> SyncApplyRepository (SQLite transaction) -> AppController refresh"
        )
        Metrics = $metrics
    }

    if ($Json) {
        return ($topology | ConvertTo-Json -Depth 5)
    }

    $q = [char]96
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Todorbit Repository Architecture Map")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Application Layers")
    foreach ($layer in $topology.ApplicationLayers.PSObject.Properties) {
        [void]$sb.AppendLine("### $($layer.Name) (${q}$($layer.Value.Path)${q})")
        [void]$sb.AppendLine("$($layer.Value.Role)")
        [void]$sb.AppendLine("Key files:")
        foreach ($f in $layer.Value.KeyFiles) {
            [void]$sb.AppendLine("  - ${q}${f}${q}")
        }
        [void]$sb.AppendLine("")
    }
    [void]$sb.AppendLine("## Core Data Flows")
    foreach ($df in $topology.DataFlows) {
        [void]$sb.AppendLine("- $df")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Metrics & Test Inventory")
    [void]$sb.AppendLine("- Dart Source Files in lib/: $($topology.Metrics.DartSourceFiles)")
    [void]$sb.AppendLine("- Executable Test Suites (total): $($topology.Metrics.TotalExecutableSuites)")
    [void]$sb.AppendLine("  - Dart Unit & Widget suites (test/*_test.dart): $($topology.Metrics.DartUnitAndWidgetSuites)")
    [void]$sb.AppendLine("  - Integration suites (integration_test/): $($topology.Metrics.IntegrationSuites)")
    [void]$sb.AppendLine("  - Developer tool test suites (tools/test_*.py): $($topology.Metrics.ToolTestSuites)")
    [void]$sb.AppendLine("- Estimated Individual Test Cases (test/testWidgets assertions): $($topology.Metrics.EstimatedIndividualTestCases)+")
    [void]$sb.AppendLine("- Test Support & Fixture Files in test/ (helpers, non-executable): $($topology.Metrics.SupportHelperFiles)")
    [void]$sb.AppendLine("- Registered Feature Domains: $($topology.Metrics.TotalRegisteredFeatures)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Tip: Use ${q}dev context <feature>${q} for detailed feature requirements, tokens, tests, and invariants.")

    return $sb.ToString()
}

function New-AgentHandoff {
    [CmdletBinding()]
    param(
        [string]$Note = '',
        [switch]$Json
    )
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
    $handoffDir = Join-Path $repoRoot '.buildlog\handoffs'
    if (-not (Test-Path -LiteralPath $handoffDir)) {
        New-Item -ItemType Directory -Force -Path $handoffDir | Out-Null
    }

    $branch = (& git branch --show-current 2>$null).Trim()
    $commit = (& git rev-parse HEAD 2>$null).Trim()
    $statusLines = & git status --porcelain 2>$null
    $dirty = [bool]$statusLines

    $impact = if (Get-Command 'Invoke-ImpactAnalysis' -ErrorAction SilentlyContinue) {
        Invoke-ImpactAnalysis
    } else { $null }

    $evidenceDir = Join-Path $repoRoot '.buildlog\evidence'
    $evidenceCount = if (Test-Path -LiteralPath $evidenceDir) {
        @(Get-ChildItem -LiteralPath $evidenceDir -Filter *.json -File).Count
    } else { 0 }

    $checkpoint = [pscustomobject]@{
        Timestamp = (Get-Date -Format 'o')
        Branch = $branch
        Commit = $commit
        IsDirty = $dirty
        DirtyFiles = @(if ($statusLines) { $statusLines | ForEach-Object { if ($_.Length -ge 4) { $_.Substring(3).Trim() } } } else { @() })
        Note = $Note
        CachedEvidenceCount = $evidenceCount
        ImpactAnalysis = if ($impact) {
            [pscustomobject]@{
                ChangedFilesCount = $impact.ChangedFilesCount
                SelectedTests = @($impact.SelectedTests)
                AffectedFeatures = @($impact.AffectedFeatures)
            }
        } else { $null }
    }

    $jsonStr = $checkpoint | ConvertTo-Json -Depth 5
    $latestPath = Join-Path $handoffDir 'latest.json'
    $timestampPath = Join-Path $handoffDir "handoff-$((Get-Date).ToString('yyyyMMdd-HHmmss')).json"
    [IO.File]::WriteAllText($latestPath, $jsonStr, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($timestampPath, $jsonStr, [Text.Encoding]::UTF8)

    if ($Json) { return $jsonStr }

    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "               TODORBIT AGENT HANDOFF CHECKPOINT                 " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Checkpoint:      $latestPath" -ForegroundColor Green
    Write-Host "Branch:          $branch ($($commit.Substring(0,8))) [Dirty: $dirty]" -ForegroundColor White
    Write-Host "Cached Receipts: $evidenceCount passing test receipts" -ForegroundColor Gray
    if ($checkpoint.DirtyFiles.Count -gt 0) {
        Write-Host "Dirty Files ($($checkpoint.DirtyFiles.Count)):" -ForegroundColor Yellow
        foreach ($df in $checkpoint.DirtyFiles) { Write-Host " - $df" -ForegroundColor Gray }
    }
    if ($impact -and $impact.SelectedTests.Count -gt 0) {
        Write-Host "Pending / Impact-Selected Tests ($($impact.SelectedTests.Count)):" -ForegroundColor Cyan
        foreach ($st in $impact.SelectedTests) { Write-Host " - $st" -ForegroundColor White }
    }
    Write-Host "=================================================================" -ForegroundColor Cyan
    return $checkpoint
}

function Resume-AgentHandoff {
    [CmdletBinding()]
    param([switch]$Json)

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
    $latestPath = Join-Path $repoRoot '.buildlog\handoffs\latest.json'
    if (-not (Test-Path -LiteralPath $latestPath)) {
        Write-Host "No active handoff checkpoint found in .buildlog/handoffs/latest.json." -ForegroundColor Yellow
        return $null
    }

    $checkpoint = Get-Content -LiteralPath $latestPath -Raw | ConvertFrom-Json
    $currentCommit = (& git rev-parse HEAD 2>$null).Trim()
    $statusLines = & git status --porcelain 2>$null
    $isCommitMatched = ($checkpoint.Commit -eq $currentCommit)

    $result = [pscustomobject]@{
        CheckpointTimestamp = $checkpoint.Timestamp
        RecordedBranch = $checkpoint.Branch
        RecordedCommit = $checkpoint.Commit
        CurrentCommit = $currentCommit
        CommitMatches = $isCommitMatched
        RecordedDirtyFiles = @($checkpoint.DirtyFiles)
        CurrentDirtyFiles = @(if ($statusLines) { $statusLines | ForEach-Object { if ($_.Length -ge 4) { $_.Substring(3).Trim() } } } else { @() })
        PendingImpactTests = if ($checkpoint.ImpactAnalysis) { @($checkpoint.ImpactAnalysis.SelectedTests) } else { @() }
    }

    if ($Json) { return ($result | ConvertTo-Json -Depth 5) }

    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "               RESUMED AGENT ENGINEERING CONTEXT                 " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "Checkpoint From:   $($result.CheckpointTimestamp)" -ForegroundColor White
    Write-Host "Branch:            $($result.RecordedBranch)" -ForegroundColor Gray
    Write-Host "Commit Integrity:  $(if ($isCommitMatched) { 'MATCHED' } else { 'DRIFT DETECTED' }) (Recorded: $($checkpoint.Commit.Substring(0,8)), Current: $($currentCommit.Substring(0,8)))" -ForegroundColor $(if ($isCommitMatched) { 'Green' } else { 'Yellow' })
    Write-Host "Pending Tests:     $($result.PendingImpactTests.Count)" -ForegroundColor Yellow
    foreach ($pt in $result.PendingImpactTests) { Write-Host " - $pt" -ForegroundColor Gray }
    Write-Host "=================================================================" -ForegroundColor Cyan
    return $result
}

Export-ModuleMember -Function Get-FeatureContextPack, Get-RepositoryMap, New-AgentHandoff, Resume-AgentHandoff
