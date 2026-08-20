Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$decoder = Join-Path $repoRoot '_build/native/release/build/cmd/toml-test-decoder/toml-test-decoder.exe'
$cmdLauncher = Join-Path $repoRoot 'scripts/toml-test-decoder.cmd'
$shLauncher = Join-Path $repoRoot 'scripts/toml-test-decoder.sh'
$shExe = 'C:/Program Files/Git/usr/bin/sh.exe'
$unrelatedCwd = Join-Path $env:TEMP 'toml-test-launcher-cwd'

function Assert-Equal {
  param(
    [Parameter(Mandatory = $true)]$Actual,
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if ($Actual -cne $Expected) {
    throw "$Message`nExpected: $Expected`nActual:   $Actual"
  }
}

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-CommandProcess {
  param(
    [Parameter(Mandatory = $true)][string]$CommandFormatter,
    [AllowEmptyString()][string]$TomlInput = '',
    [AllowEmptyString()][string]$PathPrefix = '',
    [int]$TimeoutMs = 0
  )

  $tempFile = Join-Path $unrelatedCwd ("stdin-" + [guid]::NewGuid().ToString('N') + '.toml')
  Set-Content -LiteralPath $tempFile -Value $TomlInput -NoNewline
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = 'cmd.exe'
  $psi.Arguments = [string]::Format($CommandFormatter, $tempFile)
  $psi.WorkingDirectory = $unrelatedCwd
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  if ($PathPrefix.Length -gt 0) {
    $psi.Environment['PATH'] = $PathPrefix + [IO.Path]::PathSeparator + $psi.Environment['PATH']
  }

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $psi
  [void]$process.Start()

  if ($TimeoutMs -gt 0) {
    $finished = $process.WaitForExit($TimeoutMs)
    if (-not $finished) {
      try {
        $process.Kill($true)
      } catch {
      }
      return [pscustomobject]@{
        Finished = $false
        ExitCode = $null
        Stdout = ''
        Stderr = ''
      }
    }
  } else {
    $process.WaitForExit()
  }

  try {
    return [pscustomobject]@{
      Finished = $true
      ExitCode = $process.ExitCode
      Stdout = $process.StandardOutput.ReadToEnd().Trim()
      Stderr = $process.StandardError.ReadToEnd().Trim()
    }
  } finally {
    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-CmdLauncher {
  param(
    [AllowEmptyString()][string]$TomlInput = '',
    [int]$TimeoutMs = 0
  )

  Invoke-CommandProcess -CommandFormatter ('/d /s /c ""' + $cmdLauncher + '" < "{0}""') -TomlInput $TomlInput -TimeoutMs $TimeoutMs
}

function Invoke-ShLauncher {
  param(
    [AllowEmptyString()][string]$TomlInput = '',
    [int]$TimeoutMs = 0
  )

  Invoke-CommandProcess -CommandFormatter ('/d /s /c ""' + $shExe + '" "' + $shLauncher + '" < "{0}""') -TomlInput $TomlInput -PathPrefix (Split-Path -Parent $shExe) -TimeoutMs $TimeoutMs
}

New-Item -ItemType Directory -Force -Path $unrelatedCwd | Out-Null

Push-Location $repoRoot
try {
  & moon build --release --target native cmd/toml-test-decoder | Out-Null
} finally {
  Pop-Location
}

$expectedValid = '{"a":{"type":"integer","value":"1"}}'

$cmdValid = Invoke-CmdLauncher -TomlInput "a = 1`n"
Assert-Equal -Actual $cmdValid.ExitCode -Expected 0 -Message '.cmd valid input should succeed'
Assert-Equal -Actual $cmdValid.Stdout -Expected $expectedValid -Message '.cmd valid input should emit tagged JSON'
Assert-Equal -Actual $cmdValid.Stderr -Expected '' -Message '.cmd valid input should keep stderr clean'

$cmdInvalid = Invoke-CmdLauncher -TomlInput "a = { b = 1, }`n"
Assert-Equal -Actual $cmdInvalid.ExitCode -Expected 1 -Message '.cmd invalid input should fail'
Assert-Equal -Actual $cmdInvalid.Stdout -Expected '' -Message '.cmd invalid input should not contaminate stdout'
Assert-True -Condition ($cmdInvalid.Stderr.Length -gt 0) -Message '.cmd invalid input should report an error on stderr'

$shValid = Invoke-ShLauncher -TomlInput "a = 1`n"
Assert-Equal -Actual $shValid.ExitCode -Expected 0 -Message '.sh valid input should succeed'
Assert-Equal -Actual $shValid.Stdout -Expected $expectedValid -Message '.sh valid input should emit tagged JSON'
Assert-Equal -Actual $shValid.Stderr -Expected '' -Message '.sh valid input should keep stderr clean'

$shInvalid = Invoke-ShLauncher -TomlInput "a = { b = 1, }`n"
Assert-Equal -Actual $shInvalid.ExitCode -Expected 1 -Message '.sh invalid input should fail'
Assert-Equal -Actual $shInvalid.Stdout -Expected '' -Message '.sh invalid input should not contaminate stdout'
Assert-True -Condition ($shInvalid.Stderr.Length -gt 0) -Message '.sh invalid input should report an error on stderr'

$backup = "$decoder.test-backup"
Copy-Item -LiteralPath $decoder -Destination $backup -Force
try {
  Copy-Item -LiteralPath 'C:/WINDOWS/system32/where.exe' -Destination $decoder -Force

  $cmdRebuilt = Invoke-CmdLauncher -TomlInput "a = 1`n"
  Assert-Equal -Actual $cmdRebuilt.ExitCode -Expected 0 -Message '.cmd should rebuild instead of executing a stale decoder'
  Assert-Equal -Actual $cmdRebuilt.Stdout -Expected $expectedValid -Message '.cmd stale decoder recovery should still emit tagged JSON'

  Copy-Item -LiteralPath 'C:/WINDOWS/system32/where.exe' -Destination $decoder -Force

  $shRebuilt = Invoke-ShLauncher -TomlInput "a = 1`n"
  Assert-Equal -Actual $shRebuilt.ExitCode -Expected 0 -Message '.sh should rebuild instead of executing a stale decoder'
  Assert-Equal -Actual $shRebuilt.Stdout -Expected $expectedValid -Message '.sh stale decoder recovery should still emit tagged JSON'
} finally {
  if (Test-Path -LiteralPath $backup) {
    Move-Item -LiteralPath $backup -Destination $decoder -Force
  }
}

$parallel = @(1..8 | ForEach-Object { Invoke-CmdLauncher -TomlInput "a = 1`n" -TimeoutMs 1000 })
$timedOut = @($parallel | Where-Object { -not $_.Finished })
Assert-Equal -Actual $timedOut.Count -Expected 0 -Message '.cmd warm launches should finish within the toml-test 1-second timeout without rebuilding'
Assert-Equal -Actual (@($parallel | Where-Object { $_.ExitCode -ne 0 }).Count) -Expected 0 -Message '.cmd warm launches should all succeed'

Write-Output 'launcher regression checks passed'
