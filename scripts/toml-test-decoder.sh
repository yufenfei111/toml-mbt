#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
decoder="$repo_root/_build/native/release/build/cmd/toml-test-decoder/toml-test-decoder"

if [ ! -x "$decoder" ]; then
  (cd "$repo_root" && moon build --release --target native cmd/toml-test-decoder >&2)
fi

exec "$decoder"
