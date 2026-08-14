///|
/// Additional conformance cases covering edge cases beyond the main suites.

///|
fn ok(text : String) -> @toml-mbt.Table {
  match @toml-mbt.parse(text) {
    Ok(t) => t
    Err(e) => abort("unexpected error: \{e.to_string()}")
  }
}

///|
fn bad(text : String) -> Unit {
  match @toml-mbt.parse(text) {
    Ok(_) => abort("expected error for: \{text}")
    Err(_) => ()
  }
}

///|
fn val(t : @toml-mbt.Table, k : String) -> @toml-mbt.Value {
  match t.get(k) {
    Some(v) => v
    None => abort("missing: \{k}")
  }
}

///|
test "extra: unicode bare key" {
  let t = ok("键 = 1\n")
  match val(t, "键") {
    Integer(v) => assert_eq(v, 1L)
    _ => assert_true(false)
  }
}

///|
test "extra: empty multiline basic string" {
  let t = ok("s = \"\"\"\"\"\"\n")
  match val(t, "s") {
    String(v) => assert_eq(v, "")
    _ => assert_true(false)
  }
}

///|
test "extra: string with all simple escapes" {
  let t = ok("s = \"\\b\\t\\n\\f\\r\"\n")
  match val(t, "s") {
    String(v) => assert_eq(v, "\x08\t\n\x0C\r")
    _ => assert_true(false)
  }
}

///|
test "extra: offset datetime with fractional seconds" {
  let t = ok("d = 1979-05-27T07:32:00.999999-07:00\n")
  match val(t, "d") {
    OffsetDateTime(dt) => {
      assert_eq(dt.time.nanosecond, 999_999_000)
      assert_eq(dt.offset_minutes, -420)
    }
    _ => assert_true(false)
  }
}

///|
test "extra: lowercase z offset" {
  let t = ok("d = 1979-05-27T07:32:00z\n")
  match val(t, "d") {
    OffsetDateTime(dt) => assert_eq(dt.offset_minutes, 0)
    _ => assert_true(false)
  }
}

///|
test "extra: array of inline tables" {
  let t = ok("points = [ { x = 1, y = 2 }, { x = 3, y = 4 } ]\n")
  match val(t, "points") {
    Array(arr) => {
      assert_eq(arr.length(), 2)
      match arr[1] {
        Table(p) =>
          match p.get("x") {
            Some(Integer(v)) => assert_eq(v, 3L)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "extra: array spanning multiple lines" {
  let t = ok("a = [\n  1,\n  2,\n  3,\n]\n")
  match val(t, "a") {
    Array(arr) => assert_eq(arr.length(), 3)
    _ => assert_true(false)
  }
}

///|
test "extra: inline table spanning multiple lines" {
  let t = ok("a = {\n  x = 1,\n  y = 2,\n}\n")
  match val(t, "a") {
    Table(p) => assert_eq(p.length(), 2)
    _ => assert_true(false)
  }
}

///|
test "extra: deeply nested tables" {
  let t = ok("[a.b.c.d.e]\nf = 1\n")
  match val(t, "a") {
    Table(a) =>
      match a.get("b") {
        Some(Table(b)) =>
          match b.get("c") {
            Some(Table(c)) =>
              match c.get("d") {
                Some(Table(d)) =>
                  match d.get("e") {
                    Some(Table(e)) =>
                      match e.get("f") {
                        Some(Integer(v)) => assert_eq(v, 1L)
                        _ => assert_true(false)
                      }
                    _ => assert_true(false)
                  }
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "extra: dotted key defines intermediate tables" {
  let t = ok("a.b.c.d = 1\n")
  match val(t, "a") {
    Table(a) =>
      match a.get("b") {
        Some(Table(b)) =>
          match b.get("c") {
            Some(Table(c)) =>
              match c.get("d") {
                Some(Integer(v)) => assert_eq(v, 1L)
                _ => assert_true(false)
              }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "extra: quoted key with unicode" {
  let t = ok("\"键 键\" = 1\n")
  match val(t, "键 键") {
    Integer(v) => assert_eq(v, 1L)
    _ => assert_true(false)
  }
}

///|
test "extra: round-trip with datetimes" {
  let text = "od = 1979-05-27T07:32:00Z\nld = 1979-05-27T07:32:00\n"
  let t = ok(text)
  assert_eq(ok(@toml-mbt.serialize(t)), t)
}

///|
test "extra: round-trip with nested arrays" {
  let text = "a = [[1, 2], [3, 4]]\n"
  let t = ok(text)
  assert_eq(ok(@toml-mbt.serialize(t)), t)
}

///|
test "extra: round-trip with inline table" {
  let text = "p = { x = 1, y = \"hi\" }\n"
  let t = ok(text)
  assert_eq(ok(@toml-mbt.serialize(t)), t)
}

///|
test "invalid extra: duplicate nested key" {
  bad("a.b = 1\na.b = 2\n")
}

///|
test "invalid extra: redefine via dotted key after table" {
  bad("[a]\nb = 1\n[a.b]\nc = 2\n")
}

///|
test "invalid extra: array missing closing bracket" {
  bad("a = [1, 2\n")
}

///|
test "invalid extra: inline table missing closing brace" {
  bad("a = { b = 1\n")
}

///|
test "invalid extra: invalid integer with sign only" {
  bad("a = +\n")
}

///|
test "invalid extra: float with double exponent" {
  bad("a = 1e2e3\n")
}

///|
test "invalid extra: date with trailing garbage" {
  bad("d = 1979-05-27abc\n")
}

///|
test "invalid extra: time with missing seconds" {
  bad("t = 07:32\n")
}

///|
test "invalid extra: array of tables under scalar" {
  bad("a = 1\n[[a]]\n")
}

///|
test "invalid extra: empty dotted key segment" {
  bad("a..b = 1\n")
}

///|
test "invalid extra: key with trailing dot" {
  bad("a. = 1\n")
}

///|
test "invalid extra: string with unescaped control char" {
  bad("s = \"a\x01b\"\n")
}

///|
test "invalid extra: comment before value" {
  bad("a = # comment\n")
}

///|
test "invalid extra: inline table with newline in single line" {
  bad("a = { b = 1\nc = 2 }\n")
}

///|
test "invalid extra: equals without key" {
  bad("= 1\n")
}

///|
test "invalid extra: bare key with equals in middle" {
  bad("a = = 1\n")
}
