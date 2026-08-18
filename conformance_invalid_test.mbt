///|
/// Conformance tests derived from the toml-test `invalid` suite. Each case
/// asserts that malformed TOML is rejected.

///|
fn must_fail(text : String) -> Unit {
  match @toml-mbt.parse(text) {
    Ok(_) => abort("expected parse error for: \{text}")
    Err(_) => ()
  }
}

///|
test "TOML 1.0 rejects Unicode bare keys" {
  must_fail("中文 = 1")
}

///|
test "TOML 1.0 rejects newline in inline table" {
  must_fail("value = { a = 1,\n b = 2 }")
}

///|
test "TOML 1.0 rejects trailing comma in inline table" {
  must_fail("value = { a = 1, }")
}

///|
test "invalid: duplicate key" {
  must_fail("a = 1\na = 2\n")
}

///|
test "invalid: duplicate key in inline table" {
  must_fail("t = { a = 1, a = 2 }\n")
}

///|
test "invalid: redefining a table" {
  must_fail("[a]\n[a]\n")
}

///|
test "invalid: redefining implicitly defined table" {
  must_fail("[a.b]\n[a]\n")
}

///|
test "invalid: mixing table and array of tables" {
  must_fail("[a]\n[[a]]\n")
}

///|
test "invalid: extending a non-table" {
  must_fail("a = 1\n[a.b]\n")
}

///|
test "invalid: leading zero integer" {
  must_fail("a = 01\n")
}

///|
test "invalid: leading zero negative integer" {
  must_fail("a = -01\n")
}

///|
test "invalid: integer overflow" {
  must_fail("a = 9223372036854775808\n")
}

///|
test "invalid: integer underflow" {
  must_fail("a = -9223372036854775809\n")
}

///|
test "invalid: trailing underscore in integer" {
  must_fail("a = 1_\n")
}

///|
test "invalid: double underscore in integer" {
  must_fail("a = 1__2\n")
}

///|
test "invalid: hex without digits" {
  must_fail("a = 0x\n")
}

///|
test "invalid: invalid float" {
  must_fail("a = 1.2.3\n")
}

///|
test "invalid: float without fraction or exponent" {
  must_fail("a = 1.\n")
}

///|
test "invalid: bare word as value" {
  must_fail("a = bareword\n")
}

///|
test "invalid: missing value" {
  must_fail("a =\n")
}

///|
test "invalid: missing equals" {
  must_fail("a 1\n")
}

///|
test "invalid: invalid date" {
  must_fail("d = 1979-13-01\n")
}

///|
test "invalid: invalid day" {
  must_fail("d = 2007-02-31\n")
}

///|
test "invalid: invalid time hour" {
  must_fail("t = 24:00:00\n")
}

///|
test "invalid: invalid time minute" {
  must_fail("t = 07:60:00\n")
}

///|
test "invalid: unterminated string" {
  must_fail("s = \"unterminated\n")
}

///|
test "invalid: newline in single-line string" {
  must_fail("s = \"line\nbreak\"\n")
}

///|
test "invalid: invalid escape" {
  must_fail("s = \"\\q\"\n")
}

///|
test "invalid: lone surrogate escape" {
  must_fail("s = \"\\uD800\"\n")
}

///|
test "invalid: out of range unicode escape" {
  must_fail("s = \"\\U00110000\"\n")
}

///|
test "invalid: array with missing comma" {
  must_fail("a = [1 2]\n")
}

///|
test "invalid: array with trailing double comma" {
  must_fail("a = [1,,2]\n")
}

///|
test "invalid: inline table missing comma" {
  must_fail("t = { a = 1 b = 2 }\n")
}

///|
test "invalid: empty bare key" {
  must_fail("= 1\n")
}

///|
test "invalid: key with leading dot" {
  must_fail(".a = 1\n")
}

///|
test "invalid: unterminated array" {
  must_fail("a = [1, 2\n")
}

///|
test "invalid: unterminated inline table" {
  must_fail("a = { b = 1\n")
}

///|
test "invalid: table header missing bracket" {
  must_fail("[a\nb = 1\n")
}

///|
test "invalid: array of tables missing bracket" {
  must_fail("[[a\nb = 1\n")
}

///|
test "invalid: value on table header line" {
  must_fail("[a] extra\n")
}

///|
test "invalid: two key-values on one line" {
  must_fail("a = 1 b = 2\n")
}
