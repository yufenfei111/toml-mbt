///|
/// A hand-written lexer for TOML source text.
///
/// It produces a flat token stream with 1-based source positions, leaving
/// semantic interpretation (numbers, dates, dotted keys) to the parser. It
/// understands the hard parts of TOML lexical structure: the four string
/// forms (basic, literal, and their multiline variants) and the line-ending
/// backslash in multiline basic strings.
struct Lexer {
  input : String
  chars : Array[Char]
  offsets : Array[Int]
  mut idx : Int
  mut line : Int
  mut column : Int
}

///|
/// Splits `input` into its characters plus their UTF-16 code-unit offsets.
/// The trailing sentinel offset is `input.length()`.
fn build_chars(input : String) -> (Array[Char], Array[Int]) {
  let chars : Array[Char] = []
  let offsets : Array[Int] = []
  for off, c in input.iter2() {
    chars.push(c)
    offsets.push(off)
  }
  offsets.push(input.length())
  (chars, offsets)
}

///|
fn Lexer::new(input : String) -> Lexer {
  let (chars, offsets) = build_chars(input)
  { input, chars, offsets, idx: 0, line: 1, column: 1 }
}

///|
fn Lexer::is_eof(self : Lexer) -> Bool {
  self.idx >= self.chars.length()
}

///|
fn Lexer::peek(self : Lexer) -> Char? {
  if self.idx >= self.chars.length() {
    None
  } else {
    Some(self.chars[self.idx])
  }
}

///|
fn Lexer::peek_at(self : Lexer, offset : Int) -> Char? {
  let i = self.idx + offset
  if i >= self.chars.length() {
    None
  } else {
    Some(self.chars[i])
  }
}

///|
fn Lexer::peek_is(self : Lexer, c : Char) -> Bool {
  self.peek() == Some(c)
}

///|
fn Lexer::peek_at_is(self : Lexer, offset : Int, c : Char) -> Bool {
  self.peek_at(offset) == Some(c)
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  self.idx += 1
  self.column += 1
}

///|
fn Lexer::advance_n(self : Lexer, n : Int) -> Unit {
  for _ in 0..<n {
    self.advance()
  }
}

///|
/// Consumes a newline (`\n` or `\r\n` or a lone `\r`) and resets the column.
fn Lexer::consume_newline(self : Lexer) -> Unit {
  if self.peek_is('\r') {
    self.idx += 1
    if self.peek_is('\n') {
      self.idx += 1
    }
  } else {
    self.idx += 1
  }
  self.line += 1
  self.column = 1
}

///|
fn Lexer::raise_here(self : Lexer, message : String) -> Unit raise TomlError {
  raise TomlError::new(self.line, self.column, message)
}

///|
/// Skips a comment (`#` to end of line, exclusive of the newline).
fn Lexer::skip_comment(self : Lexer) -> Unit {
  while true {
    match self.peek() {
      None => break
      Some('\n') => break
      Some('\r') => break
      Some(_) => self.advance()
    }
  }
}

///|
fn is_word_terminator(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '#' ||
    c == '=' || c == ',' || c == '[' || c == ']' || c == '{' ||
    c == '}' || c == '"' || c == '\''
}

///|
/// Lexes a bare word: a maximal run of characters that are not whitespace,
/// comments, string delimiters, or structural punctuation.
fn Lexer::lex_word(self : Lexer) -> String {
  let start = self.idx
  while true {
    match self.peek() {
      None => break
      Some(c) => {
        if is_word_terminator(c) {
          break
        }
        self.advance()
      }
    }
  }
  self.input.substring(start=self.offsets[start], end=self.offsets[self.idx])
}

///|
fn Lexer::is_triple(self : Lexer, c : Char) -> Bool {
  self.peek_is(c) && self.peek_at_is(1, c) && self.peek_at_is(2, c)
}

///|
/// Lexes a quoted string value. `quote` is either `"` or `'`.
fn Lexer::lex_string(self : Lexer, quote : Char) -> String raise TomlError {
  if self.is_triple(quote) {
    self.advance_n(3)
    let value = self.lex_string_body(quote, true)
    if !self.is_triple(quote) {
      self.raise_here("unterminated multiline string")
    }
    self.advance_n(3)
    value
  } else {
    self.advance()
    let value = self.lex_string_body(quote, false)
    if !self.peek_is(quote) {
      self.raise_here("unterminated string")
    }
    self.advance()
    value
  }
}

///|
/// Lexes the body of a string (between its delimiters) and returns the value.
fn Lexer::lex_string_body(
  self : Lexer,
  quote : Char,
  multiline : Bool,
) -> String raise TomlError {
  let chars : Array[Char] = []
  while true {
    match self.peek() {
      None => self.raise_here("unterminated string")
      Some(c) => {
        if !multiline && (c == '\n' || c == '\r') {
          self.raise_here("newline in single-line string")
        }
        if c == quote {
          if multiline && !self.is_triple(quote) {
            // A single or double quote inside a multiline string is literal.
            chars.push(c)
            self.advance()
          } else {
            break
          }
        } else if quote == '"' && c == '\\' {
          self.advance()
          self.lex_escape(chars, multiline)
        } else {
          chars.push(c)
          self.advance()
        }
      }
    }
  }
  String::from_iter(chars.iter())
}

///|
/// Processes a single escape sequence after a backslash has been consumed.
fn Lexer::lex_escape(
  self : Lexer,
  chars : Array[Char],
  multiline : Bool,
) -> Unit raise TomlError {
  match self.peek() {
    Some('b') => {
      chars.push((0x08).unsafe_to_char())
      self.advance()
    }
    Some('t') => {
      chars.push('\t')
      self.advance()
    }
    Some('n') => {
      chars.push('\n')
      self.advance()
    }
    Some('f') => {
      chars.push((0x0C).unsafe_to_char())
      self.advance()
    }
    Some('r') => {
      chars.push('\r')
      self.advance()
    }
    Some('"') => {
      chars.push('"')
      self.advance()
    }
    Some('\\') => {
      chars.push('\\')
      self.advance()
    }
    Some('u') => {
      self.advance()
      let cp = self.lex_hex(4)
      chars.push(cp.unsafe_to_char())
    }
    Some('U') => {
      self.advance()
      let cp = self.lex_hex(8)
      chars.push(cp.unsafe_to_char())
    }
    Some(c) if multiline && (c == ' ' || c == '\t' || c == '\n' || c == '\r') => {
      // Line-ending backslash: trim whitespace up to the next non-whitespace.
      while self.peek_is(' ') || self.peek_is('\t') {
        self.advance()
      }
      match self.peek() {
        Some('\n') => self.consume_newline()
        Some('\r') => self.consume_newline()
        _ => self.raise_here("invalid escape sequence")
      }
      self.trim_line_whitespace()
    }
    _ => self.raise_here("invalid escape sequence")
  }
}

///|
/// Skips spaces, tabs, and newlines (used by the multiline line-ending rule).
fn Lexer::trim_line_whitespace(self : Lexer) -> Unit {
  while true {
    match self.peek() {
      Some(' ') => self.advance()
      Some('\t') => self.advance()
      Some('\n') => self.consume_newline()
      Some('\r') => self.consume_newline()
      _ => break
    }
  }
}

///|
fn hex_value(c : Char) -> Int {
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
/// Reads `n` hexadecimal digits and returns their value as a Unicode code
/// point, validating that it is a legal scalar value.
fn Lexer::lex_hex(self : Lexer, n : Int) -> Int raise TomlError {
  let mut value = 0
  for _ in 0..<n {
    match self.peek() {
      Some(c) => {
        let d = hex_value(c)
        if d < 0 {
          self.raise_here("invalid unicode escape")
        }
        value = value * 16 + d
        self.advance()
      }
      None => self.raise_here("invalid unicode escape")
    }
  }
  if value > 0x10FFFF || (value >= 0xD800 && value <= 0xDFFF) {
    self.raise_here("invalid unicode scalar value")
  }
  value
}

///|
/// Tokenizes `input` into a token stream, or raises `TomlError` on lexical
/// errors such as an unterminated string or an invalid escape.
pub fn Lexer::tokenize(input : String) -> Array[Token] raise TomlError {
  let lexer = Lexer::new(input)
  let tokens : Array[Token] = []
  while !lexer.is_eof() {
    // Skip spaces, tabs, and comments (newlines are significant tokens).
    while true {
      match lexer.peek() {
        Some(' ') => lexer.advance()
        Some('\t') => lexer.advance()
        Some('#') => lexer.skip_comment()
        _ => break
      }
    }
    if lexer.is_eof() {
      break
    }
    let line = lexer.line
    let column = lexer.column
    match lexer.peek() {
      Some('\n') => {
        lexer.consume_newline()
        tokens.push(Token::new(Newline, line, column))
      }
      Some('\r') => {
        lexer.consume_newline()
        tokens.push(Token::new(Newline, line, column))
      }
      Some('=') => {
        lexer.advance()
        tokens.push(Token::new(Equal, line, column))
      }
      Some(',') => {
        lexer.advance()
        tokens.push(Token::new(Comma, line, column))
      }
      Some('[') => {
        lexer.advance()
        tokens.push(Token::new(LBracket, line, column))
      }
      Some(']') => {
        lexer.advance()
        tokens.push(Token::new(RBracket, line, column))
      }
      Some('{') => {
        lexer.advance()
        tokens.push(Token::new(LBrace, line, column))
      }
      Some('}') => {
        lexer.advance()
        tokens.push(Token::new(RBrace, line, column))
      }
      Some('"') => {
        let s = lexer.lex_string('"')
        tokens.push(Token::new(Str(s), line, column))
      }
      Some('\'') => {
        let s = lexer.lex_string('\'')
        tokens.push(Token::new(Str(s), line, column))
      }
      Some(_) => {
        let w = lexer.lex_word()
        tokens.push(Token::new(Word(w), line, column))
      }
      None => break
    }
  }
  tokens.push(Token::new(EOF, lexer.line, lexer.column))
  tokens
}
