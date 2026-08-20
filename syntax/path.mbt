///|
fn path_utf8_width(c : Char) -> Int {
  let code = c.to_int()
  if code <= 0x7F {
    1
  } else if code <= 0x7FF {
    2
  } else if code <= 0xFFFF {
    3
  } else {
    4
  }
}

///|
fn is_path_space(c : Char) -> Bool {
  c == ' ' || c == '\t'
}

///|
fn path_error(
  _text : String,
  chars : Array[Char],
  at : Int,
  message : String,
) -> SyntaxError {
  let mut offset = 0
  for index in 0..<at {
    offset += path_utf8_width(chars[index])
  }
  let end_offset = if at < chars.length() {
    offset + path_utf8_width(chars[at])
  } else {
    offset
  }
  {
    message,
    span: { start_offset: offset, end_offset, line: 1, column: at + 1 },
  }
}

///|
fn is_bare_key_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  c == '-'
}

///|
fn path_hex_value(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 'A'.to_int() + 10
  } else {
    -1
  }
}

///|
fn read_basic_key(
  text : String,
  chars : Array[Char],
  start : Int,
) -> Result[(String, Int), SyntaxError] {
  let out : Array[Char] = []
  let mut index = start + 1
  while index < chars.length() {
    let c = chars[index]
    if c == '"' {
      return Ok((String::from_iter(out.iter()), index + 1))
    }
    if c == '\\' {
      if index + 1 >= chars.length() {
        return Err(path_error(text, chars, index, "unterminated basic key"))
      }
      let escape = chars[index + 1]
      match escape {
        'b' => out.push((0x08).unsafe_to_char())
        't' => out.push('\t')
        'n' => out.push('\n')
        'f' => out.push((0x0C).unsafe_to_char())
        'r' => out.push('\r')
        '"' => out.push('"')
        '\\' => out.push('\\')
        'u' | 'U' => {
          let digits = if escape == 'u' { 4 } else { 8 }
          if index + 2 + digits > chars.length() {
            return Err(path_error(text, chars, index, "invalid unicode escape"))
          }
          let mut value = 0
          for position in (index + 2)..<(index + 2 + digits) {
            let digit = path_hex_value(chars[position])
            if digit < 0 {
              return Err(
                path_error(text, chars, position, "invalid unicode escape"),
              )
            }
            value = value * 16 + digit
          }
          if value > 0x10FFFF || (value >= 0xD800 && value <= 0xDFFF) {
            return Err(
              path_error(text, chars, index, "invalid unicode scalar value"),
            )
          }
          out.push(value.unsafe_to_char())
          index += digits
        }
        _ =>
          return Err(
            path_error(text, chars, index + 1, "invalid basic key escape"),
          )
      }
      index += 2
    } else if c == '\n' || c == '\r' {
      return Err(path_error(text, chars, index, "newline in basic key"))
    } else {
      out.push(c)
      index += 1
    }
  }
  Err(path_error(text, chars, start, "unterminated basic key"))
}

///|
fn read_literal_key(
  text : String,
  chars : Array[Char],
  start : Int,
) -> Result[(String, Int), SyntaxError] {
  let out : Array[Char] = []
  let mut index = start + 1
  while index < chars.length() {
    let c = chars[index]
    if c == '\'' {
      return Ok((String::from_iter(out.iter()), index + 1))
    }
    if c == '\n' || c == '\r' {
      return Err(path_error(text, chars, index, "newline in literal key"))
    }
    out.push(c)
    index += 1
  }
  Err(path_error(text, chars, start, "unterminated literal key"))
}

///|
/// Parses a TOML dotted key into decoded segments. Basic quoted keys decode
/// TOML escapes; literal quoted keys keep their contents verbatim.
pub fn parse_key_path(text : String) -> Result[Array[String], SyntaxError] {
  let chars = text.to_array()
  let path : Array[String] = []
  let mut index = 0
  while index < chars.length() && is_path_space(chars[index]) {
    index += 1
  }
  while index < chars.length() {
    let mut segment = ""
    match chars[index] {
      '"' =>
        match read_basic_key(text, chars, index) {
          Ok((value, next)) => {
            segment = value
            index = next
          }
          Err(error) => return Err(error)
        }
      '\'' =>
        match read_literal_key(text, chars, index) {
          Ok((value, next)) => {
            segment = value
            index = next
          }
          Err(error) => return Err(error)
        }
      c if is_bare_key_char(c) => {
        let start = index
        while index < chars.length() && is_bare_key_char(chars[index]) {
          index += 1
        }
        segment = String::from_iter(chars[start:index].iter())
      }
      _ => return Err(path_error(text, chars, index, "invalid key segment"))
    }
    path.push(segment)
    while index < chars.length() && is_path_space(chars[index]) {
      index += 1
    }
    if index == chars.length() {
      return Ok(path)
    }
    if chars[index] != '.' {
      return Err(
        path_error(text, chars, index, "expected dot between key segments"),
      )
    }
    index += 1
    while index < chars.length() && is_path_space(chars[index]) {
      index += 1
    }
    if index == chars.length() {
      return Err(
        path_error(text, chars, index, "expected key segment after dot"),
      )
    }
  }
  Err(path_error(text, chars, index, "expected key segment"))
}

///|
fn source_span_at(
  source : String,
  start_offset : Int,
  end_offset : Int,
) -> SourceSpan {
  let mut offset = 0
  let mut line = 1
  let mut column = 1
  let chars = source.to_array()
  let mut index = 0
  while index < chars.length() && offset < start_offset {
    let c = chars[index]
    if c == '\r' && index + 1 < chars.length() && chars[index + 1] == '\n' {
      offset += 2
      index += 2
      line += 1
      column = 1
    } else {
      offset += path_utf8_width(c)
      index += 1
      if c == '\r' || c == '\n' {
        line += 1
        column = 1
      } else {
        column += 1
      }
    }
  }
  { start_offset, end_offset, line, column }
}

///|
fn path_has_prefix(path : Array[String], prefix : Array[String]) -> Bool {
  if prefix.length() > path.length() {
    return false
  }
  for index in 0..<prefix.length() {
    if path[index] != prefix[index] {
      return false
    }
  }
  true
}

///|
fn array_context(
  path : Array[String],
  array_tables : Array[Array[String]],
) -> Bool {
  for array_path in array_tables {
    if path_has_prefix(path, array_path) {
      return true
    }
  }
  false
}

///|
fn first_unquoted_equal(chars : Array[Char]) -> Int? {
  let mut index = 0
  let mut quote : Char? = None
  let mut escaped = false
  while index < chars.length() {
    let c = chars[index]
    match quote {
      Some('"') =>
        if escaped {
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if c == '"' {
          quote = None
        }
      Some('\'') => if c == '\'' { quote = None }
      Some(_) => ()
      None =>
        if c == '"' || c == '\'' {
          quote = Some(c)
        } else if c == '=' {
          return Some(index)
        }
    }
    index += 1
  }
  None
}

///|
fn trim_statement_end(chars : Array[Char], end : Int) -> Int {
  let mut result = end
  while result > 0 {
    let c = chars[result - 1]
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      result -= 1
    } else {
      break
    }
  }
  result
}

///|
priv enum ValueQuote {
  OutsideValue
  BasicValue(Bool)
  LiteralValue(Bool)
}

///|
fn has_triple(chars : Array[Char], index : Int, quote : Char) -> Bool {
  index + 2 < chars.length() &&
  chars[index] == quote &&
  chars[index + 1] == quote &&
  chars[index + 2] == quote
}

///|
fn quote_run(chars : Array[Char], index : Int, quote : Char) -> Int {
  let mut length = 0
  while index + length < chars.length() && chars[index + length] == quote {
    length += 1
  }
  length
}

///|
fn value_end(chars : Array[Char], start : Int) -> Int {
  let mut index = start
  let mut quote = OutsideValue
  let mut escaped = false
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while index < chars.length() {
    let c = chars[index]
    match quote {
      BasicValue(multiline) =>
        if escaped {
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if multiline && has_triple(chars, index, '"') {
          quote = OutsideValue
          index += quote_run(chars, index, '"')
          continue
        } else if !multiline && c == '"' {
          quote = OutsideValue
        }
      LiteralValue(multiline) =>
        if multiline && has_triple(chars, index, '\'') {
          quote = OutsideValue
          index += quote_run(chars, index, '\'')
          continue
        } else if !multiline && c == '\'' {
          quote = OutsideValue
        }
      OutsideValue =>
        if c == '"' {
          quote = BasicValue(has_triple(chars, index, '"'))
          index += if has_triple(chars, index, '"') { 3 } else { 1 }
          continue
        } else if c == '\'' {
          quote = LiteralValue(has_triple(chars, index, '\''))
          index += if has_triple(chars, index, '\'') { 3 } else { 1 }
          continue
        } else if c == '[' {
          bracket_depth += 1
        } else if c == ']' && bracket_depth > 0 {
          bracket_depth -= 1
        } else if c == '{' {
          brace_depth += 1
        } else if c == '}' && brace_depth > 0 {
          brace_depth -= 1
        } else if c == '#' && bracket_depth == 0 && brace_depth == 0 {
          return trim_statement_end(chars, index)
        }
    }
    index += 1
  }
  trim_statement_end(chars, chars.length())
}

///|
fn header_path(
  statement : Statement,
  source : String,
  array : Bool,
) -> Array[String]? {
  let text = statement.text(source)
  let chars = text.to_array()
  let mut index = 0
  while index < chars.length() && is_path_space(chars[index]) {
    index += 1
  }
  let open = if array { 2 } else { 1 }
  if index + open > chars.length() {
    return None
  }
  index += open
  let start = index
  let mut quote : Char? = None
  let mut escaped = false
  while index < chars.length() {
    let c = chars[index]
    match quote {
      Some('"') =>
        if escaped {
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if c == '"' {
          quote = None
        }
      Some('\'') => if c == '\'' { quote = None }
      Some(_) => ()
      None =>
        if c == '"' || c == '\'' {
          quote = Some(c)
        } else if c == ']' {
          let close_matches = !array ||
            (index + 1 < chars.length() && chars[index + 1] == ']')
          if close_matches {
            match parse_key_path(String::from_iter(chars[start:index].iter())) {
              Ok(path) => return Some(path)
              Err(_) => return None
            }
          }
        }
    }
    index += 1
  }
  None
}

///|
fn index_key_value(
  source : String,
  statement : Statement,
  table_path : Array[String],
  table_span : SourceSpan?,
  editable : Bool,
  entries : Array[KeyValueEntry],
) -> Unit {
  let text = statement.text(source)
  let chars = text.to_array()
  match first_unquoted_equal(chars) {
    None => ()
    Some(equal) => {
      let mut key_start = 0
      while key_start < equal && is_path_space(chars[key_start]) {
        key_start += 1
      }
      let mut key_end = equal
      while key_end > key_start && is_path_space(chars[key_end - 1]) {
        key_end -= 1
      }
      match parse_key_path(String::from_iter(chars[key_start:key_end].iter())) {
        Err(_) => ()
        Ok(relative_path) => {
          let mut value_start = equal + 1
          while value_start < chars.length() &&
                is_path_space(chars[value_start]) {
            value_start += 1
          }
          let value_end = value_end(chars, value_start)
          let path = table_path.copy()
          path.append(relative_path)
          let key_span = source_span_at(
            source,
            statement.span.start_offset + byte_length(chars, 0, key_start),
            statement.span.start_offset + byte_length(chars, 0, key_end),
          )
          let value_span = source_span_at(
            source,
            statement.span.start_offset + byte_length(chars, 0, value_start),
            statement.span.start_offset + byte_length(chars, 0, value_end),
          )
          entries.push({
            path,
            key_span,
            value_span,
            line_span: statement.span,
            table_span,
            editable,
          })
        }
      }
    }
  }
}

///|
fn byte_length(chars : Array[Char], start : Int, end : Int) -> Int {
  let mut length = 0
  for index in start..<end {
    length += path_utf8_width(chars[index])
  }
  length
}

///|
fn index_entries(
  source : String,
  statements : Array[Statement],
) -> Array[KeyValueEntry] {
  let entries : Array[KeyValueEntry] = []
  let array_tables : Array[Array[String]] = []
  let mut table_path : Array[String] = []
  let mut table_span : SourceSpan? = None
  let mut editable = true
  for statement in statements {
    match statement.kind {
      KeyValue =>
        index_key_value(
          source, statement, table_path, table_span, editable, entries,
        )
      TableHeader =>
        match header_path(statement, source, false) {
          Some(path) => {
            editable = !array_context(path, array_tables)
            table_path = path
            table_span = Some(statement.span)
          }
          None => ()
        }
      ArrayTableHeader =>
        match header_path(statement, source, true) {
          Some(path) => {
            array_tables.push(path.copy())
            table_path = path
            table_span = Some(statement.span)
            editable = false
          }
          None => ()
        }
      Trivia | Invalid => ()
    }
  }
  entries
}

///|
pub fn Document::find_entries(
  self : Document,
  path : Array[String],
) -> Array[KeyValueEntry] {
  let matches : Array[KeyValueEntry] = []
  for entry in self.entries {
    if entry.path == path {
      matches.push(entry)
    }
  }
  matches
}

///|
pub fn Document::find_entry(
  self : Document,
  path : Array[String],
) -> KeyValueEntry? {
  let entries = self.find_entries(path)
  if entries.length() == 1 {
    Some(entries[0])
  } else {
    None
  }
}
