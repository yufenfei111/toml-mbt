///|
/// A table is a map from string keys to TOML values. The root of any parsed
/// document is a `Table`, and inline tables inside a document are also tables.
pub type Table = Map[String, Value]

///|
/// A calendar date (year-month-day) with no time and no timezone.
pub struct LocalDate {
  year : Int
  month : Int
  day : Int
} derive(Debug, Eq)

///|
/// A wall-clock time (hour:minute:second.nanosecond) with no timezone.
pub struct LocalTime {
  hour : Int
  minute : Int
  second : Int
  nanosecond : Int
} derive(Debug, Eq)

///|
/// A local date-time (a date plus a time, no timezone).
pub struct LocalDateTime {
  date : LocalDate
  time : LocalTime
} derive(Debug, Eq)

///|
/// A date-time with a UTC offset. The offset is stored as a whole number of
/// minutes east of UTC (`-07:00` becomes `-420`, `Z` becomes `0`).
pub struct OffsetDateTime {
  date : LocalDate
  time : LocalTime
  offset_minutes : Int
} derive(Debug, Eq)

///|
/// A TOML value. Mirrors every value kind defined by the TOML 1.0 spec.
pub enum Value {
  String(String)
  Integer(Int64)
  Float(Double)
  Boolean(Bool)
  OffsetDateTime(OffsetDateTime)
  LocalDateTime(LocalDateTime)
  LocalDate(LocalDate)
  LocalTime(LocalTime)
  Array(Array[Value])
  Table(Map[String, Value])
} derive(Debug)

///|
/// Value equality that treats two `Float` NaN values as equal, so that
/// round-trip tests compare NaN round-trips as equal.
pub impl Eq for Value with fn equal(self, other) {
  match (self, other) {
    (String(a), String(b)) => a == b
    (Integer(a), Integer(b)) => a == b
    (Float(a), Float(b)) => a == b || (a != a && b != b)
    (Boolean(a), Boolean(b)) => a == b
    (OffsetDateTime(a), OffsetDateTime(b)) => a == b
    (LocalDateTime(a), LocalDateTime(b)) => a == b
    (LocalDate(a), LocalDate(b)) => a == b
    (LocalTime(a), LocalTime(b)) => a == b
    (Array(a), Array(b)) => a == b
    (Table(a), Table(b)) => a == b
    _ => false
  }
}

///|
/// Constructors for `LocalDate`.
pub fn LocalDate::new(year : Int, month : Int, day : Int) -> LocalDate {
  { year, month, day }
}

///|
/// Constructors for `LocalTime`.
pub fn LocalTime::new(
  hour : Int,
  minute : Int,
  second : Int,
  nanosecond : Int,
) -> LocalTime {
  { hour, minute, second, nanosecond }
}

///|
/// Constructors for `LocalDateTime`.
pub fn LocalDateTime::new(date : LocalDate, time : LocalTime) -> LocalDateTime {
  { date, time }
}

///|
/// Constructors for `OffsetDateTime`.
pub fn OffsetDateTime::new(
  date : LocalDate,
  time : LocalTime,
  offset_minutes : Int,
) -> OffsetDateTime {
  { date, time, offset_minutes }
}
