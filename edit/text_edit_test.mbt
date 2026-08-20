///|
test "returns the original text for an empty edit list" {
  let source = "alpha beta"
  assert_eq(apply_edits(source, []), Ok(source))
}

///|
test "replaces one byte range" {
  let edit = TextEdit::{ start_offset: 6, end_offset: 10, replacement: "B" }
  assert_eq(apply_edits("alpha beta", [edit]), Ok("alpha B"))
}

///|
test "applies non-overlapping edits from right to left" {
  let edits = [
    TextEdit::{ start_offset: 0, end_offset: 5, replacement: "A" },
    TextEdit::{ start_offset: 11, end_offset: 16, replacement: "G" },
  ]
  assert_eq(apply_edits("alpha beta gamma", edits), Ok("A beta G"))
}

///|
test "inserts text at a byte offset" {
  let edit = TextEdit::{ start_offset: 5, end_offset: 5, replacement: "!" }
  assert_eq(apply_edits("alpha", [edit]), Ok("alpha!"))
}

///|
test "deletes a byte range" {
  let edit = TextEdit::{ start_offset: 5, end_offset: 10, replacement: "" }
  assert_eq(apply_edits("alpha beta", [edit]), Ok("alpha"))
}

///|
test "rejects an out-of-bounds range without changing its source" {
  let source = "alpha"
  let edit = TextEdit::{ start_offset: 0, end_offset: 6, replacement: "A" }
  assert_eq(apply_edits(source, [edit]), Err(OutOfBounds(0, 6)))
  assert_eq(source, "alpha")
}

///|
test "rejects a reversed range" {
  let edit = TextEdit::{ start_offset: 4, end_offset: 2, replacement: "x" }
  assert_eq(apply_edits("alpha", [edit]), Err(InvalidRange(4, 2)))
}

///|
test "reports negative endpoints as out of bounds before reversed range validation" {
  let edit = TextEdit::{ start_offset: -1, end_offset: -2, replacement: "x" }
  assert_eq(apply_edits("alpha", [edit]), Err(OutOfBounds(-1, -2)))
}

///|
test "rejects overlap before applying anything" {
  let source = "abcdef"
  let edits = [
    TextEdit::{ start_offset: 0, end_offset: 4, replacement: "x" },
    TextEdit::{ start_offset: 3, end_offset: 6, replacement: "y" },
  ]
  match apply_edits(source, edits) {
    Ok(_) => abort("expected overlap error")
    Err(_) => ()
  }
  assert_eq(source, "abcdef")
}

///|
test "allows adjacent replacements" {
  let edits = [
    TextEdit::{ start_offset: 0, end_offset: 2, replacement: "A" },
    TextEdit::{ start_offset: 2, end_offset: 4, replacement: "B" },
  ]
  assert_eq(apply_edits("abcd", edits), Ok("AB"))
}

///|
test "rejects two insertions at the same offset" {
  let edits = [
    TextEdit::{ start_offset: 2, end_offset: 2, replacement: "x" },
    TextEdit::{ start_offset: 2, end_offset: 2, replacement: "y" },
  ]
  match validate_edits("abcd", edits) {
    Ok(_) => abort("expected duplicate insertion error")
    Err(_) => ()
  }
}

///|
test "rejects an insertion touching a replacement boundary" {
  let edits = [
    TextEdit::{ start_offset: 1, end_offset: 3, replacement: "X" },
    TextEdit::{ start_offset: 3, end_offset: 3, replacement: "!" },
  ]
  match apply_edits("abcd", edits) {
    Ok(_) => abort("expected boundary ambiguity error")
    Err(_) => ()
  }
}

///|
test "uses UTF-8 byte offsets and permits unicode replacements" {
  let edit = TextEdit::{ start_offset: 1, end_offset: 4, replacement: "\n界" }
  assert_eq(apply_edits("a界b", [edit]), Ok("a\n界b"))
}

///|
test "rejects an offset inside a UTF-8 scalar" {
  let edit = TextEdit::{ start_offset: 2, end_offset: 4, replacement: "x" }
  assert_eq(apply_edits("a界b", [edit]), Err(InvalidRange(2, 4)))
}

///|
test "replaces a supplementary UTF-8 scalar without leaving a surrogate half" {
  let edit = TextEdit::{ start_offset: 1, end_offset: 5, replacement: "X" }
  assert_eq(apply_edits("a😀b", [edit]), Ok("aXb"))
}

///|
test "replaces text immediately after a supplementary UTF-8 scalar" {
  let edit = TextEdit::{ start_offset: 5, end_offset: 6, replacement: "B" }
  assert_eq(apply_edits("a😀b", [edit]), Ok("a😀B"))
}

///|
test "inserts immediately before a supplementary UTF-8 scalar" {
  let edit = TextEdit::{ start_offset: 1, end_offset: 1, replacement: "!" }
  assert_eq(apply_edits("a😀b", [edit]), Ok("a!😀b"))
}

///|
test "inserts immediately after a supplementary UTF-8 scalar" {
  let edit = TextEdit::{ start_offset: 5, end_offset: 5, replacement: "!" }
  assert_eq(apply_edits("a😀b", [edit]), Ok("a😀!b"))
}

///|
test "maps byte offsets past multiple supplementary UTF-8 scalars" {
  let edit = TextEdit::{ start_offset: 8, end_offset: 9, replacement: "X" }
  assert_eq(apply_edits("😀😀b", [edit]), Ok("😀😀X"))
}

///|
test "rejects byte offsets inside a supplementary UTF-8 scalar" {
  let edit = TextEdit::{ start_offset: 2, end_offset: 5, replacement: "x" }
  assert_eq(apply_edits("a😀b", [edit]), Err(InvalidRange(2, 5)))
}

///|
test "validation returns a descending sorted copy without mutating its input" {
  let edits = [
    TextEdit::{ start_offset: 0, end_offset: 1, replacement: "A" },
    TextEdit::{ start_offset: 3, end_offset: 4, replacement: "D" },
  ]
  assert_eq(
    validate_edits("abcd", edits),
    Ok([
      TextEdit::{ start_offset: 3, end_offset: 4, replacement: "D" },
      TextEdit::{ start_offset: 0, end_offset: 1, replacement: "A" },
    ]),
  )
  assert_eq(edits[0].start_offset, 0)
  assert_eq(edits[1].start_offset, 3)
}
