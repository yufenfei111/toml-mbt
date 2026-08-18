# MoonBit TOML Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `toml-mbt` from a duplicate parser submission into a reproducible CLI workbench that validates TOML 1.0 and safely edits values without rewriting unrelated source text.

**Architecture:** Keep the current root package as a semantic compatibility layer. Add independent `syntax`, `diagnostics`, `edit`, and `workbench` packages, then put all filesystem concerns in thin native executables under `cmd/`. The syntax layer records exact byte offsets; edits are validated, applied from right to left, and reparsed before output or replacement.

**Tech Stack:** MoonBit 0.1.20260807, native backend, `moonbitlang/async@0.20.1`, official `toml-test` v2.2.0, GitHub Actions, Apache-2.0.

**Spec:** `docs/superpowers/specs/2026-08-18-toml-workbench-design.md`

## Global Constraints

- Preserve the existing public `parse`, `serialize`, `to_json`, `Table`, `Value`, and `TomlError` APIs.
- Treat TOML 1.0 as the accepted language. Extensions are rejected unless an explicit future mode is added.
- `set` and `remove` print the proposed document by default. They may modify a file only with explicit `--write`.
- Reject edits when the target is ambiguous or outside the supported MVP subset; never guess.
- Keep project test counts separate from official `toml-test` results in code, CI, README, and application material.
- Make only evidence-backed claims. This plan improves the submission but cannot guarantee organizer approval.
- After every MoonBit task run `moon info && moon fmt` before the final test command.
- Use one real commit per completed task. Do not rewrite or fabricate the repository history.

---

## Planned file map

| Path | Change |
|---|---|
| `parser.mbt`, `lexer.mbt`, `serializer.mbt` | Enforce strict TOML 1.0 and remove current toolchain warnings. |
| `conformance_invalid_test.mbt`, `conformance_extra_test.mbt` | Convert accepted extensions into rejection regressions. |
| `decoder.mbt`, `decoder_test.mbt` | Produce the tagged JSON contract used by `toml-test`. |
| `cmd/toml-test-decoder/` | Native stdin/stdout adapter for the official runner. |
| `scripts/toml-test-decoder.sh`, `scripts/toml-test-decoder.cmd` | Stable decoder launchers for CI/Linux and local Windows use. |
| `syntax/types.mbt`, `syntax/scan.mbt`, `syntax/path.mbt` | Lossless statement boundaries, spans, key paths, and lookup index. |
| `diagnostics/diagnostic.mbt` | Stable human and JSON diagnostics. |
| `edit/text_edit.mbt`, `edit/operations.mbt` | Non-overlapping text patches and format-preserving operations. |
| `workbench/command.mbt`, `workbench/run.mbt` | Pure command parsing and command behavior. |
| `cmd/workbench/main.mbt` | Native filesystem/stdin/stdout entry point and atomic write. |
| `.github/workflows/ci.yml` | Warning-free checks plus pinned official conformance run. |
| `README.md`, `README.mbt.md`, `CHANGELOG.md` | Honest positioning, reproducible demo, limitations, and evidence. |
| `docs/application.md`, `docs/comparison.md` | Resubmission text and dated comparison with the maintained parser. |
| `../申报书.md` | Update the actual application draft after all evidence is fresh. |

### Task 1: Establish a strict, warning-free TOML 1.0 baseline

**Files:**

- Modify: `parser.mbt`
- Modify: `lexer.mbt`
- Modify: `serializer.mbt`
- Modify: `conformance_invalid_test.mbt`
- Modify: `conformance_extra_test.mbt`
- Modify: `datetime_wbtest.mbt`
- Modify: `error_test.mbt`
- Modify: `lexer_wbtest.mbt`
- Modify: `misc_test.mbt`
- Modify: `number_wbtest.mbt`
- Modify: `string_test.mbt`

**Interfaces:**

- Consumes: existing `pub fn parse(text : String) -> Result[Table, TomlError]` and lexer token stream.
- Produces: the same public API with strict TOML 1.0 behavior and a warning-free baseline required by every later task.

- [ ] **Step 1: Add rejection regressions before changing production code**

Move the three extension cases out of `conformance_extra_test.mbt` and add explicit invalid tests:

```moonbit
test "TOML 1.0 rejects Unicode bare keys" {
  must_fail("中文 = 1")
}

test "TOML 1.0 rejects newline in inline table" {
  must_fail("value = { a = 1,\n b = 2 }")
}

test "TOML 1.0 rejects trailing comma in inline table" {
  must_fail("value = { a = 1, }")
}
```

- [ ] **Step 2: Run the focused regressions and confirm they fail**

Run:

```powershell
moon test -p yufenfei111/toml-mbt -f conformance_invalid_test.mbt
```

Expected: the three new cases fail because the current parser accepts them.

- [ ] **Step 3: Restrict bare keys at the parser boundary**

Add a private helper next to `Parser::parse_key`:

```moonbit
fn is_toml10_bare_key_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_' || ch == '-'
}
```

Make bare-key parsing stop and return a located `TomlError` for every other character. Quoted Unicode keys remain valid.

- [ ] **Step 4: Make inline tables single-line and reject a trailing comma**

In `Parser::parse_inline_table`, remove all `skip_newlines()` calls. After consuming a comma, require another key before `}`. Return a located error when `Newline` appears anywhere between `{` and `}`.

- [ ] **Step 5: Remove all current MoonBit warnings without changing behavior**

Apply the toolchain-directed mechanical updates:

- replace deprecated `.substring(start, end)` with slices;
- replace deprecated `try?` with the current result propagation form;
- replace deprecated `result.is_err()` assertions with `result is Err(_)`;
- declare the internal parser as `priv struct Parser`;
- replace deprecated `\xNN` literals with `\u{NN}` equivalents.

- [ ] **Step 6: Format and run the complete baseline gate**

Run:

```powershell
moon info
moon fmt
moon check --deny-warn
moon test
moon build --target native
git diff --check
```

Expected: all commands exit 0 and `moon check --deny-warn` emits no warning.

- [ ] **Step 7: Commit the baseline**

```powershell
git add parser.mbt lexer.mbt serializer.mbt *_test.mbt
git commit -m "fix: enforce strict TOML 1.0 baseline"
```

### Task 2: Add the official `toml-test` decoder contract

**Files:**

- Create: `decoder.mbt`
- Create: `decoder_test.mbt`
- Create: `cmd/toml-test-decoder/moon.pkg`
- Create: `cmd/toml-test-decoder/main.mbt`
- Create: `scripts/toml-test-decoder.sh`
- Create: `scripts/toml-test-decoder.cmd`
- Modify: `moon.mod`
- Create or modify: `.github/workflows/ci.yml`

**Interfaces:**

- Consumes: `parse(String) -> Result[Table, TomlError]`, root `Value` variants, and existing JSON escaping.
- Produces: `decode_tagged_json(String) -> Result[String, TomlError]` and native stdin/stdout decoder launchers used by CI and Task 10 evidence.

- [ ] **Step 1: Add focused tagged-JSON tests**

Create tests for one value of every TOML category and nested structures. The public pure API is:

```moonbit
pub fn decode_tagged_json(source : String) -> Result[String, TomlError]
```

At minimum assert these exact shapes:

```moonbit
test "decoder tags scalar values" {
  let source = "name = \"MoonBit\"\ncount = 2\nenabled = true\n"
  let output = decode_tagged_json(source).unwrap()
  assert_true(output.contains("\"type\":\"string\""))
  assert_true(output.contains("\"value\":\"MoonBit\""))
  assert_true(output.contains("\"type\":\"integer\""))
  assert_true(output.contains("\"type\":\"bool\""))
}

test "decoder rejects invalid TOML" {
  match decode_tagged_json("a = { b = 1, }") {
    Ok(_) => abort("expected decoder error")
    Err(_) => ()
  }
}
```

- [ ] **Step 2: Confirm the decoder tests fail to compile**

```powershell
moon test -p yufenfei111/toml-mbt -f decoder_test.mbt
```

Expected: failure because `decode_tagged_json` does not exist.

- [ ] **Step 3: Implement deterministic tagged JSON**

Map the existing value model to the official tagged representation. Preserve the original normalized textual value required by the protocol for integers, floats, dates, times, and datetimes. Sort object keys before emission so snapshots and CI output are deterministic. Reuse the repository JSON escaping helper rather than interpolating unescaped strings.

- [ ] **Step 4: Add a native stdin/stdout adapter**

Add `moonbitlang/async@0.20.1` to `moon.mod`. Configure `cmd/toml-test-decoder/moon.pkg` as a native executable importing the root package and async stdio. The entry point reads all stdin, writes tagged JSON plus a newline on success, writes the parse error to stderr on failure, and returns a non-zero process status.

- [ ] **Step 5: Add a stable runner script**

`scripts/toml-test-decoder.sh` must build the native decoder if necessary and `exec` the produced binary. `scripts/toml-test-decoder.cmd` provides the same contract on Windows. Both resolve the repository root from the launcher location and must not depend on the caller's working directory.

- [ ] **Step 6: Run the pinned official suite locally**

```powershell
moon info
moon fmt
moon test
moon build --target native -p yufenfei111/toml-mbt/cmd/toml-test-decoder
go run github.com/BurntSushi/toml-test/cmd/toml-test@v2.2.0 -decoder ./scripts/toml-test-decoder.cmd
```

Record the exact valid/invalid totals and every failing test in the task notes. Do not update README claims yet.

- [ ] **Step 7: Pin the same command in CI**

Create a Windows- or Linux-compatible GitHub Actions job that installs the documented MoonBit toolchain, runs `moon check --deny-warn`, `moon test`, builds the native decoder, and invokes exactly `toml-test@v2.2.0`. Pin third-party actions to a release tag or commit.

- [ ] **Step 8: Commit the conformance harness**

```powershell
git add moon.mod decoder.mbt decoder_test.mbt cmd/toml-test-decoder scripts/toml-test-decoder.sh scripts/toml-test-decoder.cmd .github/workflows/ci.yml
git commit -m "test: integrate official TOML decoder contract"
```

### Task 3: Scan lossless statement boundaries and source spans

**Files:**

- Create: `syntax/moon.pkg`
- Create: `syntax/types.mbt`
- Create: `syntax/scan.mbt`
- Create: `syntax/scan_test.mbt`

**Interfaces:**

- Consumes: raw UTF-8 TOML source only; it deliberately does not depend on the semantic parser.
- Produces: `scan(String) -> ScanResult`, `Statement::text(String) -> String`, `SourceSpan`, `StatementKind`, `Statement`, `Document`, and `SyntaxError` for Tasks 4–9.

- [ ] **Step 1: Define tests for byte-exact statement ranges**

Cover LF, CRLF, comments, blank lines, multiline basic/literal strings, arrays spanning lines, inline `#` characters inside strings, table headers, and array-table headers. Each test must assert `source.slice(span.start_offset, span.end_offset)` equals the exact original statement.

```moonbit
test "scanner preserves CRLF and comments" {
  let source = "# lead\r\nname  =  \"Moon\" # keep\r\n\r\n[tool]\r\ncount=2\r\n"
  let result = scan(source)
  inspect!(result.errors.length(), content="0")
  let document = result.document
  inspect!(document.statements.length(), content="5")
  inspect!(document.statements[1].text(source), content="name  =  \"Moon\" # keep\r\n")
}
```

- [ ] **Step 2: Confirm the syntax package tests fail**

```powershell
moon test -p yufenfei111/toml-mbt/syntax
```

Expected: package or symbols do not exist.

- [ ] **Step 3: Add the minimal public model**

```moonbit
pub struct SourceSpan {
  start_offset : Int
  end_offset : Int
  line : Int
  column : Int
} derive(Eq, Show)

pub struct SyntaxError {
  message : String
  span : SourceSpan
} derive(Eq, Show)

pub enum StatementKind {
  Trivia
  KeyValue
  TableHeader
  ArrayTableHeader
  Invalid
} derive(Eq, Show)

pub struct Statement {
  kind : StatementKind
  span : SourceSpan
} derive(Eq, Show)

pub struct Document {
  source : String
  statements : Array[Statement]
}

pub struct ScanResult {
  document : Document
  errors : Array[SyntaxError]
}

pub fn scan(source : String) -> ScanResult
pub fn Statement::text(self : Statement, source : String) -> String
```

- [ ] **Step 4: Implement a single-pass stateful scanner**

Track current offset, line, column, quote mode, triple-quote mode, escape state, bracket depth, brace depth, and comment state. Finish a statement only at a newline outside strings with zero bracket/brace depth. Preserve newline bytes in the preceding statement. For unterminated strings/brackets, append an `Invalid` statement and a `SyntaxError` to `ScanResult.errors` rather than dropping text. This non-throwing result is what lets diagnostics retain exact invalid source.

- [ ] **Step 5: Verify, format, and commit**

```powershell
moon info
moon fmt
moon test -p yufenfei111/toml-mbt/syntax
moon test
moon check --deny-warn
git diff --check
git add syntax
git commit -m "feat: add lossless TOML statement scanner"
```

### Task 4: Build the key-path index and table context

**Files:**

- Modify: `syntax/types.mbt`
- Create: `syntax/path.mbt`
- Create: `syntax/path_test.mbt`
- Modify: `syntax/scan.mbt`

**Interfaces:**

- Consumes: `Document`, `Statement`, `SourceSpan`, and `scan(String) -> ScanResult` from Task 3.
- Produces: `parse_key_path(String) -> Result[Array[String], SyntaxError]`, `Document::find_entries(Array[String]) -> Array[KeyValueEntry]`, `Document::find_entry(Array[String]) -> KeyValueEntry?`, and indexed entries for editing and `get`.

- [ ] **Step 1: Add path and lookup tests**

Test bare, quoted, dotted, and whitespace-padded keys; normal table context; repeated array-table context; escaped quoted key segments; and a missing path. Include this exact preservation case:

```moonbit
test "lookup finds value but preserves original spelling" {
  let source = "[package]\n\"display.name\"  =  \"old\" # keep\n"
  let result = scan(source)
  inspect!(result.errors.length(), content="0")
  let document = result.document
  let entry = document.find_entry(["package", "display.name"]).unwrap()
  inspect!(source.slice(entry.value_span.start_offset, entry.value_span.end_offset), content="\"old\"")
}
```

- [ ] **Step 2: Confirm lookup tests fail**

```powershell
moon test -p yufenfei111/toml-mbt/syntax -f path_test.mbt
```

- [ ] **Step 3: Add entries to the document model**

```moonbit
pub struct KeyValueEntry {
  path : Array[String]
  key_span : SourceSpan
  value_span : SourceSpan
  line_span : SourceSpan
  table_span : SourceSpan?
  editable : Bool
} derive(Show)
```

Add `entries : Array[KeyValueEntry]` to `Document`, plus:

```moonbit
pub fn parse_key_path(text : String) -> Result[Array[String], SyntaxError]
pub fn Document::find_entries(self : Document, path : Array[String]) -> Array[KeyValueEntry]
pub fn Document::find_entry(self : Document, path : Array[String]) -> KeyValueEntry?
```

- [ ] **Step 4: Index table-relative key/value statements**

Track the active normal table and prepend it to relative keys. `find_entries` returns every exact path match; `find_entry` returns a value only when there is exactly one match. Record array-table entries for `get` and diagnostics, but set `editable=false` because repeated table instances make `set/remove` ambiguous in the MVP. Compute `value_span` without including surrounding spaces or a trailing comment.

- [ ] **Step 5: Verify and commit**

```powershell
moon info
moon fmt
moon test -p yufenfei111/toml-mbt/syntax
moon test
moon check --deny-warn
git add syntax
git commit -m "feat: index TOML key paths and source ranges"
```

### Task 5: Add stable structured diagnostics

**Files:**

- Create: `diagnostics/moon.pkg`
- Create: `diagnostics/diagnostic.mbt`
- Create: `diagnostics/diagnostic_test.mbt`

**Interfaces:**

- Consumes: `@syntax.SourceSpan` and source text; semantic errors arrive as normalized strings and spans.
- Produces: `Diagnostic`, `SuggestedEdit`, `sort_diagnostics`, `render_text`, and `render_json` for the pure Workbench command layer.

- [ ] **Step 1: Write exact rendering and ordering tests**

Use stable codes:

- `TOML100`: semantic TOML parse failure;
- `WB100`: lossless scan/path failure;
- `WB201`: path is readable but not safely editable.

Assert human output includes `file:line:column`, code, message, and a one-line source excerpt. Assert JSON output parses and contains numeric start/end offsets. Assert diagnostics sort by `(start_offset, end_offset, code)`.

- [ ] **Step 2: Confirm package tests fail**

```powershell
moon test -p yufenfei111/toml-mbt/diagnostics
```

- [ ] **Step 3: Implement the package without creating an edit-package cycle**

```moonbit
pub enum Severity { Error; Warning } derive(Eq, Show)

pub struct SuggestedEdit {
  span : @syntax.SourceSpan
  replacement : String
} derive(Eq, Show)

pub struct Diagnostic {
  severity : Severity
  code : String
  message : String
  span : @syntax.SourceSpan
  suggestion : SuggestedEdit?
} derive(Eq, Show)

pub fn sort_diagnostics(items : Array[Diagnostic]) -> Array[Diagnostic]
pub fn render_text(file : String, source : String, item : Diagnostic) -> String
pub fn render_json(items : Array[Diagnostic]) -> String
```

Escape JSON with the root package helper or a dedicated tested equivalent. `SuggestedEdit` intentionally has the same span/replacement data as Task 6's `TextEdit` without importing the `edit` package; the Workbench layer performs the explicit conversion and avoids a package cycle.

- [ ] **Step 4: Verify and commit**

```powershell
moon info
moon fmt
moon test -p yufenfei111/toml-mbt/diagnostics
moon test
moon check --deny-warn
git add diagnostics
git commit -m "feat: add structured workbench diagnostics"
```

### Task 6: Implement the non-overlapping text-edit core

**Files:**

- Create: `edit/moon.pkg`
- Create: `edit/text_edit.mbt`
- Create: `edit/text_edit_test.mbt`

**Interfaces:**

- Consumes: source text plus caller-supplied numeric ranges.
- Produces: `TextEdit`, `EditError`, `validate_edits(String, Array[TextEdit])`, and `apply_edits(String, Array[TextEdit])` for Task 7.

- [ ] **Step 1: Add tests for safe edit application**

Cover an empty edit list, one replacement, two non-overlapping replacements, insertion, deletion, an out-of-range span, a reversed span, overlap, and two insertions at the same offset. Assert the source remains untouched when validation fails.

```moonbit
test "applies edits from right to left" {
  let source = "alpha beta gamma"
  let edits = [
    TextEdit::{ start_offset: 0, end_offset: 5, replacement: "A" },
    TextEdit::{ start_offset: 11, end_offset: 16, replacement: "G" },
  ]
  inspect!(apply_edits(source, edits), content="Ok(\"A beta G\")")
}

test "rejects overlap before applying anything" {
  let edits = [
    TextEdit::{ start_offset: 0, end_offset: 4, replacement: "x" },
    TextEdit::{ start_offset: 3, end_offset: 6, replacement: "y" },
  ]
  match apply_edits("abcdef", edits) {
    Ok(_) => abort("expected overlap error")
    Err(_) => ()
  }
}
```

- [ ] **Step 2: Confirm the edit package tests fail**

```powershell
moon test -p yufenfei111/toml-mbt/edit -f text_edit_test.mbt
```

- [ ] **Step 3: Implement validation and reverse application**

```moonbit
pub struct TextEdit {
  start_offset : Int
  end_offset : Int
  replacement : String
} derive(Eq, Show)

pub enum EditError {
  InvalidRange(Int, Int)
  OutOfBounds(Int, Int)
  Overlap(TextEdit, TextEdit)
} derive(Eq, Show)

pub fn validate_edits(source : String, edits : Array[TextEdit]) -> Result[Array[TextEdit], EditError]
pub fn apply_edits(source : String, edits : Array[TextEdit]) -> Result[String, EditError]
```

Sort a copied array by descending `start_offset`. Reject overlapping ranges and duplicate insertion offsets before producing output. Construct a new string; never mutate a partially completed user-visible result.

- [ ] **Step 4: Verify and commit**

```powershell
moon info
moon fmt
moon test -p yufenfei111/toml-mbt/edit
moon test
moon check --deny-warn
git add edit
git commit -m "feat: add safe TOML text edit engine"
```

### Task 7: Add format-preserving `set` and `remove`

**Files:**

- Create: `edit/operations.mbt`
- Create: `edit/operations_test.mbt`
- Modify: `edit/moon.pkg`
- Modify: `syntax/types.mbt`
- Modify: `syntax/scan.mbt`

**Interfaces:**

- Consumes: `@syntax.scan`, `@syntax.Document::find_entries`, `@toml.parse`, and `apply_edits` from Tasks 1, 4, and 6.
- Produces: `set_value(String, Array[String], String) -> Result[String, OperationError]` and `remove_key(String, Array[String]) -> Result[String, OperationError]` for Task 8.

- [ ] **Step 1: Add golden full-document tests**

Every test compares the complete output, not just the parsed value. Cover:

- replace a top-level key while retaining spaces and an inline comment;
- replace a quoted dotted key;
- replace a key inside a normal table;
- insert a missing root key;
- insert a missing key at the end of an existing normal table;
- remove a key with LF and CRLF;
- reject invalid encoded values;
- reject edits under an array table;
- reject duplicate/ambiguous paths;
- prove an operation error returns no changed document.

```moonbit
test "set changes only the value bytes" {
  let source = "title  =  \"old\"  # retain me\r\ncount=2\r\n"
  let output = set_value(source, ["title"], "\"new\"").unwrap()
  inspect!(output, content="title  =  \"new\"  # retain me\r\ncount=2\r\n")
}

test "remove deletes the target line only" {
  let source = "# configuration\na = 1 # same line\nb = 2\n"
  let output = remove_key(source, ["a"]).unwrap()
  inspect!(output, content="# configuration\nb = 2\n")
}
```

- [ ] **Step 2: Confirm the operation tests fail**

```powershell
moon test -p yufenfei111/toml-mbt/edit -f operations_test.mbt
```

- [ ] **Step 3: Validate a replacement as exactly one TOML value**

Implement:

```moonbit
fn validate_encoded_value(encoded : String) -> Result[Unit, OperationError] {
  let synthetic = "__workbench_value__ = " + encoded + "\n"
  match @toml.parse(synthetic) {
    Ok(_) => Ok(())
    Err(error) => Err(InvalidValue(error.to_string()))
  }
}
```

Also reject encoded text containing a statement-ending newline outside a multiline TOML string. This prevents a valid prefix followed by injected keys.

- [ ] **Step 4: Replace and remove existing entries**

Call `@syntax.scan(source)` first and refuse all edits when `ScanResult.errors` is non-empty. `set_value` replaces only `value_span`. `remove_key` deletes `line_span`, including the line terminator and an inline comment, but never a preceding standalone comment. Refuse the operation when lookup returns multiple entries or `editable=false`.

- [ ] **Step 5: Insert only where the placement is deterministic**

For a missing root key, append `key.path = value` before the first table header, preserving the document's existing LF/CRLF style. For a missing key under one normal table, insert before the next table header or at EOF. Reparse the entire candidate output with the root parser. Return `UnsupportedInsertion` for array tables, implicit/ambiguous parents, or a parent that does not exist.

- [ ] **Step 6: Add the public operations**

```moonbit
pub enum OperationError {
  InvalidPath(String)
  InvalidValue(String)
  NotFound(Array[String])
  AmbiguousPath(Array[String])
  UnsupportedInsertion(Array[String])
  ResultIsInvalid(String)
  TextEdit(EditError)
} derive(Show)

pub fn set_value(source : String, path : Array[String], encoded : String) -> Result[String, OperationError]
pub fn remove_key(source : String, path : Array[String]) -> Result[String, OperationError]
```

- [ ] **Step 7: Run exact-output and regression gates**

```powershell
moon info
moon fmt
moon test -p yufenfei111/toml-mbt/edit
moon test
moon check --deny-warn
git diff --check
```

- [ ] **Step 8: Commit the operations**

```powershell
git add syntax edit
git commit -m "feat: preserve formatting when editing TOML values"
```

### Task 8: Add a pure Workbench command layer

**Files:**

- Create: `workbench/moon.pkg`
- Create: `workbench/command.mbt`
- Create: `workbench/command_test.mbt`
- Create: `workbench/run.mbt`
- Create: `workbench/run_test.mbt`

**Interfaces:**

- Consumes: root semantic parser, syntax lookup, diagnostics renderers, and edit operations from Tasks 1–7.
- Produces: `parse_args(Array[String]) -> Result[Command, CommandError]` and pure `run(Command, String) -> RunResult` for the native I/O adapter.

- [ ] **Step 1: Add strict argument parsing tests**

Test all valid forms and reject missing arguments, unknown commands, extra arguments, duplicated `--json`/`--write`, and flags on commands that do not support them.

```moonbit
pub enum Command {
  Check(file~ : String, json~ : Bool)
  Get(file~ : String, path~ : Array[String])
  Set(file~ : String, path~ : Array[String], encoded~ : String, write~ : Bool)
  Remove(file~ : String, path~ : Array[String], write~ : Bool)
} derive(Eq, Show)

pub enum CommandError {
  UnknownCommand(String)
  MissingArgument(String)
  UnexpectedArgument(String)
  DuplicateFlag(String)
  InvalidPath(String)
} derive(Eq, Show)

pub fn parse_args(args : Array[String]) -> Result[Command, CommandError]
```

- [ ] **Step 2: Confirm command parsing tests fail**

```powershell
moon test -p yufenfei111/toml-mbt/workbench -f command_test.mbt
```

- [ ] **Step 3: Implement the smallest strict parser and usage text**

Recognize only:

```text
toml-workbench check <file> [--json]
toml-workbench get <file> <key.path>
toml-workbench set <file> <key.path> <toml-value> [--write]
toml-workbench remove <file> <key.path> [--write]
```

Parse `<key.path>` with `@syntax.parse_key_path`; do not split naively on every dot because quoted segments may contain dots.

- [ ] **Step 4: Add pure behavior tests**

Use a `RunResult` so logic is testable without filesystem or process APIs:

```moonbit
pub struct RunResult {
  stdout : String
  stderr : String
  exit_code : Int
  proposed_source : String?
} derive(Eq, Show)

pub fn run(command : Command, source : String) -> RunResult
```

Verify:

- `check` returns 0 with no error for valid TOML;
- invalid TOML returns non-zero and a `TOML100` diagnostic;
- `check --json` emits valid structured JSON;
- `get` prints the selected value in JSON-compatible form;
- `set/remove` return the complete proposed TOML in stdout;
- failed operations return non-zero with no `proposed_source`.

- [ ] **Step 5: Implement behavior by composing existing packages**

Do not duplicate parsing, lookup, diagnostic rendering, or edit logic. `run` receives source text; it never opens or writes files. `write=true` is carried in the command but acted on only by the native adapter.

- [ ] **Step 6: Verify and commit**

```powershell
moon info
moon fmt
moon test -p yufenfei111/toml-mbt/workbench
moon test
moon check --deny-warn
git add workbench
git commit -m "feat: add pure TOML Workbench commands"
```

### Task 9: Add native CLI I/O and atomic `--write`

**Files:**

- Create: `cmd/workbench/moon.pkg`
- Create: `cmd/workbench/main.mbt`
- Create: `cmd/workbench/io_test.mbt`
- Modify: `moon.mod`

**Interfaces:**

- Consumes: `@workbench.parse_args`, `@workbench.run`, async filesystem functions, and async stdio functions.
- Produces: the `toml-workbench` native executable with process exit codes and atomic `--write`; no later package imports this executable.

- [ ] **Step 1: Add filesystem integration tests around a temporary directory**

Expose the I/O seam from the command package so tests can call it with explicit paths. Test reading a file, stdout-only default editing, successful `--write`, and failure preserving original bytes. Use unique files under the test runner's temporary directory; do not touch repository fixtures.

- [ ] **Step 2: Confirm the native CLI package is missing**

```powershell
moon test --target native -p yufenfei111/toml-mbt/cmd/workbench
```

- [ ] **Step 3: Implement native read/output behavior**

Use `moonbitlang/async@0.20.1` official APIs: `@fs.read_file`, `@stdio.stdout`, and `@stdio.stderr`. Read UTF-8 bytes once, invoke `@workbench.run`, print the exact returned streams, and map `exit_code` to the process status.

- [ ] **Step 4: Implement atomic replacement for `--write`**

Only when `write=true`, `exit_code=0`, and `proposed_source` exists:

1. create a unique temporary file in the target file's directory;
2. write the complete candidate bytes;
3. read them back and parse them again;
4. rename the temporary file over the target using `@fs.rename`;
5. on any pre-rename failure, remove only that exact temporary file and leave the target unchanged.

The temporary filename is based on the target basename plus process/time entropy. Resolve and compare parent directories before rename; never accept a temporary path outside the target directory.

- [ ] **Step 5: Run an end-to-end manual smoke test**

```powershell
$workbenchDemo = Join-Path $env:TEMP 'toml-workbench-demo.toml'
Set-Content -LiteralPath $workbenchDemo -Value "title  =  `"old`" # keep" -NoNewline
moon run --target native cmd/workbench -- set $workbenchDemo title '"new"'
Get-Content -LiteralPath $workbenchDemo -Raw
moon run --target native cmd/workbench -- set $workbenchDemo title '"new"' --write
Get-Content -LiteralPath $workbenchDemo -Raw
Remove-Item -LiteralPath $workbenchDemo
```

Expected: the first command prints the candidate but the first file read still contains `old`; after `--write`, it contains `new` and retains spacing/comment text.

- [ ] **Step 6: Run the native and repository gates**

```powershell
moon info
moon fmt
moon test --target native -p yufenfei111/toml-mbt/cmd/workbench
moon test
moon check --deny-warn
moon build --target native
git diff --check
```

- [ ] **Step 7: Commit the executable**

```powershell
git add moon.mod cmd/workbench
git commit -m "feat: add native TOML Workbench CLI"
```

### Task 10: Rewrite project positioning and application from fresh evidence

**Files:**

- Modify: `README.md`
- Modify: `README.mbt.md`
- Modify: `CHANGELOG.md`
- Create: `docs/comparison.md`
- Create: `docs/application.md`
- Modify: `../申报书.md`

**Interfaces:**

- Consumes: verified commands/results from Tasks 1–9 and dated primary-source information about the maintained parser.
- Produces: reviewer-facing README, comparison, application text, changelog, and reproducible demo used by Task 11.

- [ ] **Step 1: Capture fresh evidence before writing claims**

Run and save the exact outputs in implementation notes:

```powershell
moon --version
moonc --version
moon check --deny-warn
moon test
moon build --target native
go run github.com/BurntSushi/toml-test/cmd/toml-test@v2.2.0 -decoder ./scripts/toml-test-decoder.cmd
git log --oneline --decorate -15
```

Also revisit the maintained `moonbit-community/toml-parser` repository on the implementation date. Record the inspected commit/release and cite direct links for every comparison claim. If its capabilities have changed, update the comparison rather than preserving the August 18 assumption.

- [ ] **Step 2: Rewrite the README opening and relationship disclosure**

The first screen must state:

```markdown
# MoonBit TOML Workbench

A format-preserving TOML inspection and editing toolchain for MoonBit.

This project began as an independent TOML parser prototype. MoonBit already has the
actively maintained `moonbit-community/toml-parser`; the parser in this repository is
retained as a compatibility and experimentation layer, not presented as a replacement.
The hackathon contribution is the lossless syntax model, structured diagnostics,
minimal text patches, and the `check/get/set/remove` workflow.
```

Then add, in this order: three-minute demo, current capability table, architecture, reproducible verification, exact official result, limitations, roadmap, relationship/upstream links, license.

- [ ] **Step 3: Add a dated, evidence-linked comparison**

`docs/comparison.md` must compare value parsing, serialization, source preservation, text patches, structured diagnostics, and CLI workflows. Use neutral phrases such as “not documented as a core capability in the inspected upstream README,” never claim a feature is absent without examining source or official docs.

- [ ] **Step 4: Write the replacement application text**

`docs/application.md` and `../申报书.md` must include:

1. rejection context and what changed;
2. related maintained project and explicit non-replacement statement;
3. user problem and concrete workflow;
4. completed features, each linked to code/tests;
5. reproducible test commands and exact results;
6. technical novelty: lossless spans, diagnostics, validated minimal patches, atomic writes;
7. known limitations and safe rejection behavior;
8. competition-period roadmap clearly marked as future work;
9. demo steps that a reviewer can complete in under three minutes.

Delete unsupported wording including “生态首个”, “完全兼容”, “完整合规”, “生产可用”, and any implication that 289 project tests are official conformance cases.

- [ ] **Step 5: Update generated package docs and changelog**

Regenerate `README.mbt.md`/package interface documentation using the repository's MoonBit workflow. Add an Unreleased changelog entry separating breaking fixes, new Workbench packages, CLI, and test infrastructure.

- [ ] **Step 6: Verify every numeric and capability claim**

Search all submission-facing text:

```powershell
rg -n "289|100%|complete|完整|首个|生产|toml-test|moonbit-community" README.md README.mbt.md CHANGELOG.md docs ../申报书.md
```

For every match, either attach evidence, qualify it, or remove it. Check all commands from a clean shell and confirm all relative links resolve.

- [ ] **Step 7: Commit the truthful submission material**

```powershell
git add README.md README.mbt.md CHANGELOG.md docs/comparison.md docs/application.md
git commit -m "docs: reposition project as TOML Workbench"
```

`../申报书.md` is outside this repository and must remain a clearly reported parent-workspace change. Do not try to stage it from this repository or copy it into Git merely to hide that boundary.

### Task 11: Build the final reviewer evidence bundle

**Files:**

- Create: `docs/resubmission-checklist.md`
- Modify as evidence requires: `.github/workflows/ci.yml`
- Modify as evidence requires: `README.md`

**Interfaces:**

- Consumes: every implementation, test, CLI, CI, and documentation deliverable from Tasks 1–10.
- Produces: the final reproducible reviewer path and resubmission checklist; this is the terminal deliverable.

- [ ] **Step 1: Run the full clean verification gate**

```powershell
git status --short
moon info
moon fmt
git diff --exit-code
moon check --deny-warn
moon test
moon build --target native
go run github.com/BurntSushi/toml-test/cmd/toml-test@v2.2.0 -decoder ./scripts/toml-test-decoder.cmd
```

Expected: formatting leaves no diff, MoonBit commands pass, and the official suite result exactly matches the documented number. If official cases still fail, the checklist must name them and README must not imply full compliance.

- [ ] **Step 2: Rehearse the reviewer path from repository instructions only**

In a fresh temporary directory, copy one commented TOML example and run:

```powershell
moon run --target native cmd/workbench -- check demo.toml
moon run --target native cmd/workbench -- get demo.toml package.name
moon run --target native cmd/workbench -- set demo.toml package.name '"changed"'
moon run --target native cmd/workbench -- set demo.toml package.name '"changed"' --write
moon run --target native cmd/workbench -- remove demo.toml package.obsolete
```

Verify stdout, exit status, the no-write default, comment/spacing preservation, and final parse success. Fix documentation or code if any README command differs.

- [ ] **Step 3: Create the resubmission checklist**

Include checkboxes for repository title/description, application URL, maintained-project disclosure, current-vs-roadmap labeling, demo commands, CI link, exact test result, limitations, license, contact channel, and the 2026-08-24 resubmission deadline. Add a short reviewer note:

```markdown
The original submission overlapped with an existing TOML parser. The revised project
explicitly acknowledges that work and narrows its contribution to format-preserving
analysis and safe source editing. The parser is now compatibility infrastructure,
while the lossless syntax, diagnostics, patch engine, and Workbench CLI are the
reviewable hackathon deliverables.
```

- [ ] **Step 4: Inspect repository state and commit final evidence**

```powershell
git diff --check
git status --short
git log --oneline --decorate -12
git add docs/resubmission-checklist.md README.md .github/workflows/ci.yml
git commit -m "docs: add hackathon resubmission evidence"
git status --short
```

Expected: repository worktree is clean. The sibling `../申报书.md` may remain modified because it belongs to the parent workspace; report it explicitly.

## Final acceptance checklist

- [ ] Existing public parser/serializer APIs still compile and pass their regressions.
- [ ] Strict TOML 1.0 rejects Unicode bare keys, multiline inline tables, and inline-table trailing commas.
- [ ] `moon check --deny-warn`, `moon test`, and native build all exit 0.
- [ ] A pinned official `toml-test` run is reproducible and documented exactly.
- [ ] Lossless spans preserve LF/CRLF, comments, whitespace, key spelling, and raw values.
- [ ] `set` modifies only a validated value range; `remove` deletes only the selected line.
- [ ] Unsupported and ambiguous paths fail without changing the source file.
- [ ] CLI defaults to stdout and uses atomic replacement only with `--write`.
- [ ] README and application prominently acknowledge `moonbit-community/toml-parser`.
- [ ] Completed features and competition-period plans are visibly separated.
- [ ] The three-minute reviewer demo has been executed exactly as documented.
- [ ] No claim promises acceptance; the material demonstrates concrete differentiation and evidence.
