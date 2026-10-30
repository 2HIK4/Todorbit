param([string]$Executable = 'build/windows/x64/runner/Release/TodorbitWidget.exe')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$executablePath = (Resolve-Path -LiteralPath (Join-Path $repo $Executable)).Path
$root = Join-Path $repo ('.buildlog/native-self-test/' + [guid]::NewGuid().ToString('N'))
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $executablePath
$info.Arguments = '--self-test'
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.EnvironmentVariables['APPDATA'] = Join-Path $root 'Roaming'
$info.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $root 'Local'
New-Item -ItemType Directory -Force -Path $info.EnvironmentVariables['APPDATA'],$info.EnvironmentVariables['LOCALAPPDATA'] | Out-Null
Write-Output "Native self-test: APPDATA=$($info.EnvironmentVariables['APPDATA']); LOCALAPPDATA=$($info.EnvironmentVariables['LOCALAPPDATA'])"
$process = [Diagnostics.Process]::Start($info)
$process.WaitForExit()
if ($process.ExitCode -ne 0) { throw "Native self-test failed ($($process.ExitCode))." }
Write-Output 'Native self-test passed.'
