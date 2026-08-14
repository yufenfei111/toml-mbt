# Changelog

All notable changes to this project are documented in this file.

## [0.1.0] - 2026-08-14

Initial release.

### Added

- Lexer for all TOML 1.0 lexical forms, including the four string types and the
  multiline line-ending backslash rule.
- Recursive-descent parser for key-value pairs, dotted keys, tables, inline
  tables, arrays, and arrays of tables.
- Typed data model (`Value`, `Table`, and four date-time types).
- Errors with 1-based line and column positions.
- Serializer with insertion-order preservation and round-trip support.
- `to_json` conversion in the `toml-test` tagged JSON format.
- Unit and whitebox tests covering parsing, serialization, and error handling.
