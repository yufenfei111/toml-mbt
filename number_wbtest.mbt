///|
/// Whitebox tests for integer and float parsing.

///|
test "parse decimal integer" {
  assert_eq(parse_integer_str("42").unwrap(), 42L)
}

///|
test "parse negative integer" {
  assert_eq(parse_integer_str("-17").unwrap(), -17L)
}

///|
test "parse integer with underscores" {
  assert_eq(parse_integer_str("1_000").unwrap(), 1000L)
}

///|
test "parse hex integer" {
  assert_eq(parse_integer_str("0xDEADBEEF").unwrap(), 0xDEADBEEFL)
}

///|
test "parse octal integer" {
  assert_eq(parse_integer_str("0o755").unwrap(), 0o755L)
}

///|
test "parse binary integer" {
  assert_eq(parse_integer_str("0b1010").unwrap(), 0b1010L)
}

///|
test "parse max int64" {
  assert_eq(
    parse_integer_str("9223372036854775807").unwrap(),
    9223372036854775807L,
  )
}

///|
test "integer rejects leading zero" {
  assert_true(parse_integer_str("01").is_err())
}

///|
test "integer rejects overflow" {
  assert_true(parse_integer_str("9223372036854775808").is_err())
}

///|
test "integer rejects garbage" {
  assert_true(parse_integer_str("12abc").is_err())
}

///|
test "parse float with fraction" {
  assert_eq(parse_float_str("3.14").unwrap(), 3.14)
}

///|
test "parse float with exponent" {
  assert_eq(parse_float_str("5e2").unwrap(), 500.0)
}

///|
test "parse float with underscores" {
  assert_eq(parse_float_str("1_000.5").unwrap(), 1000.5)
}

///|
test "parse positive infinity" {
  assert_true(parse_float_str("inf").unwrap().is_inf())
}

///|
test "parse negative infinity" {
  assert_true(parse_float_str("-inf").unwrap().is_neg_inf())
}

///|
test "parse NaN" {
  assert_true(parse_float_str("nan").unwrap().is_nan())
}

///|
test "float rejects garbage" {
  assert_true(parse_float_str("1.2.3").is_err())
}

///|
test "has leading zero detects decimal" {
  assert_true(has_leading_zero("0123"))
  assert_true(!has_leading_zero("0"))
  assert_true(!has_leading_zero("0x10"))
  assert_true(!has_leading_zero("123"))
}
