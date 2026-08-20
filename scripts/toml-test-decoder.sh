#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
decoder="$repo_root/_build/native/release/build/cmd/toml-test-decoder/toml-test-decoder"

if [ "${TOML_TEST_DECODER_NO_BUILD:-}" = 1 ]; then
  if [ ! -x "$decoder" ]; then
    printf '%s\n' "prebuilt decoder is missing: $decoder" >&2
    exit 1
  fi
else
  if ! build_output=$(cd "$repo_root" && moon build --quiet --release --target native cmd/toml-test-decoder </dev/null 2>&1); then
    printf '%s\n' "$build_output" >&2
    exit 1
  fi
fi

exec "$decoder"
