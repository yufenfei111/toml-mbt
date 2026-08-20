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
