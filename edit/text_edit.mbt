///|
/// A replacement over a half-open UTF-8 byte range in source text.
pub(all) struct TextEdit {
  start_offset : Int
  end_offset : Int
  replacement : String
} derive(Eq, Debug)

///|
/// A reason why a set of edits cannot be safely applied.
///
/// `InvalidRange` covers reversed ranges and offsets within a UTF-8 scalar;
/// `OutOfBounds` covers negative offsets and offsets past the UTF-8 byte
/// length of the source.
pub(all) enum EditError {
  InvalidRange(Int, Int)
  OutOfBounds(Int, Int)
  Overlap(TextEdit, TextEdit)
} derive(Eq, Debug)

///|
/// Validates edits against `source` and returns a descending-start copy.
///
/// Adjacent non-empty ranges are valid. Edits sharing a start offset, and an
/// insertion touching either boundary of a non-empty range, are rejected as
/// ambiguous.
pub fn validate_edits(
  source : String,
  edits : Array[TextEdit],
) -> Result[Array[TextEdit], EditError] {
  let source_length = utf8_byte_length(source)
  for edit in edits {
    if edit.start_offset < 0 ||
      edit.end_offset < 0 ||
      edit.start_offset > source_length ||
      edit.end_offset > source_length {
      return Err(OutOfBounds(edit.start_offset, edit.end_offset))
    }
    if edit.start_offset > edit.end_offset {
      return Err(InvalidRange(edit.start_offset, edit.end_offset))
    }
    if !is_utf8_boundary(source, edit.start_offset) ||
      !is_utf8_boundary(source, edit.end_offset) {
      return Err(InvalidRange(edit.start_offset, edit.end_offset))
    }
  }

  let sorted : Array[TextEdit] = []
  for edit in edits {
    sorted.push(copy_text_edit(edit))
  }
  sorted.sort_by(compare_edits_descending)

  for index in 0..<(sorted.length() - 1) {
    let higher = sorted[index]
    let lower = sorted[index + 1]
    if higher.start_offset == lower.start_offset ||
      lower.end_offset > higher.start_offset ||
      (
        lower.end_offset == higher.start_offset &&
        (is_insertion(lower) || is_insertion(higher))
      ) {
      return Err(Overlap(higher, lower))
    }
  }
  Ok(sorted)
}

///|
/// Applies a complete, validated edit set from right to left.
pub fn apply_edits(
  source : String,
  edits : Array[TextEdit],
) -> Result[String, EditError] {
  match validate_edits(source, edits) {
    Err(error) => Err(error)
    Ok(sorted) => {
      let mut output = source
      for edit in sorted {
        let start = byte_offset_to_code_unit(source, edit.start_offset)
        let end = byte_offset_to_code_unit(source, edit.end_offset)
        output = output[:start].to_owned() +
          edit.replacement +
          output[end:].to_owned()
      }
      Ok(output)
    }
  }
}

///|
fn compare_edits_descending(left : TextEdit, right : TextEdit) -> Int {
  let start_order = right.start_offset.compare(left.start_offset)
  if start_order != 0 {
    start_order
  } else {
    right.end_offset.compare(left.end_offset)
  }
}

///|
fn copy_text_edit(edit : TextEdit) -> TextEdit {
  {
    start_offset: edit.start_offset,
    end_offset: edit.end_offset,
    replacement: edit.replacement,
  }
}

///|
fn is_insertion(edit : TextEdit) -> Bool {
  edit.start_offset == edit.end_offset
}

///|
fn utf8_byte_length(source : String) -> Int {
  let mut length = 0
  for character in source {
    length += utf8_width(character)
  }
  length
}

///|
fn is_utf8_boundary(source : String, target : Int) -> Bool {
  let mut offset = 0
  if target == 0 {
    return true
  }
  for character in source {
    offset += utf8_width(character)
    if offset == target {
      return true
    }
    if offset > target {
      return false
    }
  }
  false
}

///|
/// Converts a previously validated UTF-8 byte offset into a String code-unit
/// index, which is safe to use for MoonBit string slicing.
fn byte_offset_to_code_unit(source : String, target : Int) -> Int {
  let mut byte_offset = 0
  let mut code_unit_offset = 0
  for _, character in source.iter2() {
    if byte_offset == target {
      return code_unit_offset
    }
    byte_offset += utf8_width(character)
    code_unit_offset += utf16_width(character)
  }
  source.length()
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
fn utf16_width(character : Char) -> Int {
  if character.to_int() <= 0xFFFF {
    1
  } else {
    2
  }
}
