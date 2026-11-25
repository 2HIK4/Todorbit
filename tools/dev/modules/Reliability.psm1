<#
.SYNOPSIS
    Todorbit Developer Automation Toolkit - Reliability & Package Verification Module
.DESCRIPTION
    Audits release package artifacts (x64 PE binaries, CRT dependencies, 16 KiB ELF alignment, Inno Setup),
    and executes reliability and fault-injection verification.
#>

$ErrorActionPreference = 'Stop'

function Invoke-PackageVerification {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [ValidateSet('Windows', 'Android', 'All')]
        [string]$Platform = 'All',

        [switch]$ConfigOnly,
        [switch]$RequireArtifacts,
        [switch]$Json
    )

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path

    $pythonExe = (Get-Command 'python.exe' -ErrorAction SilentlyContinue).Source
    if (-not $pythonExe) {
        $pythonExe = (Get-Command 'python' -ErrorAction SilentlyContinue).Source
    }
    if (-not $pythonExe) {
        throw "Python executable not found in PATH."
    }

    $results = @{}
    $configPassed = $true
    $artifactFailed = $false
    $artifactsInspected = 0
    $missingPlatforms = [Collections.Generic.List[string]]::new()

    if ($Platform -eq 'Windows' -or $Platform -eq 'All') {
        $winScript = Join-Path $repoRoot 'tools\verify-windows-artifact.py'
        if (Test-Path -LiteralPath $winScript) {
            $winRaw = & $pythonExe $winScript
            $winExit = $LASTEXITCODE
            $winObj = $winRaw | ConvertFrom-Json
            $results['Windows'] = $winObj
            if ($winExit -ne 0 -or -not $winObj.config_passed) {
                $configPassed = $false
            }
            $winCount = [int]$winObj.artifacts_inspected
            $artifactsInspected += $winCount
            if ($winCount -eq 0) {
                $missingPlatforms.Add('Windows')
            } elseif (-not $winObj.artifacts_passed) {
                $artifactFailed = $true
            }
        } else {
            $configPassed = $false
        }
    }

    if ($Platform -eq 'Android' -or $Platform -eq 'All') {
        $manifestPath = Join-Path $repoRoot 'android\app\src\main\AndroidManifest.xml'
        $hasManifest = Test-Path -LiteralPath $manifestPath
        $androidVerifier = Join-Path $repoRoot 'tools\verify-android-artifact.py'
        $hasVerifier = Test-Path -LiteralPath $androidVerifier
        $androidCfgOk = $hasManifest -and $hasVerifier
        if (-not $androidCfgOk) {
            $configPassed = $false
        }

        $apkCandidates = [Collections.Generic.List[string]]::new()
        $apkOutDir = Join-Path $repoRoot 'build\app\outputs\flutter-apk'
        if (Test-Path -LiteralPath $apkOutDir) {
            foreach ($apk in (Get-ChildItem -LiteralPath $apkOutDir -Filter '*.apk' -File -ErrorAction SilentlyContinue)) {
                $apkCandidates.Add($apk.FullName)
            }
        }
        $candidateApk = Join-Path $repoRoot '.buildlog\16k-runtime\candidate.apk'
        if (Test-Path -LiteralPath $candidateApk) {
            $apkCandidates.Add($candidateApk)
        }

        $apksAudited = [Collections.Generic.List[object]]::new()
        foreach ($apkPath in ($apkCandidates | Select-Object -Unique)) {
            $apkOut = & $pythonExe $androidVerifier $apkPath 2>&1
            $apkOk = ($LASTEXITCODE -eq 0)
            if (-not $apkOk) { $artifactFailed = $true }
            $apksAudited.Add([pscustomobject]@{
                File = [IO.Path]::GetFileName($apkPath)
                Path = $apkPath
                Passed = $apkOk
                Detail = (($apkOut | ForEach-Object { $_.ToString() }) -join '; ')
            })
        }

        $androidCount = $apksAudited.Count
        $artifactsInspected += $androidCount
        if ($androidCount -eq 0) {
            $missingPlatforms.Add('Android')
        }

        $results['Android'] = [pscustomobject]@{
            ManifestExists = $hasManifest
            TargetSdk = 35
            Native16kVerificationAvailable = $hasVerifier
            ConfigPassed = $androidCfgOk
            ApksAudited = @($apksAudited.ToArray())
            ArtifactsInspected = $androidCount
            ArtifactsPassed = ($androidCount -gt 0) -and (-not ($apksAudited | Where-Object { -not $_.Passed }))
            Passed = $androidCfgOk -and ($androidCount -gt 0) -and (-not ($apksAudited | Where-Object { -not $_.Passed }))
        }
    }

    $artifactsPassed = ($artifactsInspected -gt 0) -and (-not $artifactFailed) -and ($missingPlatforms.Count -eq 0)
    $overallStatus = if (-not $configPassed -or $artifactFailed) {
        'FAIL'
    } elseif ($missingPlatforms.Count -gt 0 -or $artifactsInspected -eq 0) {
        'MISSING_ARTIFACTS'
    } else {
        'PASS'
    }
    $overallPassed = if ($ConfigOnly) {
        $configPassed -and (-not $artifactFailed)
    } else {
        ($overallStatus -eq 'PASS')
    }

    $summary = [pscustomobject]@{
        Platform = $Platform
        ConfigOnly = [bool]$ConfigOnly
        ConfigPassed = $configPassed
        ArtifactsInspected = $artifactsInspected
        ArtifactsPassed = $artifactsPassed
        MissingArtifactPlatforms = @($missingPlatforms.ToArray())
        OverallStatus = $overallStatus
        OverallPassed = $overallPassed
        Details = $results
    }

    if ($Json) {
        return ($summary | ConvertTo-Json -Depth 6)
    }

    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "             PACKAGE & ARTIFACT VERIFICATION REPORT             " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    $statusColor = switch ($overallStatus) {
        'PASS' { 'Green' }
        'MISSING_ARTIFACTS' { 'Yellow' }
        Default { 'Red' }
    }
    Write-Host "Overall Status:          $overallStatus" -ForegroundColor $statusColor
    Write-Host "Configuration Check:     $(if ($configPassed) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if ($configPassed) { 'Green' } else { 'Red' })
    Write-Host "Artifacts Inspected:     $artifactsInspected" -ForegroundColor $(if ($artifactsInspected -gt 0) { 'White' } else { 'Yellow' })
    if ($missingPlatforms.Count -gt 0) {
        Write-Host "Missing Artifacts For:   $($missingPlatforms -join ', ')" -ForegroundColor Yellow
    }
    Write-Host ""

    if ($results.ContainsKey('Windows')) {
        $w = $results['Windows']
        Write-Host "Windows Verification:" -ForegroundColor Yellow
        Write-Host "  Inno Setup Script:   $($w.inno_setup.script) [AppId: $($w.inno_setup.app_id)]" -ForegroundColor White
        Write-Host "  x64 Configured:      $($w.inno_setup.x64_configured)" -ForegroundColor Gray
        Write-Host "  Missing References:  $($w.inno_setup.missing_references.Count)" -ForegroundColor Gray
        Write-Host "  Binaries Audited:    $($w.artifacts_inspected) ($($w.artifact_status))" -ForegroundColor Gray
    }

    if ($results.ContainsKey('Android')) {
        $a = $results['Android']
        Write-Host "Android Verification:" -ForegroundColor Yellow
        Write-Host "  Manifest Exists:     $($a.ManifestExists)" -ForegroundColor White
        Write-Host "  16 KiB Tooling:      $($a.Native16kVerificationAvailable)" -ForegroundColor Gray
        Write-Host "  APKs Audited:        $($a.ArtifactsInspected)" -ForegroundColor Gray
    }
    Write-Host "=================================================================" -ForegroundColor Cyan

    if ($overallStatus -eq 'FAIL') {
        throw "Package verification failed."
    }
    if (-not $ConfigOnly -and $overallStatus -eq 'MISSING_ARTIFACTS') {
        throw "Package artifact verification incomplete: 0 artifacts found for $($missingPlatforms -join ', '). Build release artifacts or pass -ConfigOnly for configuration-only validation."
    }
}

Export-ModuleMember -Function Invoke-PackageVerification
