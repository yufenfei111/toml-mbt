///|
/// Blackbox tests for error cases and error reporting.

///|
test "duplicate key at root" {
  assert_true(@toml-mbt.parse("a = 1\na = 2\n").is_err())
}

///|
test "duplicate key in inline table" {
  assert_true(@toml-mbt.parse("t = { a = 1, a = 2 }\n").is_err())
}

///|
test "redefining a table" {
  assert_true(@toml-mbt.parse("[a]\n[a]\n").is_err())
}

///|
test "redefining an implicitly created table" {
  assert_true(@toml-mbt.parse("[a.b]\n[a]\n").is_err())
}

///|
test "mixing table and array of tables" {
  assert_true(@toml-mbt.parse("[a]\n[[a]]\n").is_err())
}

///|
test "extending a non-table value" {
  assert_true(@toml-mbt.parse("a = 1\n[a.b]\n").is_err())
}

///|
test "missing value" {
  assert_true(@toml-mbt.parse("a =\n").is_err())
}

///|
test "bare key as value is an error" {
  assert_true(@toml-mbt.parse("a = bareword\n").is_err())
}

///|
test "error carries line and column" {
  match @toml-mbt.parse("ok = 1\nbad = @@@\n") {
    Ok(_) => assert_true(false)
    Err(e) => {
      // The error message should mention the offending line.
      assert_true(e.to_string().contains("line 2"))
    }
  }
}

///|
test "empty document is valid" {
  let t = @toml-mbt.parse("").unwrap()
  assert_eq(t.length(), 0)
}

///|
test "only comments and whitespace is valid" {
  let t = @toml-mbt.parse("# comment\n\n# another\n").unwrap()
  assert_eq(t.length(), 0)
}
