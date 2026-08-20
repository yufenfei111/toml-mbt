#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
decoder="$repo_root/_build/native/release/build/cmd/toml-test-decoder/toml-test-decoder"
lock_dir="$repo_root/_build/toml-test-decoder-build.lock"
build_lock=none

if [ "${TOML_TEST_DECODER_NO_BUILD:-}" = 1 ]; then
  if [ ! -x "$decoder" ]; then
    printf '%s\n' "prebuilt decoder is missing: $decoder" >&2
    exit 1
  fi
  exec "$decoder"
fi

if command -v flock >/dev/null 2>&1; then
  mkdir -p "$repo_root/_build"
  exec 9>"$lock_dir"
  if ! flock -w 120 9; then
    printf '%s\n' "timed out waiting for decoder build lock: $lock_dir" >&2
    exit 1
  fi
  build_lock=flock
elif command -v powershell.exe >/dev/null 2>&1; then
  # Git Bash on Windows uses the same kernel mutex as the .cmd launcher.
  decoder="$decoder.exe"
  build_lock=windows
else
  printf '%s\n' 'no supported decoder build lock is available' >&2
  exit 1
fi

if [ "$build_lock" = flock ]; then
  build_output=$(
    cd "$repo_root" &&
      moon build --quiet --release --target native cmd/toml-test-decoder </dev/null 2>&1
  ) && build_status=0 || build_status=$?
else
  build_output=$(
    powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
      -File "$script_dir/toml-test-build.ps1" -RepoRoot "$repo_root" \
      </dev/null 2>&1
  ) && build_status=0 || build_status=$?
fi

if [ "$build_status" -eq 0 ]; then
  :
else
  printf '%s\n' "$build_output" >&2
  exit "$build_status"
fi

if [ "$build_lock" = flock ]; then
  flock -u 9
  exec 9>&-
fi
exec "$decoder"
