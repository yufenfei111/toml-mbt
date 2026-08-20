///|
/// Scanner quote modes.  A triple-quoted string is represented separately so
/// embedded newlines cannot terminate a statement.
priv enum QuoteMode {
  Outside
  Basic(Bool)
  Literal(Bool)
} derive(Eq)

///|
fn utf8_width(c : Char) -> Int {
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
fn byte_offset_to_code_unit(source : String, target : Int) -> Int {
  let mut byte_offset = 0
  for code_unit, c in source.iter2() {
    if byte_offset == target {
      return code_unit
    }
    byte_offset += utf8_width(c)
  }
  source.length()
}

///|
pub fn Statement::text(self : Statement, source : String) -> String {
  let start = byte_offset_to_code_unit(source, self.span.start_offset)
  let end = byte_offset_to_code_unit(source, self.span.end_offset)
  source[start:end].to_owned()
}

///|
fn is_horizontal_space(c : Char) -> Bool {
  c == ' ' || c == '\t'
}

///|
fn is_triple(chars : Array[Char], index : Int, quote : Char) -> Bool {
  index + 2 < chars.length() &&
  chars[index] == quote &&
  chars[index + 1] == quote &&
  chars[index + 2] == quote
}

///|
fn classify_statement(source : String, span : SourceSpan) -> StatementKind {
  let text = Statement::text({ kind: Trivia, span }, source)
  let chars = text.to_array()
  let mut first : Char? = None
  let mut second : Char? = None
  let mut has_equal = false
  let mut comment = false
  for c in chars {
    if comment {
      ()
    } else if c == '#' {
      comment = true
    } else if is_horizontal_space(c) || c == '\r' || c == '\n' {
      ()
    } else {
      match first {
        None => first = Some(c)
        Some(_) =>
          match second {
            None => second = Some(c)
            Some(_) => ()
          }
      }
      if c == '=' {
        has_equal = true
      }
    }
  }
  match first {
    None => Trivia
    Some('[') =>
      match second {
        Some('[') => ArrayTableHeader
        _ => TableHeader
      }
    Some(_) => if has_equal { KeyValue } else { Invalid }
  }
}

///|
fn make_span(
  start_offset : Int,
  end_offset : Int,
  line : Int,
  column : Int,
) -> SourceSpan {
  { start_offset, end_offset, line, column }
}

///|
fn add_statement(
  statements : Array[Statement],
  source : String,
  span : SourceSpan,
  invalid : Bool,
) -> StatementKind {
  let kind = if invalid { Invalid } else { classify_statement(source, span) }
  statements.push({ kind, span })
  kind
}

///|
/// Scans top-level TOML statement boundaries without invoking the semantic
/// parser.  Offsets are UTF-8 bytes; CRLF advances two bytes and one line.
pub fn scan(source : String) -> ScanResult {
  let chars = source.to_array()
  let statements : Array[Statement] = []
  let errors : Array[SyntaxError] = []
  let mut index = 0
  let mut offset = 0
  let mut line = 1
  let mut column = 1
  let mut statement_offset = 0
  let mut statement_line = 1
  let mut statement_column = 1
  let mut quote = Outside
  let mut escaped = false
  let mut bracket_depth = 0
  let mut brace_depth = 0
  let mut comment = false
  while index < chars.length() {
    let c = chars[index]
    if c == '\r' || c == '\n' {
      let width = if c == '\r' &&
        index + 1 < chars.length() &&
        chars[index + 1] == '\n' {
        2
      } else {
        1
      }
      let ends_statement = quote == Outside &&
        bracket_depth == 0 &&
        brace_depth == 0
      offset += width
      index += if width == 2 { 2 } else { 1 }
      line += 1
      column = 1
      comment = false
      if ends_statement {
        let span = make_span(
          statement_offset, offset, statement_line, statement_column,
        )
        let kind = add_statement(statements, source, span, false)
        if kind == Invalid {
          errors.push({ message: "invalid statement", span })
        }
        statement_offset = offset
        statement_line = line
        statement_column = column
      }
      continue
    }
    if comment {
      offset += utf8_width(c)
      index += 1
      column += 1
      continue
    }
    match quote {
      Outside =>
        if c == '"' {
          if is_triple(chars, index, '"') {
            quote = Basic(true)
            offset += 3
            index += 3
            column += 3
          } else {
            quote = Basic(false)
            offset += 1
            index += 1
            column += 1
          }
        } else if c == '\'' {
          if is_triple(chars, index, '\'') {
            quote = Literal(true)
            offset += 3
            index += 3
            column += 3
          } else {
            quote = Literal(false)
            offset += 1
            index += 1
            column += 1
          }
        } else {
          if c == '#' {
            comment = true
          } else if c == '[' {
            bracket_depth += 1
          } else if c == ']' && bracket_depth > 0 {
            bracket_depth -= 1
          } else if c == '{' {
            brace_depth += 1
          } else if c == '}' && brace_depth > 0 {
            brace_depth -= 1
          }
          offset += utf8_width(c)
          index += 1
          column += 1
        }
      Basic(multiline) =>
        if escaped {
          escaped = false
          offset += utf8_width(c)
          index += 1
          column += 1
        } else if c == '\\' {
          escaped = true
          offset += 1
          index += 1
          column += 1
        } else if multiline && is_triple(chars, index, '"') {
          quote = Outside
          offset += 3
          index += 3
          column += 3
        } else if !multiline && c == '"' {
          quote = Outside
          offset += 1
          index += 1
          column += 1
        } else {
          offset += utf8_width(c)
          index += 1
          column += 1
        }
      Literal(multiline) =>
        if multiline && is_triple(chars, index, '\'') {
          quote = Outside
          offset += 3
          index += 3
          column += 3
        } else if !multiline && c == '\'' {
          quote = Outside
          offset += 1
          index += 1
          column += 1
        } else {
          offset += utf8_width(c)
          index += 1
          column += 1
        }
    }
  }
  if statement_offset < offset {
    let span = make_span(
      statement_offset, offset, statement_line, statement_column,
    )
    let invalid = quote != Outside || bracket_depth > 0 || brace_depth > 0
    let kind = add_statement(statements, source, span, invalid)
    if invalid {
      let message = match quote {
        Outside =>
          if bracket_depth > 0 {
            "unterminated array"
          } else {
            "unterminated inline table"
          }
        Basic(_) => "unterminated string"
        Literal(_) => "unterminated string"
      }
      errors.push({ message, span })
    } else if kind == Invalid {
      errors.push({ message: "invalid statement", span })
    }
  }
  { document: { source, statements }, errors }
}
