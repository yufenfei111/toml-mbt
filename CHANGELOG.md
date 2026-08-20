# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Changed — compatibility corrections

- Tightened the retained parser layer to TOML 1.0: Unicode bare keys, multiline inline tables, and trailing commas in inline tables are now rejected. Existing callers that relied on those extensions must quote keys or rewrite the input.
- Preserved the public `parse`, `serialize`, `to_json`, `Table`, `Value`, and `TomlError` APIs while removing current MoonBit warnings.
- Corrected UTF-16/UTF-8 boundary handling for supplementary Unicode scalars.

### Added — Workbench

- Added a lossless `syntax` package with byte-exact statements, UTF-8 source spans, parsed key paths, entry lookup, and table-block metadata.
- Added stable human and JSON diagnostics with control-character-safe rendering.
- Added validated text edits plus format-preserving `set_value` and `remove_key` operations that reparse every candidate.
- Added the pure `workbench` command layer for `check`, `get`, `set`, and `remove`.
- Added a native CLI. Edits are preview-only by default; explicit `--write` uses a same-directory temporary file, byte readback, TOML reparse, and replacement.

### Added — verification infrastructure

- Added the official `toml-test` v2.2.0 tagged-JSON decoder, Windows/Linux launchers, and a CI non-regression gate.
- Fresh 2026-08-20 evidence: project tests **420/420**, native CLI tests **11/11**, official valid tests **181/205**, official invalid tests **421/474**. Project and official counts are intentionally separate.

### Known limitations

- The semantic compatibility layer does not yet pass all TOML 1.0 official cases; the official runner exits non-zero while gaps remain.
- Format-preserving edits reject ambiguous or unsupported locations instead of guessing.
- Atomic replacement does not preserve exact mode, owner, extended attributes, or Windows ACL; see [README](README.md#已知限制与安全边界).

## [0.1.0] - 2026-08-14

Initial parser prototype release.

### Added

- Lexer, recursive-descent parser, typed value model, serializer, errors with 1-based positions, tagged JSON conversion, and repository unit/whitebox tests.
