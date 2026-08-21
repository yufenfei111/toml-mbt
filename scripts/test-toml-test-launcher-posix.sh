#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/toml-test-launcher-posix.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

launcher="$test_root/repo/scripts/toml-test-decoder.sh"
decoder_dir="$test_root/repo/_build/native/release/build/cmd/toml-test-decoder"
decoder="$decoder_dir/toml-test-decoder.exe"
mkdir -p "$(dirname -- "$launcher")" "$decoder_dir"
cp "$script_dir/toml-test-decoder.sh" "$launcher"
printf '%s\n' '#!/usr/bin/env sh' 'cat' >"$decoder"
chmod +x "$launcher" "$decoder"

actual=$(printf '%s\n' 'a = 1' | TOML_TEST_DECODER_NO_BUILD=1 "$launcher")
if [ "$actual" != 'a = 1' ]; then
  printf '%s\n' "POSIX launcher did not execute the .exe decoder: $actual" >&2
  exit 1
fi

printf '%s\n' 'POSIX launcher .exe regression check passed'
