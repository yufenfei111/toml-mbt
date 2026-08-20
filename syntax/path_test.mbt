///|
test "parse key paths accepts bare quoted dotted and padded segments" {
  let path = parse_key_path("  bare . \"display.name\" . 'raw key'  ").unwrap()
  assert_eq(path, ["bare", "display.name", "raw key"])
}

///|
test "parse key paths decodes basic escapes but preserves literal escapes" {
  let basic = parse_key_path("\"line\\nname\".\"a\\u002Eb\"").unwrap()
  let literal = parse_key_path("'line\\nname'").unwrap()
  assert_eq(basic, ["line\nname", "a.b"])
  assert_eq(literal, ["line\\nname"])
}

///|
test "parse key paths rejects an empty segment" {
  assert_true(parse_key_path("one..two") is Err(_))
}

///|
test "lookup finds value but preserves original spelling" {
  let source = "[package]\n\"display.name\"  =  \"old\" # keep\n"
  let result = scan(source)
  assert_eq(result.errors.length(), 0)
  let document = result.document
  let entry = document.find_entry(["package", "display.name"]).unwrap()
  assert_eq(
    source[entry.value_span.start_offset:entry.value_span.end_offset],
    "\"old\"",
  )
}

///|
test "entry spans use UTF-8 bytes and retain multiline basic strings" {
  let source = "\"é\" = \"\"\"first\nsecond\"\"\" # keep\n"
  let entry = scan(source).document.find_entry(["é"]).unwrap()
  assert_eq(entry.key_span.start_offset, 0)
  assert_eq(entry.key_span.end_offset, 4)
  assert_eq(entry.value_span.start_offset, 7)
  assert_eq(entry.value_span.end_offset, 25)
  assert_eq(entry.line_span.end_offset, 33)
}

///|
test "multiline basic string quote runs do not absorb an inline comment" {
  let source = "value = \"\"\"a\"\"\"\" # keep\n"
  let entry = scan(source).document.find_entry(["value"]).unwrap()
  assert_eq(entry.value_span.start_offset, 8)
  assert_eq(entry.value_span.end_offset, 16)
}

///|
test "multiline basic string quote runs after the opener retain an inline comment boundary" {
  let source = "value = \"\"\"\"a\"\"\" # keep\n"
  let entry = scan(source).document.find_entry(["value"]).unwrap()
  assert_eq(entry.value_span.start_offset, 8)
  assert_eq(entry.value_span.end_offset, 16)
}

///|
test "lookup applies normal table context and records source spans" {
  let source = "[tool.build]\n name = [\n  1,\n] # keep\n"
  let entry = scan(source).document
    .find_entry(["tool", "build", "name"])
    .unwrap()
  assert_eq(entry.editable, true)
  assert_eq(
    source[entry.key_span.start_offset:entry.key_span.end_offset],
    "name",
  )
  assert_eq(
    source[entry.value_span.start_offset:entry.value_span.end_offset],
    "[\n  1,\n]",
  )
  assert_eq(
    source[entry.line_span.start_offset:entry.line_span.end_offset],
    " name = [\n  1,\n] # keep\n",
  )
  match entry.table_span {
    Some(span) =>
      assert_eq(source[span.start_offset:span.end_offset], "[tool.build]\n")
    None => fail("expected normal table span")
  }
}

///|
test "array table entries remain indexed but ambiguous duplicates are not editable" {
  let source = "[[products]]\nname = \"hammer\"\n[[products]]\nname = \"nail\"\n[other]\nname = \"safe\"\n"
  let document = scan(source).document
  let products = document.find_entries(["products", "name"])
  assert_eq(products.length(), 2)
  assert_eq(products[0].editable, false)
  assert_eq(products[1].editable, false)
  assert_true(document.find_entry(["products", "name"]) is None)
  let other = document.find_entry(["other", "name"]).unwrap()
  assert_eq(other.editable, true)
  assert_eq(document.find_entries(["missing"]).length(), 0)
}
