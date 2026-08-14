///|
/// Conformance tests derived from the toml-test `valid` suite. Each case checks
/// that a well-formed TOML document parses to the expected value.

///|
fn parse_ok(text : String) -> @toml-mbt.Table {
  match @toml-mbt.parse(text) {
    Ok(t) => t
    Err(e) => abort("unexpected parse error: \{e.to_string()}")
  }
}

///|
fn get(table : @toml-mbt.Table, key : String) -> @toml-mbt.Value {
  match table.get(key) {
    Some(v) => v
    None => abort("missing key: \{key}")
  }
}

///|
test "valid: integers in all bases" {
  let t = parse_ok("dec = 42\nhex = 0x2A\noct = 0o52\nbin = 0b101010\n")
  match get(t, "dec") {
    Integer(v) => assert_eq(v, 42L)
    _ => assert_true(false)
  }
  match get(t, "hex") {
    Integer(v) => assert_eq(v, 42L)
    _ => assert_true(false)
  }
  match get(t, "oct") {
    Integer(v) => assert_eq(v, 42L)
    _ => assert_true(false)
  }
  match get(t, "bin") {
    Integer(v) => assert_eq(v, 42L)
    _ => assert_true(false)
  }
}

///|
test "valid: signed integers" {
  let t = parse_ok("a = +99\nb = -17\nc = 0\n")
  match get(t, "a") {
    Integer(v) => assert_eq(v, 99L)
    _ => assert_true(false)
  }
  match get(t, "b") {
    Integer(v) => assert_eq(v, -17L)
    _ => assert_true(false)
  }
  match get(t, "c") {
    Integer(v) => assert_eq(v, 0L)
    _ => assert_true(false)
  }
}

///|
test "valid: integer with underscores" {
  let t = parse_ok("n = 1_000_000\n")
  match get(t, "n") {
    Integer(v) => assert_eq(v, 1_000_000L)
    _ => assert_true(false)
  }
}

///|
test "valid: int64 boundary" {
  let t = parse_ok("min = -9223372036854775808\nmax = 9223372036854775807\n")
  match get(t, "max") {
    Integer(v) => assert_eq(v, 9223372036854775807L)
    _ => assert_true(false)
  }
  match get(t, "min") {
    Integer(v) => assert_eq(v, -9223372036854775808L)
    _ => assert_true(false)
  }
}

///|
test "valid: floats" {
  let t = parse_ok("a = 1.0\nb = 3.1415\nc = -0.01\nd = 5e+22\ne = 1e06\n")
  match get(t, "d") {
    Float(v) => assert_eq(v, 5.0e22)
    _ => assert_true(false)
  }
  match get(t, "e") {
    Float(v) => assert_eq(v, 1.0e6)
    _ => assert_true(false)
  }
}

///|
test "valid: float special values" {
  let t = parse_ok("a = inf\nb = +inf\nc = -inf\nd = nan\ne = +nan\nf = -nan\n")
  match get(t, "a") {
    Float(v) => assert_true(v.is_inf())
    _ => assert_true(false)
  }
  match get(t, "c") {
    Float(v) => assert_true(v.is_neg_inf())
    _ => assert_true(false)
  }
  match get(t, "d") {
    Float(v) => assert_true(v.is_nan())
    _ => assert_true(false)
  }
}

///|
test "valid: booleans" {
  let t = parse_ok("a = true\nb = false\n")
  match get(t, "a") {
    Boolean(v) => assert_eq(v, true)
    _ => assert_true(false)
  }
  match get(t, "b") {
    Boolean(v) => assert_eq(v, false)
    _ => assert_true(false)
  }
}

///|
test "valid: basic strings" {
  let t = parse_ok("s = \"I'm a string. \\\"You can quote me\\\"\"\n")
  match get(t, "s") {
    String(v) => assert_eq(v, "I'm a string. \"You can quote me\"")
    _ => assert_true(false)
  }
}

///|
test "valid: literal strings" {
  let t = parse_ok("s = 'C:\\Users\\nodejs\\templates'\n")
  match get(t, "s") {
    String(v) => assert_eq(v, "C:\\Users\\nodejs\\templates")
    _ => assert_true(false)
  }
}

///|
test "valid: multiline basic string" {
  let t = parse_ok("s = \"\"\"\nRoses are red\nViolets are blue\"\"\"\n")
  match get(t, "s") {
    String(v) => assert_eq(v, "Roses are red\nViolets are blue")
    _ => assert_true(false)
  }
}

///|
test "valid: multiline literal string" {
  let t = parse_ok(
    "s = '''\nThe first newline is\ntrimmed in raw strings.\n   '''\n",
  )
  match get(t, "s") {
    String(v) =>
      assert_eq(v, "The first newline is\ntrimmed in raw strings.\n   ")
    _ => assert_true(false)
  }
}

///|
test "valid: array of integers" {
  let t = parse_ok("a = [1, 2, 3]\n")
  match get(t, "a") {
    Array(arr) => assert_eq(arr.length(), 3)
    _ => assert_true(false)
  }
}

///|
test "valid: heterogeneous array" {
  let t = parse_ok("a = [1, \"two\", 3.0, true]\n")
  match get(t, "a") {
    Array(arr) => {
      assert_eq(arr.length(), 4)
      match arr[3] {
        Boolean(b) => assert_eq(b, true)
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "valid: nested arrays" {
  let t = parse_ok("a = [[1, 2], [3, 4]]\n")
  match get(t, "a") {
    Array(outer) =>
      match outer[0] {
        Array(inner) => assert_eq(inner.length(), 2)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "valid: array with trailing comma" {
  let t = parse_ok("a = [1, 2, 3,]\n")
  match get(t, "a") {
    Array(arr) => assert_eq(arr.length(), 3)
    _ => assert_true(false)
  }
}

///|
test "valid: empty array" {
  let t = parse_ok("a = []\n")
  match get(t, "a") {
    Array(arr) => assert_eq(arr.length(), 0)
    _ => assert_true(false)
  }
}

///|
test "valid: inline table" {
  let t = parse_ok("point = { x = 1, y = 2 }\n")
  match get(t, "point") {
    Table(p) =>
      match p.get("y") {
        Some(Integer(v)) => assert_eq(v, 2L)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "valid: empty inline table" {
  let t = parse_ok("point = {}\n")
  match get(t, "point") {
    Table(p) => assert_eq(p.length(), 0)
    _ => assert_true(false)
  }
}

///|
test "valid: nested inline table" {
  let t = parse_ok("a = { b = { c = 1 } }\n")
  match get(t, "a") {
    Table(outer) =>
      match outer.get("b") {
        Some(Table(inner)) =>
          match inner.get("c") {
            Some(Integer(v)) => assert_eq(v, 1L)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "valid: table header" {
  let t = parse_ok("[table]\nkey = \"value\"\n")
  match get(t, "table") {
    Table(sub) =>
      match sub.get("key") {
        Some(String(v)) => assert_eq(v, "value")
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "valid: dotted table header" {
  let t = parse_ok("[a.b.c]\nkey = 1\n")
  match get(t, "a") {
    Table(a) =>
      match a.get("b") {
        Some(Table(b)) =>
          match b.get("c") {
            Some(Table(c)) =>
              match c.get("key") {
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
test "valid: dotted keys" {
  let t = parse_ok("a.b.c = 1\n")
  match get(t, "a") {
    Table(a) =>
      match a.get("b") {
        Some(Table(b)) =>
          match b.get("c") {
            Some(Integer(v)) => assert_eq(v, 1L)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "valid: array of tables" {
  let t = parse_ok(
    "[[fruits]]\nname = \"apple\"\n\n[[fruits]]\nname = \"pear\"\n",
  )
  match get(t, "fruits") {
    Array(arr) => assert_eq(arr.length(), 2)
    _ => assert_true(false)
  }
}

///|
test "valid: nested array of tables" {
  let t = parse_ok("[[a.b]]\nx = 1\n")
  match get(t, "a") {
    Table(a) =>
      match a.get("b") {
        Some(Array(arr)) => assert_eq(arr.length(), 1)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "valid: quoted keys" {
  let t = parse_ok("\"key with space\" = 1\n'literal.key' = 2\n")
  match get(t, "key with space") {
    Integer(v) => assert_eq(v, 1L)
    _ => assert_true(false)
  }
  match get(t, "literal.key") {
    Integer(v) => assert_eq(v, 2L)
    _ => assert_true(false)
  }
}

///|
test "valid: bare keys with dashes and underscores" {
  let t = parse_ok("bare-key = 1\nbare_key = 2\n1234 = 3\n")
  match get(t, "bare-key") {
    Integer(v) => assert_eq(v, 1L)
    _ => assert_true(false)
  }
  match get(t, "bare_key") {
    Integer(v) => assert_eq(v, 2L)
    _ => assert_true(false)
  }
  match get(t, "1234") {
    Integer(v) => assert_eq(v, 3L)
    _ => assert_true(false)
  }
}

///|
test "valid: dotted key with quoted segment" {
  let t = parse_ok("site.\"google.com\" = true\n")
  match get(t, "site") {
    Table(site) =>
      match site.get("google.com") {
        Some(Boolean(v)) => assert_eq(v, true)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "valid: offset date-time" {
  let t = parse_ok("d = 1979-05-27T07:32:00Z\n")
  match get(t, "d") {
    OffsetDateTime(dt) => {
      assert_eq(dt.date.year, 1979)
      assert_eq(dt.time.hour, 7)
      assert_eq(dt.offset_minutes, 0)
    }
    _ => assert_true(false)
  }
}

///|
test "valid: offset date-time with negative offset" {
  let t = parse_ok("d = 1979-05-27T00:32:00-07:00\n")
  match get(t, "d") {
    OffsetDateTime(dt) => assert_eq(dt.offset_minutes, -420)
    _ => assert_true(false)
  }
}

///|
test "valid: local date-time" {
  let t = parse_ok("d = 1979-05-27T07:32:00\n")
  match get(t, "d") {
    LocalDateTime(dt) => assert_eq(dt.time.second, 0)
    _ => assert_true(false)
  }
}

///|
test "valid: space-separated date-time" {
  let t = parse_ok("d = 1979-05-27 07:32:00\n")
  match get(t, "d") {
    LocalDateTime(dt) => assert_eq(dt.time.hour, 7)
    _ => assert_true(false)
  }
}

///|
test "valid: local date" {
  let t = parse_ok("d = 1979-05-27\n")
  match get(t, "d") {
    LocalDate(dt) => assert_eq(dt.month, 5)
    _ => assert_true(false)
  }
}

///|
test "valid: local time" {
  let t = parse_ok("t = 07:32:00\n")
  match get(t, "t") {
    LocalTime(v) => assert_eq(v.minute, 32)
    _ => assert_true(false)
  }
}

///|
test "valid: fractional seconds" {
  let t = parse_ok("t = 00:32:00.999999\n")
  match get(t, "t") {
    LocalTime(v) => assert_eq(v.nanosecond, 999_999_000)
    _ => assert_true(false)
  }
}

///|
test "valid: comments are ignored" {
  let t = parse_ok("# full line comment\na = 1 # trailing\n")
  match get(t, "a") {
    Integer(v) => assert_eq(v, 1L)
    _ => assert_true(false)
  }
}

///|
test "valid: empty document" {
  let t = parse_ok("")
  assert_eq(t.length(), 0)
}

///|
test "valid: unicode in strings" {
  let t = parse_ok("s = \"héllo wörld 你好\"\n")
  match get(t, "s") {
    String(v) => assert_eq(v, "héllo wörld 你好")
    _ => assert_true(false)
  }
}

///|
test "valid: unicode escape" {
  let t = parse_ok("s = \"\\u03B1\\u03B2\"\n")
  match get(t, "s") {
    String(v) => assert_eq(v, "αβ")
    _ => assert_true(false)
  }
}

///|
test "valid: table defined out of order" {
  let t = parse_ok("[a.b]\nx = 1\n[a.c]\ny = 2\n")
  match get(t, "a") {
    Table(a) => {
      match a.get("b") {
        Some(Table(b)) =>
          match b.get("x") {
            Some(Integer(v)) => assert_eq(v, 1L)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
      match a.get("c") {
        Some(Table(c)) =>
          match c.get("y") {
            Some(Integer(v)) => assert_eq(v, 2L)
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    _ => assert_true(false)
  }
}

///|
test "valid: carriage return newlines" {
  let t = parse_ok("a = 1\r\nb = 2\r\n")
  match get(t, "b") {
    Integer(v) => assert_eq(v, 2L)
    _ => assert_true(false)
  }
}

///|
test "valid: round-trip complex document" {
  let text = "title = \"demo\"\n\n[server]\nhost = \"localhost\"\nports = [80, 443]\n\n[[users]]\nname = \"a\"\n"
  let t = parse_ok(text)
  assert_eq(parse_ok(@toml-mbt.serialize(t)), t)
}
