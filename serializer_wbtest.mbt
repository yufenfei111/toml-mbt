///|
/// Whitebox tests for the serializer's private formatting helpers.

///|
test "format_float integer-valued" {
  assert_eq(format_float(3.0), "3.0")
}

///|
test "format_float fractional" {
  assert_eq(format_float(3.14), "3.14")
}

///|
test "format_float infinity" {
  assert_eq(format_float(@double.infinity), "inf")
}

///|
test "format_float negative infinity" {
  assert_eq(format_float(@double.neg_infinity), "-inf")
}

///|
test "format_float nan" {
  assert_eq(format_float(@double.not_a_number), "nan")
}

///|
test "format_date pads to four digits" {
  assert_eq(format_date(LocalDate::new(1979, 5, 27)), "1979-05-27")
}

///|
test "format_date pads small month and day" {
  assert_eq(format_date(LocalDate::new(1, 1, 1)), "0001-01-01")
}

///|
test "format_time without fraction" {
  assert_eq(format_time(LocalTime::new(7, 32, 0, 0)), "07:32:00")
}

///|
test "format_time with fraction" {
  assert_eq(format_time(LocalTime::new(7, 32, 0, 500_000_000)), "07:32:00.5")
}

///|
test "format_time trims trailing zero fraction" {
  assert_eq(format_time(LocalTime::new(0, 0, 0, 50_000_000)), "00:00:00.05")
}

///|
test "format_offset Z" {
  assert_eq(format_offset(0), "Z")
}

///|
test "format_offset negative" {
  assert_eq(format_offset(-420), "-07:00")
}

///|
test "format_offset positive" {
  assert_eq(format_offset(330), "+05:30")
}

///|
test "format_frac single digit" {
  assert_eq(format_frac(500_000_000), "5")
}

///|
test "format_frac keeps significant digits" {
  assert_eq(format_frac(123_456_789), "123456789")
}

///|
test "pad pads with leading zeros" {
  assert_eq(pad(5, 2), "05")
  assert_eq(pad(1979, 4), "1979")
}

///|
test "is_bare_key accepts simple key" {
  assert_eq(is_bare_key("key"), true)
  assert_eq(is_bare_key("key-with-dash"), true)
  assert_eq(is_bare_key("key_with_123"), true)
}

///|
test "is_bare_key rejects spaces and dots" {
  assert_eq(is_bare_key("key with space"), false)
  assert_eq(is_bare_key("key.dot"), false)
  assert_eq(is_bare_key(""), false)
}

///|
test "serialize_key_segment quotes non-bare key" {
  assert_eq(serialize_key_segment("a b"), "\"a b\"")
  assert_eq(serialize_key_segment("key"), "key")
}

///|
test "escape_basic_string escapes quotes" {
  assert_eq(escape_basic_string("a\"b"), "a\\\"b")
}

///|
test "escape_basic_string escapes backslash" {
  assert_eq(escape_basic_string("a\\b"), "a\\\\b")
}

///|
test "escape_basic_string escapes newline" {
  assert_eq(escape_basic_string("a\nb"), "a\\nb")
}

///|
test "escape_basic_string leaves plain text" {
  assert_eq(escape_basic_string("hello"), "hello")
}

///|
test "all_tables empty array is false" {
  assert_eq(all_tables([]), false)
}

///|
test "all_tables mixed array is false" {
  assert_eq(all_tables([Integer(1L), Table(Map([]))]), false)
}

///|
test "all_tables pure table array is true" {
  assert_eq(all_tables([Table(Map([])), Table(Map([]))]), true)
}

///|
test "serialize_value string" {
  assert_eq(serialize_value(String("hi")), "\"hi\"")
}

///|
test "serialize_value integer" {
  assert_eq(serialize_value(Integer(42L)), "42")
}

///|
test "serialize_value boolean" {
  assert_eq(serialize_value(Boolean(true)), "true")
}

///|
test "serialize_value array" {
  assert_eq(serialize_value(Array([Integer(1L), Integer(2L)])), "[1, 2]")
}

///|
test "serialize_value date" {
  assert_eq(
    serialize_value(LocalDate(LocalDate::new(1979, 5, 27))),
    "1979-05-27",
  )
}
