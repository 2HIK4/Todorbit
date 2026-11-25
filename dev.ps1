# dev.ps1 - Todorbit CLI root launcher
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)
$devPath = Join-Path $PSScriptRoot 'tools\dev\dev.ps1'
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $devPath @Arguments
exit $LASTEXITCODE
