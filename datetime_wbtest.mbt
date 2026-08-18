///|
/// Whitebox tests for date-time parsing (the pure `parse_*_str` helpers).

///|
test "parse local date" {
  let d = parse_date_str("1979-05-27").unwrap()
  assert_eq(d.year, 1979)
  assert_eq(d.month, 5)
  assert_eq(d.day, 27)
}

///|
test "parse date rejects invalid month" {
  assert_true(parse_date_str("1979-13-01") is Err(_))
}

///|
test "parse date rejects invalid day" {
  assert_true(parse_date_str("2007-02-31") is Err(_))
}

///|
test "parse date accepts leap day" {
  let d = parse_date_str("2000-02-29").unwrap()
  assert_eq(d.day, 29)
}

///|
test "parse date rejects non-leap leap day" {
  assert_true(parse_date_str("1900-02-29") is Err(_))
}

///|
test "parse local time" {
  let t = parse_time_str("07:32:00").unwrap()
  assert_eq(t.hour, 7)
  assert_eq(t.minute, 32)
  assert_eq(t.second, 0)
  assert_eq(t.nanosecond, 0)
}

///|
test "parse time with fractional seconds" {
  let t = parse_time_str("07:32:00.5").unwrap()
  assert_eq(t.nanosecond, 500_000_000)
}

///|
test "parse time with nanosecond precision" {
  let t = parse_time_str("00:00:00.123456789").unwrap()
  assert_eq(t.nanosecond, 123_456_789)
}

///|
test "parse time rejects invalid hour" {
  assert_true(parse_time_str("24:00:00") is Err(_))
}

///|
test "parse offset Z" {
  assert_eq(parse_offset_str("Z").unwrap(), 0)
}

///|
test "parse offset negative" {
  assert_eq(parse_offset_str("-07:00").unwrap(), -420)
}

///|
test "parse offset positive" {
  assert_eq(parse_offset_str("+05:30").unwrap(), 330)
}

///|
test "parse offset rejects invalid" {
  assert_true(parse_offset_str("25:00") is Err(_))
}

///|
test "parse offset date-time" {
  match parse_datetime_str("1979-05-27T07:32:00Z", None) {
    Ok(OffsetDateTime(dt)) => {
      assert_eq(dt.date.year, 1979)
      assert_eq(dt.time.hour, 7)
      assert_eq(dt.offset_minutes, 0)
    }
    _ => assert_true(false)
  }
}

///|
test "parse offset date-time with offset" {
  match parse_datetime_str("1979-05-27T00:32:00-07:00", None) {
    Ok(OffsetDateTime(dt)) => assert_eq(dt.offset_minutes, -420)
    _ => assert_true(false)
  }
}

///|
test "parse local date-time with T separator" {
  match parse_datetime_str("1979-05-27T07:32:00", None) {
    Ok(LocalDateTime(dt)) => {
      assert_eq(dt.date.day, 27)
      assert_eq(dt.time.second, 0)
    }
    _ => assert_true(false)
  }
}

///|
test "parse local date-time with lowercase t" {
  match parse_datetime_str("1979-05-27t07:32:00", None) {
    Ok(LocalDateTime(dt)) => assert_eq(dt.time.hour, 7)
    _ => assert_true(false)
  }
}

///|
test "parse space-separated local date-time" {
  match parse_datetime_str("1979-05-27", Some("07:32:00")) {
    Ok(LocalDateTime(dt)) => assert_eq(dt.time.hour, 7)
    _ => assert_true(false)
  }
}

///|
test "parse local time only" {
  match parse_datetime_str("07:32:00", None) {
    Ok(LocalTime(t)) => assert_eq(t.hour, 7)
    _ => assert_true(false)
  }
}

///|
test "parse date rejects missing day" {
  assert_true(parse_date_str("1979-05") is Err(_))
}
