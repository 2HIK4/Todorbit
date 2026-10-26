# This runner intentionally refuses to install on the owner's normal account.
$ErrorActionPreference = 'Stop'
if ($env:USERNAME -cne 'WDAGUtilityAccount' -or $PSScriptRoot -cne 'C:\TodorbitPackages') {
  throw 'Run only through the prepared Windows Sandbox configuration.'
}
$work = 'C:\TodorbitAcceptance'
if (Test-Path -LiteralPath $work) { throw 'Acceptance requires a fresh Sandbox.' }
$null = New-Item -ItemType Directory -Path $work
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'packages.json') -Raw | ConvertFrom-Json
$checks = [Collections.Generic.List[string]]::new()
$status = 'FAIL'
try {
  foreach ($entry in $manifest.hashes.PSObject.Properties) {
    if ((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $entry.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.Value) { throw 'Package digest mismatch.' }
  }
  $checks.Add('Both package SHA-256 values match the prepared manifest')
  $installed = Join-Path $work 'Installed'
  function Install-Candidate {
    $setup = Join-Path $PSScriptRoot "Todorbit-$($manifest.version)-win-x64-setup.exe"
    $process = Start-Process -FilePath $setup -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$installed") -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw 'Sandbox installer failed.' }
  }
  Install-Candidate
  $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{8C3E7B4A-17A4-42D7-8C45-EBB4C79B6941}_is1'
  $registration = Get-ItemProperty -LiteralPath $key
  if ($registration.DisplayVersion -ne $manifest.version -or $registration.InstallLocation.TrimEnd('\') -ne $installed) { throw 'Installer registration mismatch.' }
  $checks.Add('Fresh per-user installer succeeds with matching registered version/path')
  $portableParent = Join-Path $work 'Portable With Spaces'
  Expand-Archive -LiteralPath (Join-Path $PSScriptRoot "Todorbit-$($manifest.version)-win-x64-portable.zip") -DestinationPath $portableParent
  $portable = Join-Path $portableParent 'Todorbit'
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SandboxSQLite {
  [DllImport("kernel32", CharSet=CharSet.Unicode)] public static extern bool SetDllDirectory(string value);
  [DllImport("sqlite3", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_open_v2([MarshalAs(UnmanagedType.LPUTF8Str)] string name, out IntPtr db, int flags, IntPtr vfs);
  [DllImport("sqlite3", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_close(IntPtr db);
  [DllImport("sqlite3", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_prepare_v2(IntPtr db, [MarshalAs(UnmanagedType.LPUTF8Str)] string sql, int bytes, out IntPtr statement, IntPtr tail);
  [DllImport("sqlite3", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_step(IntPtr statement);
  [DllImport("sqlite3", CallingConvention=CallingConvention.Cdecl)] static extern IntPtr sqlite3_column_text(IntPtr statement, int column);
  [DllImport("sqlite3", CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_finalize(IntPtr statement);
  public static string Scalar(string file, string sql) {
    IntPtr db = IntPtr.Zero, statement = IntPtr.Zero;
    try {
      if (sqlite3_open_v2(file, out db, 1, IntPtr.Zero) != 0 || sqlite3_prepare_v2(db, sql, -1, out statement, IntPtr.Zero) != 0 || sqlite3_step(statement) != 100) throw new Exception("SQLite read-only inspection failed");
      return Marshal.PtrToStringAnsi(sqlite3_column_text(statement, 0));
    } finally { if (statement != IntPtr.Zero) sqlite3_finalize(statement); if (db != IntPtr.Zero) sqlite3_close(db); }
  }
}
'@
  # Read via the portable DLL so the installer can later uninstall its files.
  if (-not [SandboxSQLite]::SetDllDirectory($portable)) { throw 'Cannot load packaged SQLite.' }
  $hasher = [Security.Cryptography.SHA256]::Create()
  try { $hash = $hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($portable.ToLowerInvariant())) }
  finally { $hasher.Dispose() }
  $suffix = [BitConverter]::ToString($hash).Replace('-','').Substring(0,16).ToLowerInvariant()
  $profiles = @(
    @{folder=$installed; profile=(Join-Path $env:APPDATA 'TodoPilot')},
    @{folder=$portable; profile=(Join-Path $env:APPDATA "TodoPilot\portable-$suffix")}
  )
  foreach ($item in $profiles) {
    $null = New-Item -ItemType Directory -Path $item.profile -Force
    '{"launchAtSignIn":false}' | Set-Content -LiteralPath (Join-Path $item.profile 'widget-settings.json') -Encoding UTF8
    $db = Join-Path $item.profile 'life_manager.sqlite'
    for ($restart = 0; $restart -lt 2; $restart++) {
      $info = [Diagnostics.ProcessStartInfo]::new()
      $info.FileName = Join-Path $item.folder 'Todorbit.exe'
      $info.WorkingDirectory = $item.folder
      $info.UseShellExecute = $false
      $info.WindowStyle = 'Hidden'
      $info.RedirectStandardOutput = $true
      $info.RedirectStandardError = $true
      $process = [Diagnostics.Process]::Start($info)
      $output = $process.StandardOutput.ReadToEndAsync()
      $errors = $process.StandardError.ReadToEndAsync()
      try {
        $ready = $false
        $deadline = [DateTime]::UtcNow.AddSeconds(90)
        while ([DateTime]::UtcNow -lt $deadline -and -not $process.HasExited) {
          try {
            if ((Test-Path -LiteralPath $db) -and [SandboxSQLite]::Scalar($db,'PRAGMA user_version') -eq '21' -and [SandboxSQLite]::Scalar($db,"SELECT count(*) FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'") -eq '44') { $ready = $true; break }
          } catch { }
          Start-Sleep -Milliseconds 250
        }
        if (-not $ready -or [SandboxSQLite]::Scalar($db,'PRAGMA integrity_check') -ne 'ok') { throw 'Packaged schema readiness/integrity failed.' }
      } finally {
        if (-not $process.HasExited) { $process.Kill() }
        $process.WaitForExit()
        $null = $output.GetAwaiter().GetResult()
        $null = $errors.GetAwaiter().GetResult()
        $process.Dispose()
      }
    }
  }
  $checks.Add('Installer and path-with-spaces portable create/reopen separate schema-21, 44-table profiles with integrity OK')
  $widget = Start-Process -FilePath (Join-Path $portable 'TodorbitWidget.exe') -ArgumentList '--self-test' -Wait -PassThru -WindowStyle Hidden
  if ($widget.ExitCode -ne 0) { throw 'Packaged widget self-test failed.' }
  $checks.Add('Packaged native widget self-test succeeds')
  $installedDb = Join-Path $profiles[0].profile 'life_manager.sqlite'
  $before = (Get-FileHash -LiteralPath $installedDb -Algorithm SHA256).Hash
  $uninstall = Start-Process -FilePath (Join-Path $installed 'unins000.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait -PassThru -WindowStyle Hidden
  if ($uninstall.ExitCode -ne 0 -or (Test-Path -LiteralPath $key) -or (Get-FileHash -LiteralPath $installedDb -Algorithm SHA256).Hash -ne $before) { throw 'Uninstall/profile preservation check failed.' }
  Install-Candidate
  $checks.Add('Uninstall removes registration while preserving database bytes; reinstall succeeds')
  $status = 'PASS'
} catch {
  # There are no OAuth calls or credentials in this smoke runner. Still emit
  # only the stage/type, never application stdout, account labels or token data.
  $checks.Add('Stopped: ' + $_.Exception.GetType().Name)
} finally {
  @{status=$status; checks=@($checks); gui='UNVERIFIED'; google='UNVERIFIED'; cleanWindowsIdentity=$true} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath 'C:\TodorbitResults\acceptance.json' -Encoding UTF8
}
Write-Host "Sandbox process/schema smoke: $status. See C:\TodorbitResults\acceptance.json."
Write-Host 'Manual GUI/OAuth checks are still required. No user tokens were copied into this VM.'
Write-Host "Installer: $installed\Todorbit.exe"
Write-Host "Portable: $portable\Todorbit.exe"
Read-Host 'Press Enter to close this report; keep Sandbox open for manual acceptance'
