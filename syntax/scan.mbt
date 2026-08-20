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
  let mut code_unit_offset = 0
  for c in source {
    if byte_offset == target {
      return code_unit_offset
    }
    byte_offset += utf8_width(c)
    code_unit_offset += if c.to_int() <= 0xFFFF { 1 } else { 2 }
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
fn remember_non_trivia(
  first : Char?,
  second : Char?,
  c : Char,
) -> (Char?, Char?) {
  match first {
    None => (Some(c), second)
    Some(_) =>
      match second {
        None => (first, Some(c))
        Some(_) => (first, second)
      }
  }
}

///|
fn is_triple(chars : Array[Char], index : Int, quote : Char) -> Bool {
  index + 2 < chars.length() &&
  chars[index] == quote &&
  chars[index + 1] == quote &&
  chars[index + 2] == quote
}

///|
fn quote_run_length(chars : Array[Char], index : Int, quote : Char) -> Int {
  let mut length = 0
  while index + length < chars.length() && chars[index + length] == quote {
    length += 1
  }
  length
}

///|
fn classify_statement(source : String, span : SourceSpan) -> StatementKind {
  let text = Statement::text({ kind: Trivia, span }, source)
  let chars = text.to_array()
  let mut first : Char? = None
  let mut second : Char? = None
  let mut has_equal = false
  let mut comment = false
  let mut quote = Outside
  let mut escaped = false
  for c in chars {
    match quote {
      Outside =>
        if comment {
          ()
        } else if c == '#' {
          comment = true
        } else if is_horizontal_space(c) || c == '\r' || c == '\n' {
          ()
        } else {
          let (next_first, next_second) = remember_non_trivia(first, second, c)
          first = next_first
          second = next_second
          if c == '=' {
            has_equal = true
          } else if c == '"' {
            quote = Basic(false)
          } else if c == '\'' {
            quote = Literal(false)
          }
        }
      Basic(_) =>
        if escaped {
          escaped = false
        } else if c == '\\' {
          escaped = true
        } else if c == '"' {
          quote = Outside
        }
      Literal(_) => if c == '\'' { quote = Outside }
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
  let container_stack : Array[Char] = []
  let mut comment = false
  let mut statement_invalid = false
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
      if quote == Basic(false) || quote == Literal(false) {
        statement_invalid = true
        errors.push({
          message: "newline in single-line string",
          span: make_span(offset, offset + width, line, column),
        })
        quote = Outside
        escaped = false
      } else if quote == Basic(true) && escaped {
        escaped = false
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
        let kind = add_statement(statements, source, span, statement_invalid)
        if kind == Invalid && !statement_invalid {
          errors.push({ message: "invalid statement", span })
        }
        statement_offset = offset
        statement_line = line
        statement_column = column
        statement_invalid = false
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
            container_stack.push(c)
          } else if c == ']' {
            let matches = container_stack.length() > 0 &&
              container_stack[container_stack.length() - 1] == '['
            if matches {
              container_stack.truncate(container_stack.length() - 1)
              bracket_depth -= 1
            } else {
              statement_invalid = true
              errors.push({
                message: "unmatched closing delimiter",
                span: make_span(offset, offset + utf8_width(c), line, column),
              })
            }
          } else if c == '{' {
            brace_depth += 1
            container_stack.push(c)
          } else if c == '}' {
            let matches = container_stack.length() > 0 &&
              container_stack[container_stack.length() - 1] == '{'
            if matches {
              container_stack.truncate(container_stack.length() - 1)
              brace_depth -= 1
            } else {
              statement_invalid = true
              errors.push({
                message: "unmatched closing delimiter",
                span: make_span(offset, offset + utf8_width(c), line, column),
              })
            }
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
          let length = quote_run_length(chars, index, '"')
          if length > 5 {
            statement_invalid = true
            errors.push({
              message: "too many quotes in multiline string closing delimiter",
              span: make_span(offset, offset + length - 5, line, column),
            })
          }
          quote = Outside
          offset += length
          index += length
          column += length
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
          let length = quote_run_length(chars, index, '\'')
          if length > 5 {
            statement_invalid = true
            errors.push({
              message: "too many quotes in multiline string closing delimiter",
              span: make_span(offset, offset + length - 5, line, column),
            })
          }
          quote = Outside
          offset += length
          index += length
          column += length
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
    let unterminated = quote != Outside || bracket_depth > 0 || brace_depth > 0
    let invalid = statement_invalid || unterminated
    let kind = add_statement(statements, source, span, invalid)
    if unterminated {
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
    } else if kind == Invalid && !statement_invalid {
      errors.push({ message: "invalid statement", span })
    }
  }
  let (entries, tables) = index_document(source, statements)
  { document: { source, statements, entries, tables }, errors }
}
