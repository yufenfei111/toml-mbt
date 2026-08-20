Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$decoder = Join-Path $repoRoot '_build/native/release/build/cmd/toml-test-decoder/toml-test-decoder.exe'
$cmdLauncher = Join-Path $repoRoot 'scripts/toml-test-decoder.cmd'
$shLauncher = Join-Path $repoRoot 'scripts/toml-test-decoder.sh'
$shExe = 'C:/Program Files/Git/usr/bin/sh.exe'
$tempRoot = Join-Path $env:TEMP ('toml-test-launcher-tests-' + [guid]::NewGuid().ToString('N'))
$expectedValid = '{"a":{"type":"integer","value":"1"}}'

function Assert-Equal($Actual, $Expected, [string]$Message) {
  if ($Actual -cne $Expected) {
    throw "$Message`nExpected: $Expected`nActual:   $Actual"
  }
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Invoke-Launcher([ValidateSet('cmd', 'sh')][string]$Kind, [string]$Toml, [hashtable]$Environment = @{}) {
  $inputPath = Join-Path $tempRoot ([guid]::NewGuid().ToString('N') + '.toml')
  [IO.File]::WriteAllBytes($inputPath, [Text.Encoding]::UTF8.GetBytes($Toml))
  try {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'cmd.exe'
    $command = if ($Kind -eq 'cmd') {
      '""' + $cmdLauncher + '" < "' + $inputPath + '""'
    } else {
      '""' + $shExe + '" "' + $shLauncher + '" < "' + $inputPath + '""'
    }
    $psi.Arguments = '/d /s /c ' + $command
    $psi.WorkingDirectory = $tempRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['TOML_TEST_DECODER_TEMP_ROOT'] = $tempRoot
    if ($Kind -eq 'sh') {
      $psi.Environment['PATH'] = (Split-Path -Parent $shExe) + [IO.Path]::PathSeparator + $psi.Environment['PATH']
    }
    foreach ($name in $Environment.Keys) { $psi.Environment[$name] = $Environment[$name] }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $process.WaitForExit()
    [pscustomobject]@{
      ExitCode = $process.ExitCode
      Stdout = $process.StandardOutput.ReadToEnd().Trim()
      Stderr = $process.StandardError.ReadToEnd().Trim()
    }
  } finally {
    Remove-Item -LiteralPath $inputPath -Force -ErrorAction SilentlyContinue
  }
}

function Assert-CleanTemp {
  Assert-Equal @(Get-ChildItem -LiteralPath $tempRoot -Force).Count 0 'launcher test temporary resources should be cleaned'
}

New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
  Push-Location $repoRoot
  try { & moon build --release --target native cmd/toml-test-decoder | Out-Null } finally { Pop-Location }

  foreach ($kind in 'cmd', 'sh') {
    $valid = Invoke-Launcher $kind "a = 1`n"
    Assert-Equal $valid.ExitCode 0 "$kind valid input should succeed from an unrelated directory"
    Assert-Equal $valid.Stdout $expectedValid "$kind valid input should emit tagged JSON"
    Assert-Equal $valid.Stderr '' "$kind valid input should keep stderr clean"

    $invalid = Invoke-Launcher $kind "a = { b = 1, }`n"
    Assert-Equal $invalid.ExitCode 1 "$kind invalid input should fail"
    Assert-Equal $invalid.Stdout '' "$kind invalid input should keep stdout clean"
    Assert-True ($invalid.Stderr.Length -gt 0) "$kind invalid input should report stderr"
    Assert-CleanTemp
  }

  $source = Join-Path $repoRoot 'cmd/toml-test-decoder/main.mbt'
  $originalSourceTime = (Get-Item -LiteralPath $source).LastWriteTimeUtc
  try {
    $beforeRebuild = (Get-Item -LiteralPath $decoder).LastWriteTimeUtc
    (Get-Item -LiteralPath $source).LastWriteTimeUtc = $beforeRebuild.AddSeconds(2)
    $stale = Invoke-Launcher cmd "a = 1`n"
    Assert-Equal $stale.Stdout $expectedValid '.cmd should execute after a source freshness rebuild'
    Assert-True ((Get-Item -LiteralPath $decoder).LastWriteTimeUtc -gt $beforeRebuild) '.cmd should rebuild a healthy stale decoder'

    $beforeNoBuild = (Get-Item -LiteralPath $decoder).LastWriteTimeUtc
    (Get-Item -LiteralPath $source).LastWriteTimeUtc = $beforeNoBuild.AddSeconds(2)
    $noBuild = Invoke-Launcher cmd "a = 1`n" @{ TOML_TEST_DECODER_NO_BUILD = '1' }
    Assert-Equal $noBuild.Stdout $expectedValid '.cmd no-build mode should execute the existing decoder'
    Assert-Equal (Get-Item -LiteralPath $decoder).LastWriteTimeUtc $beforeNoBuild '.cmd no-build mode should not rebuild'
    Assert-CleanTemp
  } finally {
    (Get-Item -LiteralPath $source).LastWriteTimeUtc = $originalSourceTime
  }
} finally {
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'launcher regression checks passed'
