# Task 2 Report: Official `toml-test` Decoder Contract

## Status

COMPLETE. The pure decoder API, pinned async native adapter, Windows/Linux launchers, and Linux CI integration are committed. Project tests and checks pass. The official v2.2.0 conformance command runs successfully as a harness and reports the pre-existing parser baseline gaps separately: 177/205 valid pass and 421/474 invalid pass.

## Commit

- Commit: `e5a18f723669bd72528c7610f32e22eb3fb069ca`
- Message: `test: integrate official TOML decoder contract`
- Branch: `feature/toml-workbench`

## Files changed

- `.github/workflows/ci.yml`
- `cmd/toml-test-decoder/main.mbt`
- `cmd/toml-test-decoder/moon.pkg`
- `decoder.mbt`
- `decoder_test.mbt`
- `moon.mod`
- `pkg.generated.mbti`
- `scripts/toml-test-decoder.cmd`
- `scripts/toml-test-decoder.sh` (mode `100755`)

The generated root interface was committed because the new public API is intentionally visible. No README or application claim was changed.

## Authentic TDD red/green evidence

### Pure decoder RED

The brief's literal command was run first:

```text
> moon test -p yufenfei111/toml-mbt -f decoder_test.mbt
exit 1
Error: [4021]
decoder_test.mbt:4:16: The value identifier decode_tagged_json is unbound.
decoder_test.mbt:24:5: The value identifier decode_tagged_json is unbound.
decoder_test.mbt:42:5: The value identifier decode_tagged_json is unbound.
decoder_test.mbt:51:9: The value identifier decode_tagged_json is unbound.
```

The installed CLI's authentic file-scoped form produced the same expected RED:

```text
> moon test decoder_test.mbt
exit 1
Error: [4021]
decoder_test.mbt:4:16: The value identifier decode_tagged_json is unbound.
decoder_test.mbt:24:5: The value identifier decode_tagged_json is unbound.
decoder_test.mbt:42:5: The value identifier decode_tagged_json is unbound.
decoder_test.mbt:51:9: The value identifier decode_tagged_json is unbound.
```

The first minimal implementation then exposed a real deterministic-order defect: `moon test decoder_test.mbt` reported 3 passed, 1 failed because MoonBit's built-in `String::compare` is shortlex, not ordinary lexicographic order. A code-point lexicographic comparator fixed that production defect.

### Pure decoder GREEN

```text
> moon test decoder_test.mbt
Total tests: 4, passed: 4, failed: 0.

> moon test
Total tests: 294, passed: 294, failed: 0.
```

### Native adapter RED/GREEN

Before `main.mbt` existed, the installed CLI-compatible build command failed for the expected reason:

```text
> moon build --target native cmd/toml-test-decoder
exit 1
Error: [4067]
Missing main function in the main package.
```

After implementing the async stdio entry point:

```text
> moon build --target native cmd/toml-test-decoder
exit 0
Finished. moon: ran 7 tasks, now up to date
```

## Official protocol sources consulted

- Pinned v2.2.0 primary README: <https://raw.githubusercontent.com/toml-lang/toml-test/v2.2.0/README.md>
  - Tables are JSON objects; arrays are JSON arrays.
  - The eight scalar tags are `string`, `integer`, `float`, `bool`, `datetime`, `datetime-local`, `date-local`, and `time-local`.
  - Every tagged scalar `value` is a JSON string.
  - Offset date-times use RFC 3339; local date/time forms omit the corresponding offset/date portion.
  - Decoder stdin/stdout and non-zero invalid-input behavior are normative.
- Pinned v2.2.0 primary module declaration: <https://raw.githubusercontent.com/toml-lang/toml-test/v2.2.0/go.mod>
  - The module path is `github.com/toml-lang/toml-test/v2`.
- Pinned `moonbitlang/async@0.20.1` archive contents and generated interfaces from the MoonBit registry cache:
  - `moonbitlang/async/stdio` exports `stdin`, `stdout`, and `stderr`.
  - `moonbitlang/async/io` provides async `Reader::read_all`, `Data::text`, and `Writer::write`.
- Setup action primary README: <https://raw.githubusercontent.com/hustcer/setup-moonbit/v1/README.md>, which recommends the pinned `hustcer/setup-moonbit@v1.16` release tag used by CI.

## Implementation decisions

- `decode_tagged_json(String) -> Result[String, TomlError]` delegates parsing to the unchanged public `parse` API.
- Scalars are emitted with the official v2 tags. Integers/floats/date-times use the repository's existing normalized formatting helpers, which also preserve existing public serialization behavior.
- Arrays remain plain JSON arrays and tables remain plain JSON objects, as required by v2.2.0 (arrays are not tagged).
- Object keys are recursively sorted using ordinary code-point lexicographic order. A custom comparator is necessary because MoonBit's built-in string comparison is shortlex.
- JSON key/value quoting delegates to `Json::string(...).stringify()`, reusing the repository/core JSON escaping rather than interpolating unescaped data.
- The native executable imports exactly `moonbitlang/async@0.20.1` through `moon.mod`, reads stdin to EOF, emits one JSON line on success, emits the parse error to stderr on failure, and exits non-zero through native `exit`.
- Both launchers resolve the repository root from their own path, lazily create a release native binary, redirect build chatter away from decoder stdout, and then replace/invoke the binary.
- CI uses the Linux `.sh` launcher. Local Windows evidence uses the `.cmd` launcher.
- CI uses the primary-source v2 module path and required `test` subcommand. The brief's literal old path was still executed and its exact failure is recorded below.

## Verification commands and exact results

### Baseline

```text
> moon --version
moon 0.1.20260807 (4da23f8 2026-08-07)
moonc v0.10.7+bc794d341 (2026-08-11)
moonrun 0.1.20260807 (4da23f8 2026-08-07)

> moon test
Total tests: 290, passed: 290, failed: 0.

> moon check --deny-warn
exit 0
Finished. moon: ran 3 tasks, now up to date
```

### Dependency fetch

The sandboxed first attempt was recorded exactly:

```text
> moon add moonbitlang/async@0.20.1
exit 1
Error: update failed
Caused by:
  0: failed to clone registry index
  1: 拒绝访问。 (os error 5)
```

The authorized retry succeeded without changing the required version:

```text
> moon add moonbitlang/async@0.20.1
exit 0
Registry index cloned successfully
Symbols updated successfully
Downloading moonbitlang/async@0.20.1
```

### Installed-CLI command compatibility

The brief's literal native build command is incompatible with this installed Moon CLI:

```text
> moon build --target native -p yufenfei111/toml-mbt/cmd/toml-test-decoder
exit 1
error: unexpected argument '-p' found
Usage: moon.exe build [OPTIONS] [PATH]...
```

The authentic path-scoped equivalent passes:

```text
> moon build --release --target native cmd/toml-test-decoder
exit 0
Finished. moon: no work to do
```

### Windows launcher behavior from an unrelated working directory

```text
> "b = 2\na = 1\n" | scripts\toml-test-decoder.cmd
VALID_STATUS=0
VALID_STDOUT={"a":{"type":"integer","value":"1"},"b":{"type":"integer","value":"2"}}

> "a = { b = 1, }\n" | scripts\toml-test-decoder.cmd
INVALID_STATUS=1
INVALID_STDERR=line 1, column 14: expected a key
```

The first launcher invocation was also tested after `moon clean`; the lazy build completed and its build output stayed off captured decoder stdout.

### Literal and primary-source official commands

The brief's literal Go module path cannot identify v2.2.0:

```text
> go run github.com/BurntSushi/toml-test/cmd/toml-test@v2.2.0 -decoder ./scripts/toml-test-decoder.cmd
exit 1
go: github.com/BurntSushi/toml-test/cmd/toml-test@v2.2.0: invalid version: unknown revision cmd/toml-test/v2.2.0
```

On Windows, the official v2 runner also passes decoder commands through `cmd.exe`, so the brief's POSIX `./scripts/...cmd` spelling is rejected as `'.' is not recognized`. The working Windows command uses a backslash path:

```text
> go run github.com/toml-lang/toml-test/v2/cmd/toml-test@v2.2.0 test -decoder .\scripts\toml-test-decoder.cmd
exit 1 (conformance failures)
toml-test v2.2.0 [.\scripts\toml-test-decoder.cmd] [no encoder]
  valid tests: 177 passed, 28 failed
encoder tests: no encoder command given
invalid tests: 421 passed, 53 failed
```

This used the checksum-verified official portable `go1.26.5.windows-amd64.zip` (`SHA256 97e6b2a833b6d89f9ff17d25419ac0a7e3b482a044e9ab18cdef834bd834fd38`) because the host initially had no `go` executable.

### Final completion gate on the staged tree

```text
> git diff --cached --check
exit 0

> moon info
Finished. moon: ran 2 tasks, now up to date

> moon fmt --check
Finished. moon: no work to do

> moon check --deny-warn
Finished. moon: ran 2 tasks, now up to date

> moon test decoder_test.mbt
Total tests: 4, passed: 4, failed: 0.

> moon test
Total tests: 294, passed: 294, failed: 0.

> moon build --release --target native cmd/toml-test-decoder
Finished. moon: no work to do
```

Project unit counts above are intentionally distinct from official conformance counts.

## Official v2.2.0 failures (every failure)

### Valid: 28 failures

- `valid/array/array-subtables`
- `valid/array/open-parent-table`
- `valid/datetime/datetime`
- `valid/datetime/edge`
- `valid/datetime/leap-year`
- `valid/implicit-and-explicit-after`
- `valid/inline-table/key-dotted-01`
- `valid/key/dotted-02`
- `valid/multibyte`
- `valid/spec-1.0.0/array-of-tables-1`
- `valid/spec-1.0.0/keys-4`
- `valid/spec-1.0.0/offset-date-time-1`
- `valid/spec-1.0.0/string-4`
- `valid/spec-1.0.0/string-7`
- `valid/spec-1.0.0/table-3`
- `valid/spec-1.0.0/table-4`
- `valid/string/multibyte`
- `valid/string/multibyte-escape`
- `valid/string/multiline-quotes`
- `valid/string/quoted-unicode`
- `valid/string/raw-multiline`
- `valid/table/array-implicit-and-explicit-after`
- `valid/table/array-nest`
- `valid/table/array-table-array`
- `valid/table/names`
- `valid/table/names-with-values`
- `valid/table/without-super`
- `valid/table/without-super-with-values`

### Invalid: 53 failures

- `invalid/array/tables-01`
- `invalid/control/bare-cr`
- `invalid/control/comment-cr`
- `invalid/control/comment-del`
- `invalid/control/comment-ff`
- `invalid/control/comment-lf`
- `invalid/control/comment-null`
- `invalid/control/comment-us`
- `invalid/datetime/no-secs`
- `invalid/float/exp-double-us`
- `invalid/float/exp-leading-us`
- `invalid/float/exp-trailing-us`
- `invalid/float/exp-trailing-us-01`
- `invalid/float/exp-trailing-us-02`
- `invalid/float/leading-us`
- `invalid/float/leading-zero`
- `invalid/float/leading-zero-neg`
- `invalid/float/leading-zero-plus`
- `invalid/float/trailing-us`
- `invalid/float/trailing-us-exp-01`
- `invalid/float/trailing-us-exp-02`
- `invalid/float/us-after-dot`
- `invalid/float/us-before-dot`
- `invalid/inline-table/duplicate-key-03`
- `invalid/inline-table/overwrite-02`
- `invalid/inline-table/overwrite-08`
- `invalid/integer/capital-bin`
- `invalid/integer/capital-hex`
- `invalid/integer/capital-oct`
- `invalid/integer/negative-bin`
- `invalid/integer/negative-hex`
- `invalid/integer/negative-oct`
- `invalid/integer/positive-bin`
- `invalid/integer/positive-hex`
- `invalid/integer/positive-oct`
- `invalid/integer/us-after-bin`
- `invalid/integer/us-after-hex`
- `invalid/integer/us-after-oct`
- `invalid/key/multiline-key-01`
- `invalid/key/multiline-key-02`
- `invalid/key/multiline-key-03`
- `invalid/key/multiline-key-04`
- `invalid/key/newline-04`
- `invalid/key/newline-05`
- `invalid/local-date/trailing-t`
- `invalid/local-datetime/no-secs`
- `invalid/spec-1.0.0/inline-table-2-0`
- `invalid/string/basic-multiline-out-of-range-unicode-escape-01`
- `invalid/string/basic-out-of-range-unicode-escape-01`
- `invalid/table/llbrace`
- `invalid/table/multiline-key-01`
- `invalid/table/multiline-key-02`
- `invalid/table/rrbrace`

## Self-review

- Reviewed the full staged diff: 9 files, 220 insertions, 6 deletions; no unrelated source changes or README claims are staged.
- Verified public API impact is limited to the intended `decode_tagged_json` addition in `pkg.generated.mbti`; existing `parse`, `Value`, `to_json`, and serialization APIs remain unchanged.
- Verified every official scalar tag, arrays, nested tables, escaping, recursive ordering, and invalid-input propagation have direct tests against real code.
- Verified the shell launcher is executable in Git (`100755`) and contains LF line endings.
- Verified both lazy launchers keep build chatter off protocol stdout and resolve paths independently of caller CWD.
- Mutation check: removing any scalar branch, JSON escaping, recursive sorting, array/table shape, or parse-error propagation fails at least one focused decoder test.
- The official 81 failures are parser/lexer conformance work outside Task 2's harness scope; they are not counted as project unit-test failures and were not hidden or converted to README claims.

## Concerns

- CI now correctly gates on the official v2.2.0 suite, so it will remain red until later parser-conformance tasks resolve the recorded 28 valid and 53 invalid failures.
- The brief's literal Go path (`BurntSushi/...` without `/v2`) and its Windows `./...cmd` spelling cannot run v2.2.0. CI therefore uses the pinned primary-source module path and Linux `.sh` launcher; local evidence uses the Windows-compatible `.\...cmd` spelling.
- The installed Moon CLI does not support `moon build -p`; the path-scoped equivalent is recorded and used.

## Fix round 1 (completed after harness debugging)

### Root cause and hypothesis test

The Windows launcher regression harness used `$Input` as the parameter and
value written to each temporary TOML file. PowerShell variable names are
case-insensitive, so this collides with the automatic `$input` pipeline
enumerator. The helper consequently redirected an empty file and correctly
received `{}` from the decoder.

The initially failing harness run was:

```text
> scripts/test-toml-test-launchers.ps1
.cmd valid input should emit tagged JSON
Expected: {"a":{"type":"integer","value":"1"}}
Actual:   {}
```

The instrumented comparison used the exact same `cmd.exe` arguments and
working directory as the helper. Its input file was exactly six UTF-8 bytes
`61 20 3d 20 31 0a` (`a = 1\n`), stdin was the closed file-redirection handle,
and it returned exit `0` with stdout bytes
`7b 22 61 22 3a 7b 22 74 79 70 65 22 3a 22 69 6e 74 65 67 65 72 22 2c 22 76 61 6c 75 65 22 3a 22 31 22 7d 7d 0a`.
The only data-flow difference was the test helper's `$Input` value: the
working reproduction wrote the literal bytes, while the helper wrote the
automatic empty pipeline enumerator. Both used `cmd.exe`, the same
`/d /s /c ""<launcher>" < "<file>""` arguments, `UseShellExecute = $false`,
the unrelated working directory, and redirected stdout/stderr; the helper
also trims captured output, which cannot turn tagged JSON into `{}`.

Renaming only the test-data parameters to `$TomlInput` advanced the test past
the formerly failing `.cmd` assertion, confirming the hypothesis. The same
comparison revealed that the `.sh` helper directly starts Git's `sh.exe` from
`cmd.exe` without Git's `usr\\bin` on `PATH`; `dirname` was therefore missing
(exit `127`). Prepending that one directory to the child environment is a
test-only correction and produced the expected tagged JSON.

### Launcher regression fixed

The corrected harness then exposed a real Windows-launcher issue: the `.cmd`
launcher called `moon build` before every invocation. Its existing eight
warm-launch, one-second regression failed with `Actual: 8` timeouts after the
stale-decoder check restored the saved executable. The launcher now runs a
no-stdin health probe first and invokes the mutex-protected build helper only
for a missing or unhealthy executable. The helper repeats that health check
after acquiring the mutex so concurrent stale launches do not rebuild more
than once.

```text
> scripts/test-toml-test-launchers.ps1
launcher regression checks passed

> scripts/test-toml-test-baseline-parser.ps1
baseline parser regression checks passed
```

### Official no-build result

The checksum-verified official `go1.26.5.windows-amd64.zip` was used
(`97e6b2a833b6d89f9ff17d25419ac0a7e3b482a044e9ab18cdef834bd834fd38`).
The controlled v2.2.0 invocation with `TOML_TEST_DECODER_NO_BUILD=1` took
`15919 ms` and returned the expected conformance status `1`:

```text
valid tests: 177 passed, 28 failed
invalid tests: 421 passed, 53 failed
```

### Commit, self-review, and concerns

- Commit: `fix: make toml-test gate reproducible`.
- Self-review: the decoder contract and parser semantics remain untouched;
  changes are confined to launcher test input/environment setup, build
  readiness checks, the CI baseline gate, and its parser tests.
- Concern: the no-stdin health probe treats successful empty-input decoding as
  the executable readiness signal. It deliberately avoids putting build work
  on the official runner's per-case protocol path; the explicit CI no-build
  mode remains the deterministic conformance path.
