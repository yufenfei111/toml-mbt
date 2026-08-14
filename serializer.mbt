///|
/// Serializes a `Table` back into TOML source text.
///
/// The output preserves insertion order, quotes keys that are not valid bare
/// keys, and emits nested tables as `[table]` headers and arrays of tables as
/// `[[table]]` headers. Round-tripping `parse` -> `serialize` -> `parse`
/// preserves the value structure.

///|
/// Serializes a table into TOML text.
pub fn serialize(table : Table) -> String {
  let lines : Array[String] = []
  write_table(table, "", lines)
  join_lines(lines)
}

///|
fn join_lines(lines : Array[String]) -> String {
  join(lines, "\n")
}

///|
fn join(strings : Array[String], sep : String) -> String {
  let mut result = ""
  let mut first = true
  for s in strings {
    if !first {
      result = result + sep
    }
    result = result + s
    first = false
  }
  result
}

///|
/// Writes the contents of `table` as key-value lines plus nested-table
/// headers, using `prefix` as the dotted key path to this table.
fn write_table(table : Table, prefix : String, out : Array[String]) -> Unit {
  for key, value in table {
    let qkey = serialize_key_segment(key)
    let child = if prefix == "" { qkey } else { prefix + "." + qkey }
    match value {
      Table(t) => {
        out.push("")
        out.push("[" + child + "]")
        write_table(t, child, out)
      }
      Array(arr) if all_tables(arr) => {
        for elem in arr {
          match elem {
            Table(t) => {
              out.push("")
              out.push("[[" + child + "]]")
              write_table(t, child, out)
            }
            _ => out.push(child + " = " + serialize_value(elem))
          }
        }
      }
      _ => out.push(child + " = " + serialize_value(value))
    }
  }
}

///|
fn all_tables(arr : Array[Value]) -> Bool {
  if arr.length() == 0 {
    return false
  }
  for v in arr {
    match v {
      Table(_) => continue
      _ => return false
    }
  }
  true
}

///|
/// Serializes a single value to TOML source.
fn serialize_value(value : Value) -> String {
  match value {
    String(s) => "\"" + escape_basic_string(s) + "\""
    Integer(i) => i.to_string()
    Float(f) => format_float(f)
    Boolean(b) => if b { "true" } else { "false" }
    OffsetDateTime(dt) =>
      format_date(dt.date) + "T" + format_time(dt.time) + format_offset(dt.offset_minutes)
    LocalDateTime(dt) => format_date(dt.date) + "T" + format_time(dt.time)
    LocalDate(d) => format_date(d)
    LocalTime(t) => format_time(t)
    Array(arr) => "[" + join(arr.map(serialize_value), ", ") + "]"
    Table(t) => "{ " + serialize_inline(t) + " }"
  }
}

///|
fn serialize_inline(table : Table) -> String {
  let parts : Array[String] = []
  for key, value in table {
    parts.push(serialize_key_segment(key) + " = " + serialize_value(value))
  }
  join(parts, ", ")
}

///|
/// Quotes a key if it is not a valid bare key.
fn serialize_key_segment(key : String) -> String {
  if is_bare_key(key) {
    key
  } else {
    "\"" + escape_basic_string(key) + "\""
  }
}

///|
fn is_bare_key(key : String) -> Bool {
  if key.length() == 0 {
    return false
  }
  for c in key.iter() {
    if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' ||
      c == '_' || c == '-') {
      return false
    }
  }
  true
}

///|
fn escape_basic_string(s : String) -> String {
  let chars : Array[Char] = []
  for c in s.iter() {
    match c {
      '"' => {
        chars.push('\\')
        chars.push('"')
      }
      '\\' => {
        chars.push('\\')
        chars.push('\\')
      }
      '\n' => {
        chars.push('\\')
        chars.push('n')
      }
      '\r' => {
        chars.push('\\')
        chars.push('r')
      }
      '\t' => {
        chars.push('\\')
        chars.push('t')
      }
      c if c.to_int() < 0x20 => {
        chars.push('\\')
        chars.push('u')
        for ch in u_escape(c.to_int()).iter() {
          chars.push(ch)
        }
      }
      _ => chars.push(c)
    }
  }
  String::from_iter(chars.iter())
}

///|
/// Formats a code point as four lowercase hex digits (for `\uXXXX`).
fn u_escape(code : Int) -> String {
  let digits = "0123456789abcdef"
  let d0 = (code >> 12) & 0xF
  let d1 = (code >> 8) & 0xF
  let d2 = (code >> 4) & 0xF
  let d3 = code & 0xF
  digits.substring(start=d0, end=d0 + 1) +
    digits.substring(start=d1, end=d1 + 1) +
    digits.substring(start=d2, end=d2 + 1) +
    digits.substring(start=d3, end=d3 + 1)
}

///|
fn format_float(f : Double) -> String {
  if f.is_inf() {
    if f > 0.0 {
      "inf"
    } else {
      "-inf"
    }
  } else if f.is_nan() {
    "nan"
  } else {
    let s = f.to_string()
    if s.contains(".") || s.contains("e") || s.contains("E") {
      s
    } else {
      s + ".0"
    }
  }
}

///|
fn pad(n : Int, width : Int) -> String {
  let s = n.to_string()
  let mut result = s
  while result.length() < width {
    result = "0" + result
  }
  result
}

///|
fn format_date(d : LocalDate) -> String {
  pad(d.year, 4) + "-" + pad(d.month, 2) + "-" + pad(d.day, 2)
}

///|
fn format_time(t : LocalTime) -> String {
  let base = pad(t.hour, 2) + ":" + pad(t.minute, 2) + ":" + pad(t.second, 2)
  if t.nanosecond == 0 {
    base
  } else {
    base + "." + format_frac(t.nanosecond)
  }
}

///|
fn format_frac(nanos : Int) -> String {
  let s = pad(nanos, 9)
  let mut i = s.length()
  while i > 1 && s.substring(start=i - 1, end=i) == "0" {
    i -= 1
  }
  s.substring(start=0, end=i)
}

///|
fn format_offset(minutes : Int) -> String {
  if minutes == 0 {
    "Z"
  } else {
    let sign = if minutes < 0 { "-" } else { "+" }
    let abs = if minutes < 0 { -minutes } else { minutes }
    sign + pad(abs / 60, 2) + ":" + pad(abs % 60, 2)
  }
}
