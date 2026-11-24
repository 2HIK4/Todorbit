# Registry.psm1 - Todorbit Centralized Test & Automation Registry
# Automatically discovers, categorizes, validates, and reports all repository test suites.
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Get-RegistryPath {
    return Join-Path (Get-RepoRoot) 'tools\dev\registry.json'
}

function Build-TestRegistry {
    [CmdletBinding()]
    param()

    $repoRoot = Get-RepoRoot
    $featuresJsonPath = Join-Path $repoRoot 'tools\dev\features.json'
    $featureCatalog = $null
    if (Test-Path -LiteralPath $featuresJsonPath) {
        $featureCatalog = Get-Content -LiteralPath $featuresJsonPath -Raw | ConvertFrom-Json
    }

    $testsList = [Collections.Generic.List[object]]::new()
    $seenIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $totalTestCases = 0

    # 1. Discover Dart test suites in test/ (only executable suites matching *_test.dart)
    $dartTestFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'test') -Recurse -File -Filter '*_test.dart')
    $supportHelpers = @(Get-ChildItem -Path (Join-Path $repoRoot 'test') -Recurse -File -Filter '*.dart' | Where-Object { $_.Name -notmatch '_test\.dart$' })

    foreach ($file in $dartTestFiles) {
        $relPath = ($file.FullName.Substring($repoRoot.Length + 1)).Replace('\', '/')
        $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $id = "test:$baseName"
        if ($seenIds.Contains($id)) {
            $id = "test:$relPath"
        }
        $seenIds.Add($id) | Out-Null

        # Count granular test cases
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $matches = [regex]::Matches($content, '\b(?:test|testWidgets)\s*\(')
            $totalTestCases += $matches.Count
        }

        # Analyze feature mappings
        $associatedFeatures = [Collections.Generic.List[string]]::new()
        if ($featureCatalog) {
            foreach ($prop in $featureCatalog.PSObject.Properties) {
                $featName = $prop.Name
                $featTests = @($prop.Value.tests)
                if ($featTests -contains $relPath) {
                    $associatedFeatures.Add($featName)
                }
            }
        }

        # If not explicitly mapped, infer feature from name or directory
        if ($associatedFeatures.Count -eq 0) {
            if ($relPath -match 'calendar') { $associatedFeatures.Add('calendar') }
            elseif ($relPath -match 'task|workspace') { $associatedFeatures.Add('tasks') }
            elseif ($relPath -match 'sync') { $associatedFeatures.Add('sync') }
            elseif ($relPath -match 'habit') { $associatedFeatures.Add('habits') }
            elseif ($relPath -match 'goal') { $associatedFeatures.Add('goals') }
            elseif ($relPath -match 'timer|focus') { $associatedFeatures.Add('task-timers') }
            elseif ($relPath -match 'settings|appearance|theme') { $associatedFeatures.Add('settings') }
            elseif ($relPath -match 'widget') { $associatedFeatures.Add('widgets') }
            elseif ($relPath -match 'alarm') { $associatedFeatures.Add('alarms') }
            elseif ($relPath -match 'database|migration|repository') { $associatedFeatures.Add('database') }
            elseif ($relPath -match 'update') { $associatedFeatures.Add('windows-updates') }
            else { $associatedFeatures.Add('shared') }
        }

        # Determine Tier and Evidence Reuse Eligibility
        $tier = 'Level1_Fast'
        $evidenceEligibility = 'Eligible'
        if ($relPath -match 'migration|database|journal|persistence|concurrency|sync_apply|sync_lease|crash_recovery|undo_redo|safety') {
            $tier = 'Level2_Critical'
            $evidenceEligibility = 'Eligible'
        } elseif ($relPath -match 'journeys|stress|benchmark|mobile_workspace|integration') {
            $tier = 'Level3_DeferredRegression'
            $evidenceEligibility = 'Eligible'
        }

        # Enforce non-cacheable / environment-gated / screenshot-side-effect tests in code
        # so `dev registry --refresh` can never reset or bypass cache eligibility.
        if ($relPath -match 'runtime_workflow_journey_test\.dart$|startup_recovery_journeys_test\.dart$|resource_journeys_test\.dart$|native_widget_launch_integration_test\.dart$|performance_benchmark_test\.dart$|lab_render_test\.dart$') {
            $evidenceEligibility = 'Ineligible'
        }

        # Determine supported platforms
        $platforms = @('Windows', 'Android')
        if ($relPath -match 'android') { $platforms = @('Android') }
        elseif ($relPath -match 'windows') { $platforms = @('Windows') }

        $testsList.Add([pscustomobject]@{
            Id = $id
            Type = 'flutter_test'
            Path = $relPath
            Command = "flutter test --no-pub --reporter=expanded $relPath"
            Tier = $tier
            Features = @($associatedFeatures.ToArray())
            Platforms = $platforms
            EvidenceReuse = $evidenceEligibility
            Description = "Automated Flutter test suite: $baseName"
            Prerequisites = @('flutter_sdk', 'pub_get')
        })
    }

    # 2. Discover Integration Tests in integration_test/
    $intTestFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'integration_test') -Recurse -File -Filter *.dart -ErrorAction SilentlyContinue)
    foreach ($file in $intTestFiles) {
        $relPath = ($file.FullName.Substring($repoRoot.Length + 1)).Replace('\', '/')
        $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $id = "integration:$baseName"
        $seenIds.Add($id) | Out-Null

        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $matches = [regex]::Matches($content, '\b(?:test|testWidgets)\s*\(')
            $totalTestCases += $matches.Count
        }

        $testsList.Add([pscustomobject]@{
            Id = $id
            Type = 'integration_test'
            Path = $relPath
            Command = "flutter test --no-pub $relPath"
            Tier = 'Level3_DeferredRegression'
            Features = @('mobile', 'integration')
            Platforms = @('Android')
            EvidenceReuse = 'Ineligible'
            Description = "Integration workflow test: $baseName"
            Prerequisites = @('flutter_sdk', 'android_emulator')
        })
    }

    # 3. Discover Tool unit tests in tools/
    $pyTestFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'tools') -Recurse -File -Filter test_*.py -ErrorAction SilentlyContinue)
    foreach ($file in $pyTestFiles) {
        $relPath = ($file.FullName.Substring($repoRoot.Length + 1)).Replace('\', '/')
        $baseName = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $id = "tool:$baseName"
        $seenIds.Add($id) | Out-Null

        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $matches = [regex]::Matches($content, '\bdef\s+test_[a-zA-Z0-9_]+\s*\(')
            $totalTestCases += $matches.Count
        }

        $testsList.Add([pscustomobject]@{
            Id = $id
            Type = 'python_test'
            Path = $relPath
            Command = "python -m unittest discover -s tools -p $($file.Name)"
            Tier = if ($baseName -match 'boundary|architecture|safety|evidence') { 'Level2_Critical' } else { 'Level1_Fast' }
            Features = @('architecture', 'dev-tools')
            Platforms = @('Windows', 'Host')
            EvidenceReuse = 'Ineligible'
            Description = "Developer tool/architecture test: $baseName"
            Prerequisites = @('python')
        })
    }

    # 4. Check-docs validator
    $testsList.Add([pscustomobject]@{
        Id = "tool:check-docs"
        Type = "python_script"
        Path = "tools/dev/check-docs.py"
        Command = "python tools/dev/check-docs.py"
        Tier = "Level1_Fast"
        Features = @("documentation", "architecture")
        Platforms = @("Host")
        EvidenceReuse = "Ineligible"
        Description = "Documentation, map and catalog integrity validator"
        Prerequisites = @("python")
    })
    $totalTestCases += 1

    $metrics = [pscustomobject]@{
        TotalExecutableSuites = $testsList.Count
        DartUnitAndWidgetSuites = $dartTestFiles.Count
        IntegrationSuites = $intTestFiles.Count
        ToolTestSuites = $pyTestFiles.Count + 1
        SupportHelperFiles = $supportHelpers.Count
        EstimatedIndividualTestCases = $totalTestCases
    }

    $registry = [pscustomobject]@{
        Version = '2.0.0'
        GeneratedAt = (Get-Date -Format 'o')
        TotalTests = $testsList.Count
        Metrics = $metrics
        SupportHelpers = @($supportHelpers | ForEach-Object { ($_.FullName.Substring($repoRoot.Length + 1)).Replace('\', '/') })
        Tests = @($testsList.ToArray())
    }

    return $registry
}

function Save-TestRegistry {
    [CmdletBinding()]
    param()
    $registry = Build-TestRegistry
    $regPath = Get-RegistryPath
    $json = $registry | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($regPath, $json, [Text.UTF8Encoding]::new($false))
    return $registry
}

function Get-TestRegistry {
    [CmdletBinding()]
    param(
        [switch]$Refresh
    )
    $regPath = Get-RegistryPath
    if ($Refresh -or -not (Test-Path -LiteralPath $regPath)) {
        return (Save-TestRegistry)
    }
    try {
        $content = Get-Content -LiteralPath $regPath -Raw | ConvertFrom-Json
        return $content
    } catch {
        return (Save-TestRegistry)
    }
}

function Test-TestRegistry {
    [CmdletBinding()]
    param()

    $repoRoot = Get-RepoRoot
    $registry = Get-TestRegistry
    $issues = [Collections.Generic.List[string]]::new()

    # Check 1: Ensure all registered test files actually exist on disk
    foreach ($entry in $registry.Tests) {
        $abs = Join-Path $repoRoot ($entry.Path.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $abs)) {
            $issues.Add("Missing test file on disk for registered id '$($entry.Id)': $($entry.Path)")
        }
    }

    # Check 2: Check for any unregistered test files in test/ (matching *_test.dart)
    $existingTestFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'test') -Recurse -File -Filter '*_test.dart')
    $registeredPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $registry.Tests) {
        $registeredPaths.Add($entry.Path) | Out-Null
    }
    foreach ($tf in $existingTestFiles) {
        $rel = ($tf.FullName.Substring($repoRoot.Length + 1)).Replace('\', '/')
        if (-not $registeredPaths.Contains($rel)) {
            $issues.Add("Unregistered test file detected on disk: $rel")
        }
    }

    # Check 3: Ensure integration_test/*.dart and tools/**/test_*.py are also registered
    $intFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'integration_test') -Recurse -File -Filter '*.dart' -ErrorAction SilentlyContinue)
    foreach ($inf in $intFiles) {
        $rel = ($inf.FullName.Substring($repoRoot.Length + 1)).Replace('\', '/')
        if (-not $registeredPaths.Contains($rel)) {
            $issues.Add("Unregistered integration test detected on disk: $rel")
        }
    }
    $pyFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'tools') -Recurse -File -Filter 'test_*.py' -ErrorAction SilentlyContinue)
    foreach ($pf in $pyFiles) {
        $rel = ($pf.FullName.Substring($repoRoot.Length + 1)).Replace('\', '/')
        if (-not $registeredPaths.Contains($rel)) {
            $issues.Add("Unregistered tool test detected on disk: $rel")
        }
    }

    # Check 4: Enforce cache-ineligibility invariants so registry edits cannot silently make non-cacheable tests eligible
    $ineligiblePattern = 'runtime_workflow_journey_test\.dart$|startup_recovery_journeys_test\.dart$|resource_journeys_test\.dart$|native_widget_launch_integration_test\.dart$|performance_benchmark_test\.dart$|lab_render_test\.dart$'
    foreach ($entry in $registry.Tests) {
        $mustBeIneligible = ($entry.Type -in @('integration_test', 'python_test', 'python_script')) -or ($entry.Path -match $ineligiblePattern)
        if ($mustBeIneligible -and $entry.EvidenceReuse -ne 'Ineligible') {
            $issues.Add("Non-cacheable test '$($entry.Path)' must have EvidenceReuse='Ineligible' (found '$($entry.EvidenceReuse)').")
        }
    }

    return [pscustomobject]@{
        Valid = ($issues.Count -eq 0)
        TotalTests = $registry.Tests.Count
        IssuesCount = $issues.Count
        Issues = @($issues.ToArray())
    }
}

Export-ModuleMember -Function Build-TestRegistry, Save-TestRegistry, Get-TestRegistry, Test-TestRegistry
