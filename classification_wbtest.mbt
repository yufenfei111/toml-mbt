///|
/// Whitebox tests for word classification: deciding whether a bare word is a
/// float, a date-time, or an integer.

///|
test "classify: decimal integer is not a float" {
  assert_eq(is_float_word("42"), false)
  assert_eq(is_float_word("-17"), false)
}

///|
test "classify: hex integer is not a float" {
  assert_eq(is_float_word("0xDEADBEEF"), false)
  assert_eq(is_float_word("0x1e"), false)
}

///|
test "classify: octal and binary are not floats" {
  assert_eq(is_float_word("0o755"), false)
  assert_eq(is_float_word("0b1010"), false)
}

///|
test "classify: floats with fraction" {
  assert_eq(is_float_word("3.14"), true)
  assert_eq(is_float_word("0.5"), true)
}

///|
test "classify: floats with exponent" {
  assert_eq(is_float_word("1e6"), true)
  assert_eq(is_float_word("5E22"), true)
}

///|
test "classify: special floats" {
  assert_eq(is_float_word("inf"), true)
  assert_eq(is_float_word("-inf"), true)
  assert_eq(is_float_word("nan"), true)
  assert_eq(is_float_word("+nan"), true)
}

///|
test "classify: datetime words are not floats" {
  assert_eq(is_float_word("1979-05-27"), false)
  assert_eq(is_float_word("07:32:00"), false)
}

///|
test "classify: datetime detection" {
  assert_eq(is_datetime_word("1979-05-27"), true)
  assert_eq(is_datetime_word("07:32:00"), true)
  assert_eq(is_datetime_word("1979-05-27T07:32:00Z"), true)
  assert_eq(is_datetime_word("42"), false)
}

///|
test "classify: base prefix detection" {
  assert_eq(has_integer_base_prefix("0x1f"), true)
  assert_eq(has_integer_base_prefix("0X1F"), true)
  assert_eq(has_integer_base_prefix("0o755"), true)
  assert_eq(has_integer_base_prefix("0b101"), true)
  assert_eq(has_integer_base_prefix("-0x1f"), true)
  assert_eq(has_integer_base_prefix("42"), false)
  assert_eq(has_integer_base_prefix("0"), false)
}

///|
test "classify: leading zero detection" {
  assert_eq(has_leading_zero("01"), true)
  assert_eq(has_leading_zero("0"), false)
  assert_eq(has_leading_zero("-01"), true)
  assert_eq(has_leading_zero("0x10"), false)
  assert_eq(has_leading_zero("10"), false)
}
