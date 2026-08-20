///|
/// Parses TOML and emits the tagged JSON representation required by
/// toml-test decoders. Object keys are sorted recursively for stable output.
pub fn decode_tagged_json(source : String) -> Result[String, TomlError] {
  match parse(source) {
    Ok(table) => Ok(decoder_table_to_string(table))
    Err(error) => Err(error)
  }
}

///|
/// Encodes one already-parsed TOML value with the same deterministic tagged
/// JSON contract as `decode_tagged_json`.
pub fn encode_tagged_value(value : Value) -> String {
  decoder_value_to_string(value)
}

///|
fn decoder_table_to_string(table : Table) -> String {
  let keys = table.keys().collect()
  keys.sort_by(decoder_compare_keys)
  let fields : Array[String] = []
  for key in keys {
    match table.get(key) {
      Some(value) =>
        fields.push(json_string(key) + ":" + decoder_value_to_string(value))
      None => ()
    }
  }
  "{" + join(fields, ",") + "}"
}

///|
/// MoonBit's built-in String comparison uses shortlex order. JSON object keys
/// use ordinary code-point lexicographic order here so output is predictable.
fn decoder_compare_keys(left : String, right : String) -> Int {
  let left_chars : Array[Char] = left.iter().collect()
  let right_chars : Array[Char] = right.iter().collect()
  let common = if left_chars.length() < right_chars.length() {
    left_chars.length()
  } else {
    right_chars.length()
  }
  for i in 0..<common {
    let order = left_chars[i].compare(right_chars[i])
    if order != 0 {
      return order
    }
  }
  left_chars.length().compare(right_chars.length())
}

///|
fn decoder_value_to_string(value : Value) -> String {
  match value {
    String(s) => decoder_tagged("string", s)
    Integer(i) => decoder_tagged("integer", i.to_string())
    Float(f) => decoder_tagged("float", format_float(f))
    Boolean(b) => decoder_tagged("bool", if b { "true" } else { "false" })
    OffsetDateTime(dt) =>
      decoder_tagged(
        "datetime",
        format_date(dt.date) +
        "T" +
        format_time(dt.time) +
        format_offset(dt.offset_minutes),
      )
    LocalDateTime(dt) =>
      decoder_tagged(
        "datetime-local",
        format_date(dt.date) + "T" + format_time(dt.time),
      )
    LocalDate(date) => decoder_tagged("date-local", format_date(date))
    LocalTime(time) => decoder_tagged("time-local", format_time(time))
    Array(values) => {
      let items : Array[String] = []
      for item in values {
        items.push(decoder_value_to_string(item))
      }
      "[" + join(items, ",") + "]"
    }
    Table(nested) => decoder_table_to_string(nested)
  }
}

///|
fn decoder_tagged(kind : String, value : String) -> String {
  "{\"type\":" + json_string(kind) + ",\"value\":" + json_string(value) + "}"
}

///|
/// Delegates quoting and escaping to the repository's JSON implementation.
fn json_string(value : String) -> String {
  Json::string(value).stringify()
}
