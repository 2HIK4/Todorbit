param(
  [ValidateSet('installed', 'portable')][string]$Mode,
  [Parameter(Mandatory)][string]$Package,
  [Parameter(Mandatory)][string]$Target,
  [Parameter(Mandatory)][string]$Digest,
  [Parameter(Mandatory)][long]$Size,
  [Parameter(Mandatory)][int]$ParentPid,
  [Parameter(Mandatory)][string]$ReadyFile,
  [Parameter(Mandatory)][string]$ExpectedVersion,
  [switch]$ShowErrors,
  [string]$Stage = ''
)

$ErrorActionPreference = 'Stop'
$status = Join-Path (Split-Path -Parent $Package) 'last-install-result.txt'
$rollback = ''
$handedOff = $false
$updateMutex = $null
$ownsUpdateMutex = $false
try {
  $packagePath = [IO.Path]::GetFullPath($Package)
  $targetPath = [IO.Path]::GetFullPath($Target).TrimEnd('\')
  if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
    throw 'The staged package is missing.'
  }
  $stream = [IO.File]::OpenRead($packagePath)
  try {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
      $actualDigest = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '')
    } finally {
      $hasher.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
  if ((Get-Item -LiteralPath $packagePath).Length -ne $Size -or
      $actualDigest -ine $Digest) {
    throw 'The staged package changed after verification.'
  }
  if (-not (Test-Path -LiteralPath (Join-Path $targetPath 'Todorbit.exe') -PathType Leaf)) {
    throw 'The current Todorbit installation is missing.'
  }
  if ($Mode -eq 'installed') {
    if ([IO.Path]::GetExtension($packagePath) -ine '.exe') {
      throw 'Installed updates require the verified setup executable.'
    }
    $registration = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{8C3E7B4A-17A4-42D7-8C45-EBB4C79B6941}_is1' -ErrorAction SilentlyContinue
    if (-not $registration -or
        [IO.Path]::GetFullPath($registration.InstallLocation).TrimEnd('\') -ine $targetPath) {
      throw 'This copy is not the registered Todorbit installation. The existing installation was left in place.'
    }
  }
  $appPath = Join-Path $targetPath 'Todorbit.exe'
  $updateMutex = [System.Threading.Mutex]::new($false, 'Local\TodorbitUpdateHandoff')
  $ownsUpdateMutex = $updateMutex.WaitOne(0)
  if (-not $ownsUpdateMutex) {
    throw 'Another Todorbit update is already running. Wait for it to finish, then retry.'
  }
  for ($attempt = 0; $attempt -lt 20; $attempt++) {
    $otherApps = @(Get-Process -Name Todorbit -ErrorAction SilentlyContinue | Where-Object {
      try {
        $_.Id -ne $ParentPid -and $_.Path -and
          [IO.Path]::GetFullPath($_.Path) -ieq $appPath
      } catch { $false }
    })
    if ($otherApps.Count -eq 0) { break }
    Start-Sleep -Milliseconds 100
  }
  if ($otherApps.Count -gt 0) {
    $ids = ($otherApps | ForEach-Object { $_.Id }) -join ', '
    throw "Another Todorbit process is using this installation (PID $ids). Close it and retry."
  }
  # The app must observe this file before closing. Without the handshake a
  # failed PowerShell startup leaves no visible explanation or recovery path.
  Set-Content -LiteralPath $ReadyFile -Value 'Helper ready.'
  $oldProcess = Get-Process -Id $ParentPid -ErrorAction SilentlyContinue
  if ($oldProcess) {
    $oldProcess | Wait-Process -Timeout 90
  }
  for ($attempt = 0; $attempt -lt 20; $attempt++) {
    $apps = @(Get-Process -Name Todorbit -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path -and [IO.Path]::GetFullPath($_.Path) -ieq $appPath } catch { $false }
    })
    if ($apps.Count -eq 0) { break }
    Start-Sleep -Milliseconds 100
  }
  if ($apps.Count -gt 0) {
    $ids = ($apps | ForEach-Object { $_.Id }) -join ', '
    throw "A Todorbit process started during the update handoff (PID $ids). Close it and retry."
  }
  $handedOff = $true
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
    $installerLog = Join-Path (Split-Path -Parent $packagePath) 'installer.log'
    $setup = Start-Process -FilePath $packagePath -ArgumentList @('/SILENT', '/NORESTART', '/CLOSEAPPLICATIONS', ('/LOG="' + $installerLog + '"')) -PassThru -Wait
    if ($setup.ExitCode -ne 0) {
      $reason = switch ($setup.ExitCode) {
        { $_ -in 2, 5 } { 'Installation was canceled.'; break }
        8 { 'Windows must restart before installation can continue.'; break }
        7 { 'Windows could not prepare this installation.'; break }
        default { 'The installer could not complete.' }
      }
      throw "$reason Installer exit code $($setup.ExitCode). See installer.log for details."
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
    $installedVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $targetPath 'Todorbit.exe')).ProductVersion
    if ($installedVersion -ne $ExpectedVersion -and
        -not $installedVersion.StartsWith($ExpectedVersion + '+')) {
      throw "Installed version $installedVersion does not match expected $ExpectedVersion."
    }
    $started = Start-Process -FilePath (Join-Path $targetPath 'Todorbit.exe') -ArgumentList '--update-restart' -WorkingDirectory $targetPath -PassThru
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
  Set-Content -LiteralPath $status -Value "Update installed: $installedVersion. Todorbit restart requested."
} catch {
  $failureMessage = $_.Exception.Message
  Set-Content -LiteralPath $status -Value ('Update failed: ' + $failureMessage)
  if ($targetPath -and
      (Test-Path -LiteralPath (Join-Path $targetPath 'Todorbit.exe') -PathType Leaf)) {
    try {
      $running = @(Get-Process -Name Todorbit -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -and [IO.Path]::GetFullPath($_.Path) -ieq (Join-Path $targetPath 'Todorbit.exe') } catch { $false }
      })
      if ($running.Count -eq 0) {
        Start-Process -FilePath (Join-Path $targetPath 'Todorbit.exe') -WorkingDirectory $targetPath | Out-Null
      }
    } catch {}
  }
  if ($ShowErrors -and $handedOff) {
    try {
      Add-Type -AssemblyName System.Windows.Forms
      [System.Windows.Forms.MessageBox]::Show(
        "Update failed: $failureMessage`r`n`r`n" +
        'Todorbit attempted to reopen the available installation. ' +
        'Open Settings > Software Updates to retry. If Todorbit does not open, ' +
        'run a verified installer manually and keep the profile data untouched.',
        'Todorbit update failed',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    } catch {}
  }
  exit 1
} finally {
  if ($ownsUpdateMutex) { $updateMutex.ReleaseMutex() }
  if ($updateMutex) { $updateMutex.Dispose() }
}
