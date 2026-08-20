///|
/// A safe-edit failure. Every variant is returned before any candidate text is
/// exposed to the caller.
pub(all) enum OperationError {
  InvalidPath(String)
  InvalidValue(String)
  NotFound(Array[String])
  AmbiguousPath(Array[String])
  UnsupportedInsertion(Array[String])
  ResultIsInvalid(String)
  TextEdit(EditError)
} derive(Debug)

///|
fn utf8_length(value : String) -> Int {
  let mut length = 0
  for character in value {
    let code = character.to_int()
    length += if code <= 0x7F {
      1
    } else if code <= 0x7FF {
      2
    } else if code <= 0xFFFF {
      3
    } else {
      4
    }
  }
  length
}

///|
fn invalid_value(message : String) -> Result[Unit, OperationError] {
  Err(InvalidValue(message))
}

///|
/// Proves that `encoded` occupies exactly one sentinel assignment. The
/// scanner supplies structural boundaries, including multiline-string state;
/// the semantic parser then proves that the assignment is valid TOML and did
/// not create a second root key or table.
fn validate_encoded_value(encoded : String) -> Result[Unit, OperationError] {
  let sentinel = "__workbench_value__"
  let prefix = sentinel + " = "
  let synthetic = prefix + encoded + "\n"
  let scanned = @syntax.scan(synthetic)
  if scanned.errors.length() > 0 {
    return invalid_value(scanned.errors[0].message)
  }
  if scanned.document.statements.length() != 1 {
    return invalid_value("encoded text must contain exactly one TOML value")
  }
  let entries = scanned.document.find_entries([sentinel])
  if entries.length() != 1 {
    return invalid_value("encoded text must contain exactly one TOML value")
  }
  let entry = entries[0]
  let value_start = utf8_length(prefix)
  let value_end = value_start + utf8_length(encoded)
  if entry.value_span.start_offset != value_start ||
    entry.value_span.end_offset != value_end {
    return invalid_value("encoded text contains text outside its TOML value")
  }
  match @toml-mbt.parse(synthetic) {
    Err(error) => invalid_value(error.to_string())
    Ok(table) =>
      if table.length() == 1 && table.get(sentinel) is Some(_) {
        Ok(())
      } else {
        invalid_value("encoded text mutated the sentinel document")
      }
  }
}

///|
fn editable_document(
  source : String,
) -> Result[@syntax.Document, OperationError] {
  let scanned = @syntax.scan(source)
  if scanned.errors.length() > 0 {
    Err(ResultIsInvalid("source scan failed: " + scanned.errors[0].message))
  } else {
    Ok(scanned.document)
  }
}

///|
fn validate_path(path : Array[String]) -> Result[Unit, OperationError] {
  if path.length() == 0 {
    Err(InvalidPath("key path must contain at least one segment"))
  } else {
    Ok(())
  }
}

///|
fn apply_and_reparse(
  source : String,
  edit : TextEdit,
) -> Result[String, OperationError] {
  match apply_edits(source, [edit]) {
    Err(error) => Err(TextEdit(error))
    Ok(candidate) => {
      let scanned = @syntax.scan(candidate)
      if scanned.errors.length() > 0 {
        return Err(
          ResultIsInvalid("result scan failed: " + scanned.errors[0].message),
        )
      }
      match @toml-mbt.parse(candidate) {
        Ok(_) => Ok(candidate)
        Err(error) => Err(ResultIsInvalid(error.to_string()))
      }
    }
  }
}

///|
fn is_bare_key_segment(segment : String) -> Bool {
  if segment.length() == 0 {
    return false
  }
  for character in segment {
    let bare = (character >= 'a' && character <= 'z') ||
      (character >= 'A' && character <= 'Z') ||
      (character >= '0' && character <= '9') ||
      character == '_' ||
      character == '-'
    if !bare {
      return false
    }
  }
  true
}

///|
fn padded_hex4(code : Int) -> String {
  let digits = code.to_string(radix=16)
  "0".repeat(4 - digits.length()) + digits
}

///|
fn render_key_segment(segment : String) -> String {
  if is_bare_key_segment(segment) {
    return segment
  }
  let output = StringBuilder(size_hint=segment.length() + 2)
  output.write_char('"')
  for character in segment {
    match character {
      '\u0008' => output.write_string("\\b")
      '\t' => output.write_string("\\t")
      '\n' => output.write_string("\\n")
      '\u000C' => output.write_string("\\f")
      '\r' => output.write_string("\\r")
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      _ => {
        let code = character.to_int()
        if code < 0x20 || code == 0x7F {
          output.write_string("\\u" + padded_hex4(code))
        } else {
          output.write_char(character)
        }
      }
    }
  }
  output.write_char('"')
  output.to_string()
}

///|
fn newline_style(source : String) -> String {
  let chars = source.to_array()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '\r' {
      if index + 1 < chars.length() && chars[index + 1] == '\n' {
        return "\r\n"
      }
      return "\r"
    }
    if chars[index] == '\n' {
      return "\n"
    }
    index += 1
  }
  "\n"
}

///|
fn byte_before_offset(source : String, target : Int) -> Char? {
  let mut offset = 0
  let mut previous : Char? = None
  for character in source {
    if offset == target {
      return previous
    }
    let code = character.to_int()
    offset += if code <= 0x7F {
      1
    } else if code <= 0x7FF {
      2
    } else if code <= 0xFFFF {
      3
    } else {
      4
    }
    previous = Some(character)
  }
  previous
}

///|
fn insertion_text(
  source : String,
  offset : Int,
  key : String,
  encoded : String,
) -> String {
  let newline = newline_style(source)
  let leading = match byte_before_offset(source, offset) {
    Some('\r') | Some('\n') | None => ""
    Some(_) => newline
  }
  leading + render_key_segment(key) + " = " + encoded + newline
}

///|
fn root_insertion_offset(document : @syntax.Document, source : String) -> Int {
  for statement in document.statements {
    match statement.kind {
      @syntax.TableHeader | @syntax.ArrayTableHeader =>
        return statement.span.start_offset
      _ => ()
    }
  }
  utf8_length(source)
}

///|
fn insertion_edit(
  document : @syntax.Document,
  source : String,
  path : Array[String],
  encoded : String,
) -> Result[TextEdit, OperationError] {
  if path.length() == 1 {
    let offset = root_insertion_offset(document, source)
    return Ok({
      start_offset: offset,
      end_offset: offset,
      replacement: insertion_text(source, offset, path[0], encoded),
    })
  }
  let parent = path[:path.length() - 1].to_owned()
  let blocks = document.find_table_blocks(parent)
  if blocks.length() != 1 || blocks[0].array || !blocks[0].editable {
    return Err(UnsupportedInsertion(path.copy()))
  }
  let offset = blocks[0].end_offset
  Ok({
    start_offset: offset,
    end_offset: offset,
    replacement: insertion_text(
      source,
      offset,
      path[path.length() - 1],
      encoded,
    ),
  })
}

///|
/// Replaces only an existing value span, or inserts into one deterministic
/// root/normal-table location. The complete candidate is reparsed before it
/// is returned.
pub fn set_value(
  source : String,
  path : Array[String],
  encoded : String,
) -> Result[String, OperationError] {
  let document = match editable_document(source) {
    Err(error) => return Err(error)
    Ok(document) => document
  }
  match validate_path(path) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match validate_encoded_value(encoded) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let matches = document.find_entries(path)
  if matches.length() > 1 {
    return Err(AmbiguousPath(path.copy()))
  }
  let edit = if matches.length() == 1 {
    let entry = matches[0]
    if !entry.editable {
      return Err(UnsupportedInsertion(path.copy()))
    }
    TextEdit::{
      start_offset: entry.value_span.start_offset,
      end_offset: entry.value_span.end_offset,
      replacement: encoded,
    }
  } else {
    match insertion_edit(document, source, path, encoded) {
      Err(error) => return Err(error)
      Ok(edit) => edit
    }
  }
  apply_and_reparse(source, edit)
}

///|
/// Removes one unambiguous key/value statement, including its inline comment
/// and line ending but excluding all preceding standalone trivia.
pub fn remove_key(
  source : String,
  path : Array[String],
) -> Result[String, OperationError] {
  let document = match editable_document(source) {
    Err(error) => return Err(error)
    Ok(document) => document
  }
  match validate_path(path) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let matches = document.find_entries(path)
  if matches.length() == 0 {
    return Err(NotFound(path.copy()))
  }
  if matches.length() > 1 {
    return Err(AmbiguousPath(path.copy()))
  }
  let entry = matches[0]
  if !entry.editable {
    return Err(UnsupportedInsertion(path.copy()))
  }
  apply_and_reparse(source, {
    start_offset: entry.line_span.start_offset,
    end_offset: entry.line_span.end_offset,
    replacement: "",
  })
}
