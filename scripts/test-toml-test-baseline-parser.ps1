Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$parser = Join-Path $repoRoot 'scripts/check-toml-test-baseline.ps1'
$tempRoot = Join-Path $env:TEMP 'toml-test-baseline-parser-tests'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-ParserCase {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Output,
    [Parameter(Mandatory = $true)][int]$Status
  )

  $caseDir = Join-Path $tempRoot $Name
  New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
  $inputPath = Join-Path $caseDir 'toml-test-output.txt'
  $summaryPath = Join-Path $caseDir 'summary.md'
  Set-Content -LiteralPath $inputPath -Value $Output -NoNewline

  $runOutput = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $parser `
    -InputPath $inputPath `
    -SummaryPath $summaryPath `
    -Status $Status 2>&1

  [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Output = ($runOutput | Out-String).Trim()
    Summary = if (Test-Path -LiteralPath $summaryPath) {
      Get-Content -Raw -LiteralPath $summaryPath
    } else {
      ''
    }
  }
}

$baseline = @'
toml-test v2.2.0 [decoder] [no encoder]
  valid tests: 177 passed, 28 failed
encoder tests: no encoder command given
invalid tests: 421 passed, 53 failed
'@

$improved = @'
toml-test v2.2.0 [decoder] [no encoder]
  valid tests: 180 passed, 25 failed
encoder tests: no encoder command given
invalid tests: 430 passed, 44 failed
'@

$fullPass = @'
toml-test v2.2.0 [decoder] [no encoder]
  valid tests: 205 passed, 0 failed
encoder tests: no encoder command given
invalid tests: 474 passed, 0 failed
'@

$regression = @'
toml-test v2.2.0 [decoder] [no encoder]
  valid tests: 176 passed, 29 failed
encoder tests: no encoder command given
invalid tests: 421 passed, 53 failed
'@

$missingCounts = @'
toml-test v2.2.0 [decoder] [no encoder]
encoder tests: no encoder command given
invalid tests: 421 passed, 53 failed
'@

$baselineResult = Invoke-ParserCase -Name 'baseline' -Output $baseline -Status 1
Assert-True -Condition ($baselineResult.ExitCode -eq 0) -Message 'Baseline parser should accept the pinned 177/421 result'
Assert-True -Condition ($baselineResult.Summary.Contains('177 passed, 28 failed')) -Message 'Baseline summary should report valid counts'
Assert-True -Condition ($baselineResult.Summary.Contains('421 passed, 53 failed')) -Message 'Baseline summary should report invalid counts'

$improvedResult = Invoke-ParserCase -Name 'improved' -Output $improved -Status 1
Assert-True -Condition ($improvedResult.ExitCode -eq 0) -Message 'Baseline parser should accept improved partial results'

$fullPassResult = Invoke-ParserCase -Name 'full-pass' -Output $fullPass -Status 0
Assert-True -Condition ($fullPassResult.ExitCode -eq 0) -Message 'Baseline parser should accept full-pass results'

$regressionResult = Invoke-ParserCase -Name 'regression' -Output $regression -Status 1
Assert-True -Condition ($regressionResult.ExitCode -ne 0) -Message 'Baseline parser should reject regressions'
Assert-True -Condition ($regressionResult.Output.Contains('regression')) -Message 'Regression failure should mention the baseline regression'

$missingResult = Invoke-ParserCase -Name 'missing-counts' -Output $missingCounts -Status 1
Assert-True -Condition ($missingResult.ExitCode -ne 0) -Message 'Baseline parser should reject missing counts'
Assert-True -Condition ($missingResult.Output.Contains('counts are missing')) -Message 'Missing-count failure should mention missing counts'

Write-Output 'baseline parser regression checks passed'
exit 0
