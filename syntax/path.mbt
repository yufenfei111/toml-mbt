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
          let mut value : Int64 = 0L
          for position in (index + 2)..<(index + 2 + digits) {
            let digit = path_hex_value(chars[position])
            if digit < 0 {
              return Err(
                path_error(text, chars, position, "invalid unicode escape"),
              )
            }
            value = value * 16L + digit.to_int64()
          }
          if value > 0x10FFFFL || (value >= 0xD800L && value <= 0xDFFFL) {
            return Err(
              path_error(text, chars, index, "invalid unicode scalar value"),
            )
          }
          out.push(value.to_int().unsafe_to_char())
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
    } else if is_forbidden_raw_key_control(c) {
      return Err(
        path_error(
          text, chars, index, "unescaped control character in basic key",
        ),
      )
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
    if is_forbidden_raw_key_control(c) {
      return Err(
        path_error(
          text, chars, index, "unescaped control character in literal key",
        ),
      )
    }
    out.push(c)
    index += 1
  }
  Err(path_error(text, chars, start, "unterminated literal key"))
}

///|
fn is_forbidden_raw_key_control(c : Char) -> Bool {
  let code = c.to_int()
  code < 0x09 || (code >= 0x0B && code <= 0x1F) || code == 0x7F
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
/// Maps a 1-based source line and character column to the UTF-8 byte span of
/// that character. Positions beyond the source are clamped to an empty EOF
/// span, so callers can safely locate parser errors without constructing a
/// `SourceSpan` themselves.
pub fn source_span_at_position(
  source : String,
  requested_line : Int,
  requested_column : Int,
) -> SourceSpan {
  let target_line = if requested_line < 1 { 1 } else { requested_line }
  let target_column = if requested_column < 1 { 1 } else { requested_column }
  let chars = source.to_array()
  let mut offset = 0
  let mut line = 1
  let mut column = 1
  let mut index = 0
  while index < chars.length() {
    let character = chars[index]
    if line == target_line && column >= target_column {
      let end_offset = if character == '\r' &&
        index + 1 < chars.length() &&
        chars[index + 1] == '\n' {
        offset + 2
      } else {
        offset + path_utf8_width(character)
      }
      return { start_offset: offset, end_offset, line, column }
    }
    if line == target_line &&
      column < target_column &&
      (character == '\r' || character == '\n') {
      return { start_offset: offset, end_offset: offset, line, column }
    }
    if character == '\r' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '\n' {
      offset += 2
      index += 2
      line += 1
      column = 1
    } else {
      offset += path_utf8_width(character)
      index += 1
      if character == '\r' || character == '\n' {
        line += 1
        column = 1
      } else {
        column += 1
      }
    }
  }
  { start_offset: offset, end_offset: offset, line, column }
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
priv enum StatementQuote {
  OutsideStatement
  BasicStatement(Bool)
  LiteralStatement(Bool)
}

///|
/// Finds a marker outside quoted values and containers. Comments are skipped
/// through their newline at every nesting depth, so comment contents never
/// influence quote or delimiter state.
fn find_top_level_marker(
  chars : Array[Char],
  start : Int,
  marker : Char,
) -> Int? {
  let mut index = 0
  let mut quote = OutsideStatement
  let mut escaped = false
  let mut bracket_depth = 0
  let mut brace_depth = 0
  let mut comment = false
  index = start
  while index < chars.length() {
    let c = chars[index]
    if comment {
      if c == '\n' || c == '\r' {
        comment = false
      }
      index += 1
      continue
    }
    match quote {
      BasicStatement(multiline) =>
        if escaped {
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if multiline && has_triple(chars, index, '"') {
          quote = OutsideStatement
          index += quote_run(chars, index, '"')
          continue
        } else if !multiline && c == '"' {
          quote = OutsideStatement
        }
      LiteralStatement(multiline) =>
        if multiline && has_triple(chars, index, '\'') {
          quote = OutsideStatement
          index += quote_run(chars, index, '\'')
          continue
        } else if !multiline && c == '\'' {
          quote = OutsideStatement
        }
      OutsideStatement =>
        if c == '#' {
          if marker == '#' && bracket_depth == 0 && brace_depth == 0 {
            return Some(index)
          }
          comment = true
        } else if c == marker && bracket_depth == 0 && brace_depth == 0 {
          return Some(index)
        } else if c == '"' {
          quote = BasicStatement(has_triple(chars, index, '"'))
          index += if has_triple(chars, index, '"') { 3 } else { 1 }
          continue
        } else if c == '\'' {
          quote = LiteralStatement(has_triple(chars, index, '\''))
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
  match find_top_level_marker(chars, start, '#') {
    Some(index) => trim_statement_end(chars, index)
    None => trim_statement_end(chars, chars.length())
  }
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
  if index + open > chars.length() || chars[index] != '[' {
    return None
  }
  if array && chars[index + 1] != '[' {
    return None
  }
  if !array && index + 1 < chars.length() && chars[index + 1] == '[' {
    return None
  }
  index += open
  let start = index
  match find_top_level_marker(chars, start, ']') {
    None => None
    Some(close) => {
      let end = if array {
        if close + 1 >= chars.length() || chars[close + 1] != ']' {
          return None
        }
        close + 2
      } else {
        close + 1
      }
      if !valid_header_tail(chars, end) {
        return None
      }
      match parse_key_path(String::from_iter(chars[start:close].iter())) {
        Ok(path) => Some(path)
        Err(_) => None
      }
    }
  }
}

///|
fn valid_header_tail(chars : Array[Char], start : Int) -> Bool {
  let mut index = start
  while index < chars.length() && is_path_space(chars[index]) {
    index += 1
  }
  if index == chars.length() || chars[index] == '#' {
    return true
  }
  chars[index] == '\r' || chars[index] == '\n'
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
  match find_top_level_marker(chars, 0, '=') {
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
fn table_block_end(
  source : String,
  statements : Array[Statement],
  header_index : Int,
) -> Int {
  let mut index = header_index + 1
  while index < statements.length() {
    match statements[index].kind {
      TableHeader | ArrayTableHeader =>
        return statements[index].span.start_offset
      _ => index += 1
    }
  }
  let chars = source.to_array()
  byte_length(chars, 0, chars.length())
}

///|
fn index_document(
  source : String,
  statements : Array[Statement],
) -> (Array[KeyValueEntry], Array[TableBlock]) {
  let entries : Array[KeyValueEntry] = []
  let tables : Array[TableBlock] = []
  let array_tables : Array[Array[String]] = []
  let mut table_path : Array[String] = []
  let mut table_span : SourceSpan? = None
  let mut editable = true
  let mut context_known = true
  let mut statement_index = 0
  while statement_index < statements.length() {
    let statement = statements[statement_index]
    match statement.kind {
      KeyValue =>
        if context_known {
          index_key_value(
            source, statement, table_path, table_span, editable, entries,
          )
        }
      TableHeader =>
        match header_path(statement, source, false) {
          Some(path) => {
            editable = !array_context(path, array_tables)
            table_path = path
            table_span = Some(statement.span)
            context_known = true
            tables.push({
              path: path.copy(),
              header_span: statement.span,
              end_offset: table_block_end(source, statements, statement_index),
              array: false,
              editable,
            })
          }
          None => {
            table_path = []
            table_span = None
            editable = false
            context_known = false
          }
        }
      ArrayTableHeader =>
        match header_path(statement, source, true) {
          Some(path) => {
            array_tables.push(path.copy())
            table_path = path
            table_span = Some(statement.span)
            editable = false
            context_known = true
            tables.push({
              path: path.copy(),
              header_span: statement.span,
              end_offset: table_block_end(source, statements, statement_index),
              array: true,
              editable: false,
            })
          }
          None => {
            table_path = []
            table_span = None
            editable = false
            context_known = false
          }
        }
      Trivia | Invalid => ()
    }
    statement_index += 1
  }
  (entries, tables)
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

///|
/// Returns every explicit table block whose decoded header path is `path`.
pub fn Document::find_table_blocks(
  self : Document,
  path : Array[String],
) -> Array[TableBlock] {
  let matches : Array[TableBlock] = []
  for table in self.tables {
    if table.path == path {
      matches.push(table)
    }
  }
  matches
}
