# toml-mbt

A [TOML 1.0](https://toml.io) parser and serializer for [MoonBit](https://www.moonbitlang.com/), written in MoonBit.

toml-mbt reads TOML into a typed value tree, reports errors with precise line and
column positions, and serializes the tree back to TOML. It targets the official
[toml-test](https://github.com/toml-lang/toml-test) conformance suite and is
published on [mooncakes.io](https://mooncakes.io).

## Features

- Full TOML 1.0 value model: strings (basic, literal, and both multiline forms),
  integers (decimal, hex, octal, binary, with underscores and signs), floats
  (including `inf` and `nan`), booleans, and all four date-time types.
- Tables, dotted keys, inline tables, arrays, and arrays of tables.
- Errors with 1-based line and column positions.
- Serialization that preserves insertion order and round-trips value structure.
- Tagged JSON output in the `toml-test` format via `to_json`.

## Installation

Add it to your `moon.mod`:

```
moon add yufenfei111/toml-mbt
```

Then import it:

```moonbit
let doc = @toml-mbt.parse("answer = 42\n")
```

## Usage

```moonbit
fn main {
  let toml = """
    title = "Example"
    enabled = true
    count = 7

    [server]
    host = "localhost"
    port = 8080
  """

  match @toml-mbt.parse(toml) {
    Ok(table) => {
      // table is a Map[String, Value]; navigate it directly.
      let server = table.get("server")
      println("parsed ok")
    }
    Err(e) => println(e.to_string())
  }
}
```

See `cmd/main/main.mbt` for a complete runnable example.

## API

- `parse(text : String) -> Result[Table, TomlError]` — parse a TOML document.
- `serialize(table : Table) -> String` — serialize a table back to TOML.
- `to_json(table : Table) -> Json` — convert to the `toml-test` tagged JSON.

The main types:

- `Table` — `Map[String, Value]`, the root of any document.
- `Value` — `String | Integer | Float | Boolean | OffsetDateTime |
  LocalDateTime | LocalDate | LocalTime | Array | Table`.
- `TomlError` — a parse error with `line`, `column`, and a message.

## Development

```sh
moon check   # type check
moon test    # run the test suite
moon build   # build
moon fmt     # format
```

## License

[Apache-2.0](LICENSE)
