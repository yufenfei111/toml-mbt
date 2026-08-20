///|
/// The seriousness of a diagnostic reported by the workbench.
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, Debug)

///|
/// A replacement that a caller may apply after deciding it is safe to do so.
pub(all) struct SuggestedEdit {
  span : @syntax.SourceSpan
  replacement : String
} derive(Eq, Debug)

///|
/// A stable, source-located problem emitted by the workbench command layer.
pub(all) struct Diagnostic {
  severity : Severity
  code : String
  message : String
  span : @syntax.SourceSpan
  suggestion : SuggestedEdit?
} derive(Eq, Debug)

///|
/// Returns a deterministic copy sorted by start offset, end offset, and code.
pub fn sort_diagnostics(items : Array[Diagnostic]) -> Array[Diagnostic] {
  let sorted = items.copy()
  sorted.sort_by(compare_diagnostics)
  sorted
}

///|
fn compare_diagnostics(left : Diagnostic, right : Diagnostic) -> Int {
  let start = left.span.start_offset.compare(right.span.start_offset)
  if start != 0 {
    return start
  }
  let end = left.span.end_offset.compare(right.span.end_offset)
  if end != 0 {
    return end
  }
  compare_code_points(left.code, right.code)
}

///|
/// Compare strings lexicographically by Unicode code point instead of the
/// runtime's shortlex string ordering.
fn compare_code_points(left : String, right : String) -> Int {
  let left_chars = left.to_array()
  let right_chars = right.to_array()
  let length = if left_chars.length() < right_chars.length() {
    left_chars.length()
  } else {
    right_chars.length()
  }
  for index in 0..<length {
    let order = left_chars[index].compare(right_chars[index])
    if order != 0 {
      return order
    }
  }
  left_chars.length().compare(right_chars.length())
}

///|
/// Renders one diagnostic with its location, source line, and highlighted
/// range. The excerpt is always a single physical line without line endings.
pub fn render_text(file : String, source : String, item : Diagnostic) -> String {
  let (excerpt, caret) = source_excerpt(source, item.span)
  "\{file}:\{display_line(item.span.line)}:\{display_column(item.span.column)}: \{severity_name(item.severity)}[\{item.code}]: \{item.message}\n\{excerpt}\n\{caret}"
}

///|
fn display_line(line : Int) -> Int {
  if line < 1 {
    1
  } else {
    line
  }
}

///|
fn display_column(column : Int) -> Int {
  if column < 1 {
    1
  } else {
    column
  }
}

///|
fn severity_name(severity : Severity) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
  }
}

///|
fn source_excerpt(
  source : String,
  span : @syntax.SourceSpan,
) -> (String, String) {
  let chars = source.to_array()
  let start = byte_offset_to_character_index(source, span.start_offset)
  let end = byte_offset_to_character_index(source, span.end_offset)
  let mut line_start = start
  while line_start > 0 &&
        chars[line_start - 1] != '\n' &&
        chars[line_start - 1] != '\r' {
    line_start -= 1
  }
  let mut line_end = start
  while line_end < chars.length() &&
        chars[line_end] != '\n' &&
        chars[line_end] != '\r' {
    line_end += 1
  }
  let mut prefix = ""
  for index in line_start..<start {
    prefix += if chars[index] == '\t' { "    " } else { " " }
  }
  let highlighted_end = if end < start {
    start
  } else if end > line_end {
    line_end
  } else {
    end
  }
  let caret_count = if highlighted_end > start {
    highlighted_end - start
  } else {
    1
  }
  let mut carets = ""
  for _ in 0..<caret_count {
    carets += "^"
  }
  (String::from_iter(chars[line_start:line_end].iter()), prefix + carets)
}

///|
/// Converts a UTF-8 byte offset to a clamped character-array index. Invalid
/// offsets within a multi-byte character point at that character rather than
/// slicing inside its encoding.
fn byte_offset_to_character_index(source : String, target : Int) -> Int {
  if target <= 0 {
    return 0
  }
  let mut offset = 0
  let mut index = 0
  for character in source {
    if offset >= target {
      return index
    }
    let next_offset = offset + utf8_width(character)
    if next_offset > target {
      return index
    }
    offset = next_offset
    index += 1
  }
  index
}

///|
fn utf8_width(character : Char) -> Int {
  let code = character.to_int()
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
/// Renders diagnostics as a compact JSON array. String fields are escaped by
/// the core JSON implementation; spans remain numeric structured values.
pub fn render_json(items : Array[Diagnostic]) -> String {
  let rendered : Array[String] = []
  for item in items {
    rendered.push(render_json_diagnostic(item))
  }
  "[" + rendered.join(",") + "]"
}

///|
fn render_json_diagnostic(item : Diagnostic) -> String {
  let suggestion = match item.suggestion {
    None => "null"
    Some(edit) => render_json_suggestion(edit)
  }
  "{\"severity\":" +
  json_string(severity_name(item.severity)) +
  ",\"code\":" +
  json_string(item.code) +
  ",\"message\":" +
  json_string(item.message) +
  ",\"span\":" +
  render_json_span(item.span) +
  ",\"suggestion\":" +
  suggestion +
  "}"
}

///|
fn render_json_suggestion(edit : SuggestedEdit) -> String {
  "{\"span\":" +
  render_json_span(edit.span) +
  ",\"replacement\":" +
  json_string(edit.replacement) +
  "}"
}

///|
fn render_json_span(span : @syntax.SourceSpan) -> String {
  "{\"start_offset\":\{span.start_offset},\"end_offset\":\{span.end_offset},\"line\":\{span.line},\"column\":\{span.column}}"
}

///|
fn json_string(value : String) -> String {
  Json::string(value).stringify()
}
