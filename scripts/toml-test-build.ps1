param(
  [Parameter(Mandatory = $true)]
  [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath($RepoRoot)
$decoder = Join-Path $repoRoot '_build/native/release/build/cmd/toml-test-decoder/toml-test-decoder.exe'
$tempBase = if ($env:TOML_TEST_DECODER_TEMP_ROOT) {
  $env:TOML_TEST_DECODER_TEMP_ROOT
} else {
  [IO.Path]::GetTempPath()
}
$tempDir = $null
$mutex = $null
$acquired = $false

function New-DecoderTempDirectory {
  for ($attempt = 1; $attempt -le 10; $attempt++) {
    $candidate = Join-Path $tempBase ('toml-test-decoder-' + [guid]::NewGuid().ToString('N'))
    try {
      New-Item -ItemType Directory -Path $candidate -ErrorAction Stop | Out-Null
      return $candidate
    } catch {
    }
  }
  throw "could not allocate a decoder temporary directory under $tempBase"
}

function Invoke-DecoderBuild {
  $previousErrorAction = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $buildOutput = & moon build --quiet --release --target native cmd/toml-test-decoder 2>&1 | Out-String
    $buildStatus = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorAction
  }
  if ($buildStatus -ne 0) {
    [Console]::Error.Write("decoder build failed with exit $buildStatus`n$buildOutput")
    exit $buildStatus
  }
}

try {
  $tempDir = New-DecoderTempDirectory
  $inputPath = Join-Path $tempDir 'stdin.toml'
  $inputFile = [IO.File]::Create($inputPath)
  try {
    [Console]::OpenStandardInput().CopyTo($inputFile)
  } finally {
    $inputFile.Dispose()
  }

  if ($env:TOML_TEST_DECODER_NO_BUILD -ne '1') {
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
      $repoBytes = [Text.Encoding]::UTF8.GetBytes($repoRoot.ToUpperInvariant())
      $mutexName = 'Local\MoonBitTomlDecoderBuild_' + (-join ($sha256.ComputeHash($repoBytes) | ForEach-Object { $_.ToString('x2') }))
    } finally {
      $sha256.Dispose()
    }
    $mutex = [Threading.Mutex]::new($false, $mutexName)
    try {
      $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds(30))
    } catch [Threading.AbandonedMutexException] {
      $acquired = $true
    }
    if (-not $acquired) { throw 'timed out waiting for the decoder build lock' }
    Push-Location -LiteralPath $repoRoot
    try {
      Invoke-DecoderBuild
    } finally {
      Pop-Location
    }
  }

  if (-not (Test-Path -LiteralPath $decoder)) { throw "decoder is missing: $decoder" }
  $psi = [Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $decoder
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $psi
  [void]$process.Start()
  try {
    $inputFile = [IO.File]::OpenRead($inputPath)
    try {
      $inputFile.CopyTo($process.StandardInput.BaseStream)
    } finally {
      $inputFile.Dispose()
      $process.StandardInput.Close()
    }
    $process.WaitForExit()
    $exitCode = $process.ExitCode
  } finally {
    $process.Dispose()
  }
  exit $exitCode
} catch {
  [Console]::Error.WriteLine($_.Exception.Message)
  exit 1
} finally {
  if ($acquired) { $mutex.ReleaseMutex() }
  if ($null -ne $mutex) { $mutex.Dispose() }
  if ($null -ne $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}
