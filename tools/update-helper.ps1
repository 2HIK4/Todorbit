param(
  [ValidateSet('installed', 'portable')][string]$Mode,
  [Parameter(Mandatory)][string]$Package,
  [Parameter(Mandatory)][string]$Target,
  [Parameter(Mandatory)][string]$Digest,
  [Parameter(Mandatory)][long]$Size,
  [Parameter(Mandatory)][int]$ParentPid,
  [string]$Stage = ''
)

$ErrorActionPreference = 'Stop'
$status = Join-Path (Split-Path -Parent $Package) 'last-install-result.txt'
$rollback = ''
try {
  $packagePath = [IO.Path]::GetFullPath($Package)
  $targetPath = [IO.Path]::GetFullPath($Target).TrimEnd('\')
  if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
    throw 'The staged package is missing.'
  }
  if ((Get-Item -LiteralPath $packagePath).Length -ne $Size -or
      (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash -ine $Digest) {
    throw 'The staged package changed after verification.'
  }
  if (-not (Test-Path -LiteralPath (Join-Path $targetPath 'Todorbit.exe') -PathType Leaf)) {
    throw 'The current Todorbit installation is missing.'
  }
  $oldProcess = Get-Process -Id $ParentPid -ErrorAction SilentlyContinue
  if ($oldProcess) {
    $oldProcess | Wait-Process -Timeout 90
  }
  # The widget is a separate process and can keep files in the bundle locked
  # after its IPC exit command has returned.
  $widgetPath = Join-Path $targetPath 'TodorbitWidget.exe'
  $widgetDeadline = (Get-Date).AddSeconds(15)
  do {
    $widgets = @(Get-Process -Name TodorbitWidget -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path -and [IO.Path]::GetFullPath($_.Path) -ieq $widgetPath } catch { $false }
    })
    if ($widgets.Count -eq 0) { break }
    Start-Sleep -Milliseconds 250
  } while ((Get-Date) -lt $widgetDeadline)
  if ($widgets.Count -gt 0) {
    throw 'The native widget did not close. The existing installation was left in place.'
  }
  if ($Mode -eq 'installed') {
    if ([IO.Path]::GetExtension($packagePath) -ine '.exe') {
      throw 'Installed updates require the verified setup executable.'
    }
    $registration = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{8C3E7B4A-17A4-42D7-8C45-EBB4C79B6941}_is1' -ErrorAction SilentlyContinue
    if (-not $registration -or
        [IO.Path]::GetFullPath($registration.InstallLocation).TrimEnd('\') -ine $targetPath) {
      throw 'This copy is not the registered Todorbit installation. Use the portable update path or reinstall after a verified backup.'
    }
    $setup = Start-Process -FilePath $packagePath -ArgumentList @('/SILENT', '/NORESTART', '/CLOSEAPPLICATIONS') -PassThru -Wait
    if ($setup.ExitCode -ne 0) {
      throw "The installer exited with code $($setup.ExitCode)."
    }
  } else {
    if ([IO.Path]::GetExtension($packagePath) -ine '.zip') {
      throw 'Portable updates require the verified ZIP.'
    }
    $stagePath = [IO.Path]::GetFullPath($Stage).TrimEnd('\')
    $parent = [IO.Path]::GetDirectoryName($targetPath)
    if ([IO.Path]::GetDirectoryName($stagePath) -ine $parent -or
        $stagePath -ieq $targetPath -or
        -not (Test-Path -LiteralPath (Join-Path $stagePath 'Todorbit.exe') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $stagePath 'PORTABLE-MODE') -PathType Leaf)) {
      throw 'The staged portable folder is invalid.'
    }
    $rollback = Join-Path $parent ('.todorbit-rollback-' + [guid]::NewGuid().ToString('N'))
    Move-Item -LiteralPath $targetPath -Destination $rollback
    try {
      Move-Item -LiteralPath $stagePath -Destination $targetPath
    } catch {
      Move-Item -LiteralPath $rollback -Destination $targetPath
      throw
    }
  }
  try {
    $started = Start-Process -FilePath (Join-Path $targetPath 'Todorbit.exe') -WorkingDirectory $targetPath -PassThru
    Start-Sleep -Seconds 3
    $started.Refresh()
    if ($started.HasExited) {
      throw "Updated Todorbit exited immediately (code $($started.ExitCode))."
    }
  } catch {
    if ($Mode -eq 'portable' -and $rollback -and
        (Test-Path -LiteralPath $rollback -PathType Container)) {
      $failed = Join-Path ([IO.Path]::GetDirectoryName($targetPath)) ('.todorbit-failed-' + [guid]::NewGuid().ToString('N'))
      Move-Item -LiteralPath $targetPath -Destination $failed
      Move-Item -LiteralPath $rollback -Destination $targetPath
    }
    throw
  }
  Set-Content -LiteralPath $status -Value 'Update installed and Todorbit restart requested.'
} catch {
  Set-Content -LiteralPath $status -Value ('Update failed: ' + $_.Exception.Message)
  exit 1
}
