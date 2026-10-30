# Stream native output without PowerShell 5 interpreting stderr as termination.
# Callers still receive every warning and a terminating error on nonzero exit.
function Invoke-TodorbitNative {
  param(
    [Parameter(Mandatory=$true)][string]$Command,
    [string[]]$ArgumentList = @(),
    [string]$InputText,
    [string]$FailureMessage = 'Native command failed'
  )
  $null = Get-Command $Command -ErrorAction Stop
  $savedPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    if ($PSBoundParameters.ContainsKey('InputText')) {
      $InputText | & $Command @ArgumentList 2>&1 | ForEach-Object { $_.ToString() }
    } else {
      & $Command @ArgumentList 2>&1 | ForEach-Object { $_.ToString() }
    }
    $nativeExitCode = $LASTEXITCODE
  } finally { $ErrorActionPreference = $savedPreference }
  if ($nativeExitCode -ne 0) { throw "$FailureMessage ($nativeExitCode)." }
}
