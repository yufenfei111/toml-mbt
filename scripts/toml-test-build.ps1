param(
  [Parameter(Mandatory = $true)]
  [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
$sha256 = [Security.Cryptography.SHA256]::Create()
try {
  $repoBytes = [Text.Encoding]::UTF8.GetBytes(
    [IO.Path]::GetFullPath($RepoRoot).ToUpperInvariant()
  )
  $hashBytes = $sha256.ComputeHash($repoBytes)
} finally {
  $sha256.Dispose()
}
$hash = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
$mutex = [Threading.Mutex]::new($false, "Local\MoonBitTomlDecoderBuild_$hash")
$acquired = $false

try {
  try {
    $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(2))
  } catch [Threading.AbandonedMutexException] {
    # The OS transfers an abandoned mutex to this process, so no stale artifact
    # survives a killed launcher.
    $acquired = $true
  }

  if (-not $acquired) {
    [Console]::Error.WriteLine(
      "Timed out waiting for the decoder build lock for $RepoRoot"
    )
    exit 1
  }

  $decoder = Join-Path $RepoRoot '_build/native/release/build/cmd/toml-test-decoder/toml-test-decoder.exe'
  if (Test-Path -LiteralPath $decoder) {
    try {
      & $decoder 1>$null 2>$null
      if ($LASTEXITCODE -eq 0) {
        exit 0
      }
    } catch {
    }
  }

  Push-Location -LiteralPath $RepoRoot
  try {
    & moon build --quiet --release --target native cmd/toml-test-decoder
    $buildStatus = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  exit $buildStatus
} catch {
  [Console]::Error.WriteLine($_.Exception.Message)
  exit 1
} finally {
  if ($acquired) {
    $mutex.ReleaseMutex()
  }
  $mutex.Dispose()
}
