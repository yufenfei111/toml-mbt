///|
/// Miscellaneous blackbox tests for edge cases and integration behavior.

///|
test "misc: empty inline table in array" {
  let t = @toml-mbt.parse("a = [ {}, {} ]\n").unwrap()
  match t.get("a") {
    Some(Array(arr)) => assert_eq(arr.length(), 2)
    _ => assert_true(false)
  }
}

///|
test "misc: table inside array of tables" {
  let t = @toml-mbt.parse("[[a]]\nb = 1\n[[a]]\nb = 2\nc = [1, 2]\n").unwrap()
  match t.get("a") {
    Some(Array(arr)) => assert_eq(arr.length(), 2)
    _ => assert_true(false)
  }
}

///|
test "misc: parse then serialize is stable" {
  let text = "a = 1\nb = 2\n"
  let t = @toml-mbt.parse(text).unwrap()
  let s1 = @toml-mbt.serialize(t)
  let s2 = @toml-mbt.serialize(@toml-mbt.parse(s1).unwrap())
  assert_eq(s1, s2)
}

///|
test "misc: negative float" {
  let t = @toml-mbt.parse("a = -3.14\n").unwrap()
  match t.get("a") {
    Some(Float(v)) => assert_eq(v, -3.14)
    _ => assert_true(false)
  }
}

///|
test "misc: large float exponent" {
  let t = @toml-mbt.parse("a = 6.626e-34\n").unwrap()
  match t.get("a") {
    Some(Float(v)) => assert_eq(v, 6.626e-34)
    _ => assert_true(false)
  }
}

///|
test "misc: space separator is invalid for offset datetime" {
  // TOML only allows a space separator for local date-time, not offset date-time.
  assert_true(@toml-mbt.parse("d = 1979-05-27 07:32:00-07:00\n").is_err())
}

///|
test "misc: key ordering preserved" {
  let t = @toml-mbt.parse("z = 1\na = 2\nm = 3\n").unwrap()
  let out = @toml-mbt.serialize(t)
  // insertion order is z, a, m
  assert_eq(out, "z = 1\na = 2\nm = 3")
}

///|
test "misc: to_json on nested structure" {
  let t = @toml-mbt.parse("a = { b = 1 }\n").unwrap()
  match @toml-mbt.to_json(t) {
    Object(obj) =>
      match obj.get("a") {
        Some(Object(inner)) =>
          match inner.get("b") {
            Some(Object(tag)) =>
              assert_eq(tag.get("type"), Some(Json::string("integer")))
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "misc: error message contains position" {
  match @toml-mbt.parse("ok = 1\n\nbad = @@@\n") {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.to_string().contains("line 3"))
  }
}

///|
test "misc: windows newline round trip" {
  let t = @toml-mbt.parse("a = 1\r\nb = 2\r\n").unwrap()
  match t.get("b") {
    Some(Integer(v)) => assert_eq(v, 2L)
    _ => assert_true(false)
  }
}

///|
test "misc: deeply nested inline table round trip" {
  let text = "a = { b = { c = { d = 42 } } }\n"
  let t = @toml-mbt.parse(text).unwrap()
  assert_eq(@toml-mbt.parse(@toml-mbt.serialize(t)).unwrap(), t)
}

///|
test "misc: array of arrays round trip" {
  let text = "a = [[1], [2, 3], []]\n"
  let t = @toml-mbt.parse(text).unwrap()
  assert_eq(@toml-mbt.parse(@toml-mbt.serialize(t)).unwrap(), t)
}
