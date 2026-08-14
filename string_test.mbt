///|
/// Blackbox tests for the four TOML string forms and their escape handling.

///|
test "parse basic string" {
  let t = @toml-mbt.parse("s = \"hello world\"\n").unwrap()
  match t.get("s") {
    Some(String(s)) => assert_eq(s, "hello world")
    _ => assert_true(false)
  }
}

///|
test "parse basic string with escapes" {
  let t = @toml-mbt.parse("s = \"a\\nb\\t\\\"c\\\\d\"\n").unwrap()
  match t.get("s") {
    Some(String(s)) => assert_eq(s, "a\nb\t\"c\\d")
    _ => assert_true(false)
  }
}

///|
test "parse literal string (no escapes)" {
  let t = @toml-mbt.parse("s = 'C:\\Users\\nodejs'\n").unwrap()
  match t.get("s") {
    Some(String(s)) => assert_eq(s, "C:\\Users\\nodejs")
    _ => assert_true(false)
  }
}

///|
test "parse multiline basic string" {
  let t = @toml-mbt.parse("s = \"\"\"\nline1\nline2\n\"\"\"\n").unwrap()
  match t.get("s") {
    Some(String(s)) => assert_eq(s, "line1\nline2\n")
    _ => assert_true(false)
  }
}

///|
test "parse multiline literal string" {
  let t = @toml-mbt.parse("s = '''\nraw\\ntext\n'''\n").unwrap()
  match t.get("s") {
    Some(String(s)) => assert_eq(s, "raw\\ntext\n")
    _ => assert_true(false)
  }
}

///|
test "parse unicode escape" {
  let t = @toml-mbt.parse("s = \"\\u0041\\u00E9\"\n").unwrap()
  match t.get("s") {
    Some(String(s)) => assert_eq(s, "Aé")
    _ => assert_true(false)
  }
}

///|
test "parse emoji escape via scalar value" {
  let t = @toml-mbt.parse("s = \"\\U0001F600\"\n").unwrap()
  match t.get("s") {
    Some(String(s)) => assert_eq(s, "😀")
    _ => assert_true(false)
  }
}

///|
test "lone surrogate escape is invalid" {
  assert_true(@toml-mbt.parse("s = \"\\uD83D\"\n").is_err())
}

///|
test "empty string" {
  let t = @toml-mbt.parse("s = \"\"\n").unwrap()
  match t.get("s") {
    Some(String(s)) => assert_eq(s, "")
    _ => assert_true(false)
  }
}

///|
test "unterminated string is an error" {
  match @toml-mbt.parse("s = \"oops\n") {
    Ok(_) => assert_true(false)
    Err(_) => ()
  }
}

///|
test "invalid escape is an error" {
  match @toml-mbt.parse("s = \"\\q\"\n") {
    Ok(_) => assert_true(false)
    Err(_) => ()
  }
}
