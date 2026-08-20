param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,
  [Parameter(Mandatory = $true)]
  [string]$SummaryPath,
  [Parameter(Mandatory = $true)]
  [int]$Status
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
  $output = Get-Content -Raw -LiteralPath $InputPath
  $valid = [regex]::Match(
    $output,
    '(?m)^\s*valid tests:\s*(\d+)\s+passed,\s*(\d+)\s+failed\s*$'
  )
  $invalid = [regex]::Match(
    $output,
    '(?m)^invalid tests:\s*(\d+)\s+passed,\s*(\d+)\s+failed\s*$'
  )

  $validSummary = if ($valid.Success) {
    "$($valid.Groups[1].Value) passed, $($valid.Groups[2].Value) failed"
  } else {
    'missing from output'
  }
  $invalidSummary = if ($invalid.Success) {
    "$($invalid.Groups[1].Value) passed, $($invalid.Groups[2].Value) failed"
  } else {
    'missing from output'
  }
  @"
### Official toml-test v2.2.0 decoder baseline

| Suite | Result |
| --- | --- |
| Valid | $validSummary |
| Invalid | $invalidSummary |
| Runner exit status | $Status |
"@ | Add-Content -LiteralPath $SummaryPath

  if (-not $valid.Success -or -not $invalid.Success) {
    throw 'toml-test infrastructure failure: valid/invalid counts are missing'
  }
  if ($Status -ne 0 -and $Status -ne 1) {
    throw "toml-test infrastructure failure: unexpected exit status $Status"
  }

  $validPassed = [int]$valid.Groups[1].Value
  $validFailed = [int]$valid.Groups[2].Value
  $invalidPassed = [int]$invalid.Groups[1].Value
  $invalidFailed = [int]$invalid.Groups[2].Value
  if ($validPassed + $validFailed -ne 205 -or $invalidPassed + $invalidFailed -ne 474) {
    throw 'toml-test infrastructure failure: unexpected pinned-suite totals'
  }
  $failureCount = $validFailed + $invalidFailed
  if (($failureCount -eq 0 -and $Status -ne 0) -or ($failureCount -gt 0 -and $Status -ne 1)) {
    throw "toml-test infrastructure failure: exit status $Status disagrees with $failureCount failures"
  }
  if ($validPassed -lt 177 -or $invalidPassed -lt 421) {
    throw "toml-test regression: valid=$validPassed (minimum 177), invalid=$invalidPassed (minimum 421)"
  }

  Write-Output "toml-test baseline accepted: valid=$validPassed, invalid=$invalidPassed, status=$Status"
} catch {
  [Console]::Error.WriteLine($_.Exception.Message)
  exit 1
}
