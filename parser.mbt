///|
/// A recursive-descent parser that turns a token stream into a `Table`.
///
/// It owns the hard semantic work the lexer deliberately leaves open:
/// interpreting bare words as booleans, integers, floats, or date-times by
/// context, resolving dotted keys, and navigating `[table]` and
/// `[[array-of-tables]]` headers.

///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
  root : Table
  mut current : Table
}

///|
fn Parser::new(tokens : Array[Token]) -> Parser {
  let root : Table = Map([])
  { tokens, pos: 0, root, current: root }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.pos]
}

///|
fn Parser::peek_at(self : Parser, offset : Int) -> Token {
  let i = self.pos + offset
  if i >= self.tokens.length() {
    self.tokens[self.tokens.length() - 1]
  } else {
    self.tokens[i]
  }
}

///|
fn Parser::peek_kind(self : Parser) -> TokenKind {
  self.peek().kind
}

///|
fn Parser::at_end(self : Parser) -> Bool {
  self.peek_kind() == EOF
}

///|
fn Parser::advance(self : Parser) -> Unit {
  if self.pos < self.tokens.length() - 1 {
    self.pos += 1
  }
}

///|
fn Parser::expect(self : Parser, kind : TokenKind) -> Unit raise TomlError {
  if self.peek_kind() == kind {
    self.advance()
  } else {
    self.raise_err("unexpected token")
  }
}

///|
fn[T] Parser::raise_err(self : Parser, message : String) -> T raise TomlError {
  let t = self.peek()
  raise TomlError::new(t.line, t.column, message)
}

///|
fn Parser::skip_newlines(self : Parser) -> Unit {
  while self.peek_kind() == Newline {
    self.advance()
  }
}

///|
fn Parser::expect_newline_or_eof(self : Parser) -> Unit raise TomlError {
  match self.peek_kind() {
    Newline => self.advance()
    EOF => ()
    _ => self.raise_err("expected a newline")
  }
}

///|
/// Splits a bare-key word on `.`, keeping empty segments so that leading and
/// trailing dots can be detected by the caller.
fn split_dotted(w : String) -> Array[String] {
  let parts : Array[String] = []
  let mut current : Array[Char] = []
  for c in w.iter() {
    if c == '.' {
      parts.push(String::from_iter(current.iter()))
      current = []
    } else {
      current.push(c)
    }
  }
  parts.push(String::from_iter(current.iter()))
  parts
}

///|
/// Reads a (possibly dotted) key and returns its parts. A key part is either
/// a bare word segment or a quoted string.
fn is_toml10_bare_key_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_' ||
  ch == '-'
}

///|
fn Parser::parse_key(self : Parser) -> Array[String] raise TomlError {
  let parts : Array[String] = []
  let mut expect_more = false
  while true {
    match self.peek_kind() {
      Word(w) => {
        for ch in w.iter() {
          if ch != '.' && !is_toml10_bare_key_char(ch) {
            self.raise_err("invalid bare key character")
          }
        }
        self.advance()
        let segs = split_dotted(w)
        let n = segs.length()
        if segs[0] == "" && parts.length() == 0 {
          self.raise_err("a key cannot start with a dot")
        }
        for i in 1..<(n - 1) {
          if segs[i] == "" {
            self.raise_err("empty key segment")
          }
        }
        for seg in segs {
          if seg != "" {
            parts.push(seg)
          }
        }
        expect_more = segs[n - 1] == ""
        if !expect_more {
          break
        }
      }
      Str(s) => {
        parts.push(s)
        self.advance()
        expect_more = false
        match self.peek_kind() {
          Word(w2) if w2.has_prefix(".") => continue
          _ => break
        }
      }
      _ => break
    }
  }
  if parts.length() == 0 {
    self.raise_err("expected a key")
  }
  if expect_more {
    self.raise_err("a key cannot end with a dot")
  }
  parts
}

///|
/// Inserts `value` at a dotted `path`, creating intermediate tables. Fails on
/// duplicate keys or when a path component is not a table.
fn insert_dotted(
  table : Table,
  path : Array[String],
  value : Value,
) -> Result[Unit, String] {
  let n = path.length()
  if n == 0 {
    return Err("empty key")
  }
  let mut cur = table
  for i in 0..<(n - 1) {
    let key = path[i]
    match cur.get(key) {
      None => {
        let m : Map[String, Value] = Map([])
        cur.set(key, Table(m))
        cur = m
      }
      Some(Table(m)) => cur = m
      Some(_) => return Err("cannot extend a non-table value")
    }
  }
  let last = path[n - 1]
  if cur.contains(last) {
    return Err("duplicate key")
  }
  cur.set(last, value)
  Ok(())
}

///|
fn Parser::set_dotted(
  self : Parser,
  table : Table,
  path : Array[String],
  value : Value,
) -> Unit raise TomlError {
  match insert_dotted(table, path, value) {
    Ok(_) => ()
    Err(msg) => self.raise_err(msg)
  }
}

///|
/// Defines a table at `path` (for a `[table]` header) and returns its map.
fn define_table(
  root : Table,
  path : Array[String],
) -> Result[Map[String, Value], String] {
  let mut cur = root
  for i in 0..<(path.length() - 1) {
    let key = path[i]
    match cur.get(key) {
      None => {
        let m : Map[String, Value] = Map([])
        cur.set(key, Table(m))
        cur = m
      }
      Some(Table(m)) => cur = m
      Some(_) => return Err("key is not a table")
    }
  }
  let last = path[path.length() - 1]
  if cur.contains(last) {
    return Err("table is already defined")
  }
  let m : Map[String, Value] = Map([])
  cur.set(last, Table(m))
  Ok(m)
}

///|
/// Appends a fresh table to an array-of-tables at `path` and returns its map.
fn append_array_table(
  root : Table,
  path : Array[String],
) -> Result[Map[String, Value], String] {
  let mut cur = root
  for i in 0..<(path.length() - 1) {
    let key = path[i]
    match cur.get(key) {
      None => {
        let m : Map[String, Value] = Map([])
        cur.set(key, Table(m))
        cur = m
      }
      Some(Table(m)) => cur = m
      Some(_) => return Err("key is not a table")
    }
  }
  let last = path[path.length() - 1]
  let m : Map[String, Value] = Map([])
  match cur.get(last) {
    None => cur.set(last, Array([Table(m)]))
    Some(Array(arr)) => arr.push(Table(m))
    Some(_) => return Err("cannot mix a table with an array of tables")
  }
  Ok(m)
}

///|
fn Parser::parse_table_header(self : Parser) -> Unit raise TomlError {
  self.advance()
  let path = self.parse_key()
  self.expect(RBracket)
  match define_table(self.root, path) {
    Ok(table) => self.current = table
    Err(msg) => self.raise_err(msg)
  }
}

///|
fn Parser::parse_array_of_tables_header(self : Parser) -> Unit raise TomlError {
  self.advance()
  self.advance()
  let path = self.parse_key()
  self.expect(RBracket)
  self.expect(RBracket)
  match append_array_table(self.root, path) {
    Ok(table) => self.current = table
    Err(msg) => self.raise_err(msg)
  }
}

///|
fn Parser::parse_key_value(self : Parser) -> Unit raise TomlError {
  let key = self.parse_key()
  self.expect(Equal)
  let value = self.parse_value()
  self.set_dotted(self.current, key, value)
}

///|
fn Parser::parse_value(self : Parser) -> Value raise TomlError {
  let t = self.peek()
  match t.kind {
    Str(s) => {
      self.advance()
      String(s)
    }
    Word(w) => {
      self.advance()
      self.parse_word_value(w)
    }
    LBracket => self.parse_array()
    LBrace => self.parse_inline_table()
    _ => self.raise_err("expected a value")
  }
}

///|
fn Parser::parse_array(self : Parser) -> Value raise TomlError {
  self.advance()
  let items : Array[Value] = []
  self.skip_newlines()
  if self.peek_kind() == RBracket {
    self.advance()
    return Array(items)
  }
  while true {
    items.push(self.parse_value())
    self.skip_newlines()
    match self.peek_kind() {
      Comma => {
        self.advance()
        self.skip_newlines()
        if self.peek_kind() == RBracket {
          self.advance()
          break
        }
      }
      RBracket => {
        self.advance()
        break
      }
      _ => self.raise_err("expected ',' or ']' in array")
    }
  }
  Array(items)
}

///|
fn Parser::parse_inline_table(self : Parser) -> Value raise TomlError {
  self.advance()
  let table : Table = Map([])
  if self.peek_kind() == RBrace {
    self.advance()
    return Table(table)
  }
  while true {
    let key = self.parse_key()
    self.expect(Equal)
    let value = self.parse_value()
    self.set_dotted(table, key, value)
    match self.peek_kind() {
      Comma => self.advance()
      RBrace => {
        self.advance()
        break
      }
      _ => self.raise_err("expected ',' or '}' in inline table")
    }
  }
  Table(table)
}

///|
fn Parser::parse_word_value(
  self : Parser,
  word : String,
) -> Value raise TomlError {
  match word {
    "true" => Boolean(true)
    "false" => Boolean(false)
    _ =>
      if is_datetime_word(word) {
        let following = if is_date_only(word) {
          match self.peek_kind() {
            Word(w2) if is_time_only(w2) => {
              self.advance()
              Some(w2)
            }
            _ => None
          }
        } else {
          None
        }
        match parse_datetime_str(word, following) {
          Ok(v) => v
          Err(msg) => self.raise_word_err(word, msg)
        }
      } else if is_float_word(word) {
        match parse_float_str(word) {
          Ok(v) => Float(v)
          Err(msg) => self.raise_word_err(word, msg)
        }
      } else {
        match parse_integer_str(word) {
          Ok(v) => Integer(v)
          Err(msg) => self.raise_word_err(word, msg)
        }
      }
  }
}

///|
fn[T] Parser::raise_word_err(
  self : Parser,
  word : String,
  msg : String,
) -> T raise TomlError {
  self.raise_err("\{msg}: \{word}")
}

///|
/// Parses the document and returns its root table.
fn Parser::parse_document(self : Parser) -> Table raise TomlError {
  self.skip_newlines()
  while !self.at_end() {
    if self.peek_kind() == LBracket {
      if self.peek_at(1).kind == LBracket {
        self.parse_array_of_tables_header()
      } else {
        self.parse_table_header()
      }
    } else {
      self.parse_key_value()
    }
    self.expect_newline_or_eof()
    self.skip_newlines()
  }
  self.root
}

///|
/// Parses a TOML document into a `Table`, raising `TomlError` on failure.
fn do_parse(text : String) -> Table raise TomlError {
  let tokens = Lexer::tokenize(text)
  let parser = Parser::new(tokens)
  parser.parse_document()
}

///|
/// Parses a TOML document into a `Table`, or returns a `TomlError`.
pub fn parse(text : String) -> Result[Table, TomlError] {
  Ok(do_parse(text)) catch {
    e => Err(e)
  }
}

// ---------------------------------------------------------------------------
// Word interpretation helpers (pure, so they are easy to unit-test).
// ---------------------------------------------------------------------------

///|
fn char_is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_all_digits(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  for c in s.iter() {
    if !char_is_digit(c) {
      return false
    }
  }
  true
}

///|
/// True when `word` starts with a `YYYY-MM-DD` date prefix.
fn looks_like_date(word : String) -> Bool {
  word.length() >= 10 &&
  is_all_digits(word[:4].to_owned()) &&
  word[4:5] == "-" &&
  is_all_digits(word[5:7].to_owned()) &&
  word[7:8] == "-" &&
  is_all_digits(word[8:10].to_owned())
}

///|
/// True when `word` is exactly a `YYYY-MM-DD` date.
fn is_date_only(word : String) -> Bool {
  word.length() == 10 && looks_like_date(word)
}

///|
/// True when `word` starts with a `HH:MM:SS` time prefix.
fn is_time_only(word : String) -> Bool {
  word.length() >= 8 &&
  is_all_digits(word[:2].to_owned()) &&
  word[2:3] == ":" &&
  is_all_digits(word[3:5].to_owned()) &&
  word[5:6] == ":" &&
  is_all_digits(word[6:8].to_owned())
}

///|
fn is_datetime_word(word : String) -> Bool {
  word.contains(":") ||
  word.contains("T") ||
  word.contains("t") ||
  looks_like_date(word)
}

///|
fn is_float_word(word : String) -> Bool {
  if word == "inf" ||
    word == "+inf" ||
    word == "-inf" ||
    word == "nan" ||
    word == "+nan" ||
    word == "-nan" {
    return true
  }
  if has_integer_base_prefix(word) {
    return false
  }
  word.contains(".") || word.contains("e") || word.contains("E")
}

///|
/// True when `word` has a non-decimal integer base prefix (`0x`, `0o`, `0b`).
fn has_integer_base_prefix(word : String) -> Bool {
  let s = if word.has_prefix("+") || word.has_prefix("-") {
    word[1:]
  } else {
    word
  }
  s.has_prefix("0x") ||
  s.has_prefix("0X") ||
  s.has_prefix("0o") ||
  s.has_prefix("0O") ||
  s.has_prefix("0b") ||
  s.has_prefix("0B")
}

///|
fn strip_underscores(s : String) -> String {
  let chars : Array[Char] = []
  for c in s.iter() {
    if c != '_' {
      chars.push(c)
    }
  }
  String::from_iter(chars.iter())
}

///|
/// True when `word` is a decimal integer with a leading zero (forbidden by TOML).
fn has_leading_zero(word : String) -> Bool {
  let s = if word.has_prefix("+") || word.has_prefix("-") {
    word[1:]
  } else {
    word
  }
  if s.length() <= 1 {
    return false
  }
  if s.has_prefix("0x") ||
    s.has_prefix("0X") ||
    s.has_prefix("0o") ||
    s.has_prefix("0O") ||
    s.has_prefix("0b") ||
    s.has_prefix("0B") {
    return false
  }
  s.has_prefix("0")
}

///|
fn parse_integer_str(word : String) -> Result[Int64, String] {
  if has_leading_zero(word) {
    return Err("leading zeros are not allowed")
  }
  Ok(@string.parse_int64(word)) catch {
    _ => Err("invalid integer")
  }
}

///|
fn parse_float_str(word : String) -> Result[Double, String] {
  match word {
    "inf" | "+inf" => Ok(@double.infinity)
    "-inf" => Ok(@double.neg_infinity)
    "nan" | "+nan" | "-nan" => Ok(@double.not_a_number)
    _ => {
      let cleaned = strip_underscores(word)
      if !is_valid_toml_float(cleaned) {
        return Err("invalid float")
      }
      Ok(@string.parse_double(cleaned)) catch {
        _ => Err("invalid float")
      }
    }
  }
}

///|
/// Validates the TOML float grammar (integer part, optional fraction with at
/// least one digit, optional exponent with at least one digit).
fn is_valid_toml_float(word : String) -> Bool {
  let mut s = word
  if s.has_prefix("+") || s.has_prefix("-") {
    s = s[1:].to_owned()
  }
  let mut e_idx = -1
  let mut dot_idx = -1
  let chars : Array[Char] = s.iter().collect()
  for i in 0..<chars.length() {
    match chars[i] {
      'e' | 'E' => if e_idx >= 0 { return false } else { e_idx = i }
      '.' => if dot_idx >= 0 { return false } else { dot_idx = i }
      _ => ()
    }
  }
  if e_idx >= 0 && dot_idx >= 0 && e_idx < dot_idx {
    return false
  }
  let mant_end = if e_idx >= 0 { e_idx } else { s.length() }
  let mantissa = s[:mant_end].to_owned()
  if dot_idx >= 0 {
    if dot_idx >= mant_end {
      return false
    }
    let int_part = mantissa[:dot_idx].to_owned()
    let frac_part = mantissa[dot_idx + 1:].to_owned()
    if !is_all_digits(int_part) || !is_all_digits(frac_part) {
      return false
    }
  } else if e_idx < 0 || !is_all_digits(mantissa) {
    return false
  }
  if e_idx >= 0 {
    let mut exp = s[e_idx + 1:].to_owned()
    if exp.has_prefix("+") || exp.has_prefix("-") {
      exp = exp[1:].to_owned()
    }
    if !is_all_digits(exp) {
      return false
    }
  }
  true
}

///|
fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    2 => if is_leap_year(year) { 29 } else { 28 }
    4 => 30
    6 => 30
    9 => 30
    11 => 30
    _ => 31
  }
}

///|
fn parse_int_component(s : String) -> Result[Int, String] {
  Ok(@string.parse_int(s)) catch {
    _ => Err("invalid number")
  }
}

///|
fn parse_date_str(s : String) -> Result[LocalDate, String] {
  if s.length() != 10 || s[4:5] != "-" || s[7:8] != "-" {
    return Err("invalid date")
  }
  let year = match parse_int_component(s[:4].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid date")
  }
  let month = match parse_int_component(s[5:7].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid date")
  }
  let day = match parse_int_component(s[8:10].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid date")
  }
  if month < 1 || month > 12 {
    return Err("invalid date")
  }
  if day < 1 || day > days_in_month(year, month) {
    return Err("invalid date")
  }
  Ok(LocalDate::new(year, month, day))
}

///|
fn frac_to_nanos(frac : String) -> Int {
  let s = if frac.length() >= 9 {
    frac[:9].to_owned()
  } else {
    let mut p = frac
    while p.length() < 9 {
      p = p + "0"
    }
    p
  }
  match parse_int_component(s) {
    Ok(v) => v
    Err(_) => 0
  }
}

///|
fn parse_time_str(s : String) -> Result[LocalTime, String] {
  if s.length() < 8 || s[2:3] != ":" || s[5:6] != ":" {
    return Err("invalid time")
  }
  let hour = match parse_int_component(s[:2].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid time")
  }
  let minute = match parse_int_component(s[3:5].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid time")
  }
  let second = match parse_int_component(s[6:8].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid time")
  }
  let mut nanosecond = 0
  if s.length() > 8 {
    if s[8:9] != "." {
      return Err("invalid time")
    }
    let frac = s[9:].to_owned()
    if !is_all_digits(frac) {
      return Err("invalid time")
    }
    nanosecond = frac_to_nanos(frac)
  }
  if hour < 0 || hour > 23 {
    return Err("invalid time")
  }
  if minute < 0 || minute > 59 {
    return Err("invalid time")
  }
  if second < 0 || second > 59 {
    return Err("invalid time")
  }
  Ok(LocalTime::new(hour, minute, second, nanosecond))
}

///|
fn parse_offset_str(s : String) -> Result[Int, String] {
  if s == "Z" || s == "z" {
    return Ok(0)
  }
  if s.length() != 6 || s[3:4] != ":" {
    return Err("invalid offset")
  }
  let sign = match s[:1] {
    "+" => 1
    "-" => -1
    _ => return Err("invalid offset")
  }
  let hour = match parse_int_component(s[1:3].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid offset")
  }
  let minute = match parse_int_component(s[4:6].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid offset")
  }
  if hour > 23 || minute > 59 {
    return Err("invalid offset")
  }
  Ok(sign * (hour * 60 + minute))
}

///|
fn is_digit_char(s : String) -> Bool {
  s.length() == 1 && is_all_digits(s)
}

///|
/// Parses the remainder of an offset/local date-time after the date and
/// `T`/`t` separator have been consumed.
fn parse_datetime_rest(date : LocalDate, s : String) -> Result[Value, String] {
  let mut i = 8
  if i < s.length() && s[i:i + 1] == "." {
    i += 1
    while i < s.length() && is_digit_char(s[i:i + 1].to_owned()) {
      i += 1
    }
  }
  let time = match parse_time_str(s[:i].to_owned()) {
    Ok(v) => v
    Err(_) => return Err("invalid time")
  }
  let offset_str = s[i:].to_owned()
  if offset_str == "" {
    Ok(LocalDateTime(LocalDateTime::new(date, time)))
  } else {
    let offset = match parse_offset_str(offset_str) {
      Ok(v) => v
      Err(_) => return Err("invalid offset")
    }
    Ok(OffsetDateTime(OffsetDateTime::new(date, time, offset)))
  }
}

///|
/// Parses a date-time word (and an optional following time word for the
/// space-separated local date-time form) into a `Value`.
fn parse_datetime_str(
  word : String,
  following : String?,
) -> Result[Value, String] {
  if word.contains(":") && !looks_like_date(word) {
    return match parse_time_str(word) {
      Ok(t) => Ok(LocalTime(t))
      Err(e) => Err(e)
    }
  }
  if looks_like_date(word) {
    let date = match parse_date_str(word[:10].to_owned()) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    let rest = word[10:].to_owned()
    if rest == "" {
      return match following {
        Some(t) =>
          match parse_time_str(t) {
            Ok(time) => Ok(LocalDateTime(LocalDateTime::new(date, time)))
            Err(e) => Err(e)
          }
        None => Ok(LocalDate(date))
      }
    }
    let sep = rest[:1]
    if sep != "T" && sep != "t" {
      return Err("invalid date-time")
    }
    return parse_datetime_rest(date, rest[1:].to_owned())
  }
  Err("invalid date-time")
}
