///|
/// Round-trip tests: parse -> serialize -> parse should preserve structure.

///|
fn roundtrip(text : String) -> Unit {
  let t = @toml-mbt.parse(text).unwrap()
  let out = @toml-mbt.serialize(t)
  let t2 = @toml-mbt.parse(out).unwrap()
  if t2 != t {
    abort("round-trip mismatch for: \{text}")
  }
}

///|
test "roundtrip: integers" {
  roundtrip("a = 0\nb = 42\nc = -17\nd = 9223372036854775807\n")
}

///|
test "roundtrip: all integer bases" {
  roundtrip("a = 0xDEADBEEF\nb = 0o755\nc = 0b1010\n")
}

///|
test "roundtrip: floats" {
  roundtrip("a = 0.0\nb = 3.14\nc = -0.01\nd = 5e+22\ne = 1e06\n")
}

///|
test "roundtrip: special floats" {
  roundtrip("a = inf\nb = -inf\nc = nan\n")
}

///|
test "roundtrip: booleans" {
  roundtrip("a = true\nb = false\n")
}

///|
test "roundtrip: strings" {
  roundtrip("a = \"hello\"\nb = 'literal'\nc = \"\"\n")
}

///|
test "roundtrip: string with escapes" {
  roundtrip("a = \"tab\\there\\nnewline\"\n")
}

///|
test "roundtrip: dates and times" {
  roundtrip(
    "od = 1979-05-27T07:32:00Z\nld = 1979-05-27T07:32:00\n" +
    "d = 1979-05-27\nt = 07:32:00\n",
  )
}

///|
test "roundtrip: offset datetime with timezone" {
  roundtrip("d = 1979-05-27T00:32:00-07:00\n")
}

///|
test "roundtrip: arrays" {
  roundtrip("a = []\nb = [1, 2, 3]\nc = [1, \"two\", 3.0]\n")
}

///|
test "roundtrip: nested arrays" {
  roundtrip("a = [[1, 2], [3, 4], [5, 6]]\n")
}

///|
test "roundtrip: inline tables" {
  roundtrip("a = {}\nb = { x = 1, y = 2 }\n")
}

///|
test "roundtrip: nested inline tables" {
  roundtrip("a = { b = { c = { d = 1 } } }\n")
}

///|
test "roundtrip: tables" {
  roundtrip("[a]\nx = 1\n[a.b]\ny = 2\n")
}

///|
test "roundtrip: dotted keys" {
  roundtrip("a.b.c = 1\nd.e = 2\n")
}

///|
test "roundtrip: array of tables" {
  roundtrip("[[p]]\nn = 1\n[[p]]\nn = 2\n[[p]]\nn = 3\n")
}

///|
test "roundtrip: quoted keys" {
  roundtrip("\"a b\" = 1\n'c.d' = 2\n")
}

///|
test "roundtrip: mixed document" {
  roundtrip(
    "title = \"demo\"\n" +
    "count = 10\n" +
    "ratio = 0.5\n" +
    "enabled = true\n" +
    "[server]\n" +
    "host = \"localhost\"\n" +
    "ports = [80, 443]\n" +
    "[server.ssl]\n" +
    "cert = \"/path/to/cert\"\n" +
    "[[users]]\n" +
    "name = \"alice\"\n" +
    "[[users]]\n" +
    "name = \"bob\"\n",
  )
}

///|
test "roundtrip: unicode content" {
  roundtrip("name = \"héllo 世界\"\nkey = \"值\"\n")
}

///|
test "roundtrip: deeply nested" {
  roundtrip("[a]\n[a.b]\n[a.b.c]\n[a.b.c.d]\nvalue = 42\n")
}

///|
test "roundtrip: underscores in numbers" {
  roundtrip("a = 1_000_000\nb = 1_000.5\n")
}

///|
test "roundtrip: keys with dashes and digits" {
  roundtrip("key-with-dash = 1\nkey_123 = 2\n123 = 3\n")
}

///|
test "roundtrip: fractional seconds" {
  roundtrip("t = 00:00:00.123456789\n")
}

///|
test "roundtrip: array of inline tables" {
  roundtrip("points = [ { x = 1, y = 2 }, { x = 3, y = 4 } ]\n")
}

///|
test "roundtrip: comments are not preserved but values are" {
  let text = "# top comment\na = 1 # inline\n\n# another\nb = 2\n"
  let t = @toml-mbt.parse(text).unwrap()
  let out = @toml-mbt.serialize(t)
  let t2 = @toml-mbt.parse(out).unwrap()
  assert_eq(t2, t)
}
