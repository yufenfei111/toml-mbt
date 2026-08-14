///|
/// Conversion from a parsed `Table` to the tagged JSON format used by the
/// official `toml-test` conformance suite. Primitive values are tagged with
/// their TOML type; tables and arrays map to plain JSON objects and arrays.

///|
/// Converts a table to the toml-test tagged JSON representation.
pub fn to_json(table : Table) -> Json {
  table_to_json(table)
}

///|
fn table_to_json(table : Table) -> Json {
  let object : Map[String, Json] = Map([])
  for key, value in table {
    object.set(key, value_to_json(value))
  }
  Json::object(object)
}

///|
fn value_to_json(value : Value) -> Json {
  match value {
    String(s) => tagged("string", s)
    Integer(i) => tagged("integer", i.to_string())
    Float(f) => tagged("float", format_float(f))
    Boolean(b) => tagged("bool", if b { "true" } else { "false" })
    OffsetDateTime(dt) =>
      tagged("datetime", format_offset_datetime(dt))
    LocalDateTime(dt) => tagged("datetime-local", format_local_datetime(dt))
    LocalDate(d) => tagged("date-local", format_date(d))
    LocalTime(t) => tagged("time-local", format_time(t))
    Array(arr) => {
      let items : Array[Json] = []
      for v in arr {
        items.push(value_to_json(v))
      }
      Json::array(items)
    }
    Table(t) => table_to_json(t)
  }
}

///|
fn tagged(kind : String, value : String) -> Json {
  let object : Map[String, Json] = Map([])
  object.set("type", Json::string(kind))
  object.set("value", Json::string(value))
  Json::object(object)
}

///|
fn format_offset_datetime(dt : OffsetDateTime) -> String {
  format_date(dt.date) + "T" + format_time(dt.time) + format_offset(dt.offset_minutes)
}

///|
fn format_local_datetime(dt : LocalDateTime) -> String {
  format_date(dt.date) + "T" + format_time(dt.time)
}
