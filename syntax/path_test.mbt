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
test "parse key paths rejects empty double trailing and whitespace-only segments" {
  assert_true(parse_key_path("") is Err(_))
  assert_true(parse_key_path("one..two") is Err(_))
  assert_true(parse_key_path("one.") is Err(_))
  assert_true(parse_key_path(" \t . \t ") is Err(_))
}

///|
test "parse key paths decodes escaped basic key quotes" {
  let path = parse_key_path("\"a\\\"b\".'literal key'").unwrap()
  assert_eq(path, ["a\"b", "literal key"])
}

///|
test "parse key paths rejects invalid unicode scalars without overflow" {
  assert_true(parse_key_path("\"\\U00110000\"") is Err(_))
  assert_true(parse_key_path("\"\\UFFFFFFFF\"") is Err(_))
  assert_true(parse_key_path("\"\\uD800\"") is Err(_))
  assert_eq(parse_key_path("\"\\U0010FFFF\"").unwrap(), ["􏿿"])
}

///|
test "parse key paths rejects forbidden raw quoted-key controls" {
  assert_true(parse_key_path("\"bad\u0001\"") is Err(_))
  assert_true(parse_key_path("'bad\u007F'") is Err(_))
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
test "array comments cannot alter the value span state" {
  let source = "items = [\n  # [ ] \" # ignored\n  1,\n] # outer\nnext = 2\n"
  let document = scan(source).document
  let items = document.find_entry(["items"]).unwrap()
  assert_eq(
    source[items.value_span.start_offset:items.value_span.end_offset],
    "[\n  # [ ] \" # ignored\n  1,\n]",
  )
  assert_true(document.find_entry(["next"]) is Some(_))
}

///|
test "malformed header tail clears context until a valid header" {
  let source = "[old]\na = 1\n[new]junk\nbad = 2\n[good]\nok = 3\n"
  let document = scan(source).document
  assert_true(document.find_entry(["old", "a"]) is Some(_))
  assert_true(document.find_entry(["old", "bad"]) is None)
  assert_true(document.find_entry(["new", "bad"]) is None)
  assert_true(document.find_entry(["good", "ok"]) is Some(_))
}

///|
test "spans retain CRLF bytes and an EOF value" {
  let source = "[table]\r\nname = 2"
  let entry = scan(source).document.find_entry(["table", "name"]).unwrap()
  assert_eq(entry.value_span.start_offset, 16)
  assert_eq(entry.value_span.end_offset, 17)
  assert_eq(entry.line_span.end_offset, 17)
  match entry.table_span {
    Some(span) => assert_eq(span.end_offset, 9)
    None => fail("expected table span")
  }
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

///|
test "table blocks expose exact insertion boundaries and editability" {
  let source = "root = 1\n[normal]\nvalue = 2\n[[items]]\nname = \"one\"\n[items.detail]\n"
  let document = scan(source).document
  let normal = document.find_table_blocks(["normal"])
  assert_eq(normal.length(), 1)
  assert_eq(normal[0].array, false)
  assert_eq(normal[0].editable, true)
  assert_eq(
    source[normal[0].header_span.start_offset:normal[0].header_span.end_offset],
    "[normal]\n",
  )
  assert_eq(
    source[normal[0].header_span.start_offset:normal[0].end_offset],
    "[normal]\nvalue = 2\n",
  )
  let items = document.find_table_blocks(["items"])
  assert_eq(items.length(), 1)
  assert_eq(items[0].array, true)
  assert_eq(items[0].editable, false)
  let detail = document.find_table_blocks(["items", "detail"])
  assert_eq(detail.length(), 1)
  assert_eq(detail[0].array, false)
  assert_eq(detail[0].editable, false)
  assert_eq(detail[0].end_offset, source.length())
}

///|
test "source positions map character columns to exact UTF-8 spans" {
  let source = "a = 1\r\né = ]"
  let first = source_span_at_position(source, 2, 1)
  assert_eq(first.start_offset, 7)
  assert_eq(first.end_offset, 9)
  assert_eq(first.line, 2)
  assert_eq(first.column, 1)
  let invalid = source_span_at_position(source, 2, 5)
  assert_eq(invalid.start_offset, 12)
  assert_eq(invalid.end_offset, 13)
  assert_eq(invalid.line, 2)
  assert_eq(invalid.column, 5)
}

///|
test "source positions clamp invalid coordinates to an EOF span" {
  let eof = source_span_at_position("a = 1", 9, 9)
  assert_eq(eof.start_offset, 5)
  assert_eq(eof.end_offset, 5)
  assert_eq(eof.line, 1)
  assert_eq(eof.column, 6)
}

///|
test "source positions treat CRLF as one complete newline span" {
  let newline = source_span_at_position("a = 1\r\nnext = 2", 1, 6)
  assert_eq(newline.start_offset, 5)
  assert_eq(newline.end_offset, 7)
  assert_eq(newline.line, 1)
  assert_eq(newline.column, 6)
}
