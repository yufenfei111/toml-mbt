Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$parser = Join-Path $repoRoot 'scripts/check-toml-test-baseline.ps1'
$workflow = Join-Path $repoRoot '.github/workflows/ci.yml'
$tempRoot = Join-Path $env:TEMP ('toml-test-baseline-tests-' + [guid]::NewGuid().ToString('N'))

function Assert-Equal($Actual, $Expected, [string]$Message) {
  if ($Actual -cne $Expected) { throw "$Message`nExpected: $Expected`nActual:   $Actual" }
}

function New-RunnerOutput($validPassed, $validFailed, $invalidPassed, $invalidFailed) {
@"
toml-test v2.2.0 [decoder] [no encoder]
  valid tests: $validPassed passed, $validFailed failed
encoder tests: no encoder command given
invalid tests: $invalidPassed passed, $invalidFailed failed
"@
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
  $cases = @(
    @{ Name = 'baseline'; Output = New-RunnerOutput 181 24 421 53; Status = 1; Pass = $true }
    @{ Name = 'improvement'; Output = New-RunnerOutput 185 20 430 44; Status = 1; Pass = $true }
    @{ Name = 'full-pass'; Output = New-RunnerOutput 205 0 474 0; Status = 0; Pass = $true }
    @{ Name = 'valid-regression'; Output = New-RunnerOutput 180 25 421 53; Status = 1; Pass = $false }
    @{ Name = 'invalid-regression'; Output = New-RunnerOutput 181 24 420 54; Status = 1; Pass = $false }
    @{ Name = 'missing'; Output = 'invalid tests: 421 passed, 53 failed'; Status = 1; Pass = $false }
    @{ Name = 'malformed'; Output = 'valid tests: many passed, none failed'; Status = 1; Pass = $false }
  )
  foreach ($case in $cases) {
    $inputPath = Join-Path $tempRoot ($case.Name + '.txt')
    $summaryPath = Join-Path $tempRoot ($case.Name + '.md')
    Set-Content -LiteralPath $inputPath -Value $case.Output -NoNewline
    $savedErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $parser -InputPath $inputPath -SummaryPath $summaryPath -Status $case.Status *> $null
    $parserPassed = $LASTEXITCODE -eq 0
    $ErrorActionPreference = $savedErrorPreference
    Assert-Equal $parserPassed $case.Pass "baseline parser case '$($case.Name)'"
  }

  $workflowText = Get-Content -Raw -LiteralPath $workflow
  Assert-Equal (
    $workflowText.Contains('Enforce official toml-test v2.2.0 baseline (181 valid / 421 invalid)')
  ) $true 'CI step name must publish the current baseline'
  Assert-Equal (
    $workflowText.Contains(
      'test -timeout 10s -parallel 1 -decoder ./scripts/toml-test-decoder.sh'
    )
  ) $true 'CI must use the stable toml-test timeout and parallelism'
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'baseline parser regression checks passed'
