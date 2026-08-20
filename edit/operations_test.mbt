///|
test "set changes only the value bytes" {
  let source = "title  =  \"old\"  # retain me\r\ncount=2\r\n"
  let output = set_value(source, ["title"], "\"new\"").unwrap()
  assert_eq(output, "title  =  \"new\"  # retain me\r\ncount=2\r\n")
}

///|
test "set replaces a quoted dotted key without changing its spelling" {
  let source = "\"display.name\" = \"old\" # keep\n"
  let output = set_value(source, ["display.name"], "\"new\"").unwrap()
  assert_eq(output, "\"display.name\" = \"new\" # keep\n")
}

///|
test "set replaces a value in one normal table" {
  let source = "[package]\nname = \"old\"\n[other]\nname = \"same\"\n"
  let output = set_value(source, ["package", "name"], "\"new\"").unwrap()
  assert_eq(output, "[package]\nname = \"new\"\n[other]\nname = \"same\"\n")
}

///|
test "set uses UTF-8 spans after supplementary characters" {
  let source = "emoji = \"😀\"\ntitle = \"old\"\n"
  let output = set_value(source, ["title"], "\"new\"").unwrap()
  assert_eq(output, "emoji = \"😀\"\ntitle = \"new\"\n")
}

///|
test "set accepts one multiline TOML string value" {
  let source = "message = \"old\" # keep\n"
  let encoded = "\"\"\"first\nsecond\"\"\""
  let output = set_value(source, ["message"], encoded).unwrap()
  assert_eq(output, "message = \"\"\"first\nsecond\"\"\" # keep\n")
}

///|
test "set inserts a missing root key before the first table using CRLF" {
  let source = "title = \"demo\"\r\n[package]\r\nname = \"tool\"\r\n"
  let output = set_value(source, ["count"], "2").unwrap()
  assert_eq(
    output, "title = \"demo\"\r\ncount = 2\r\n[package]\r\nname = \"tool\"\r\n",
  )
}

///|
test "set inserts a safely quoted root key segment" {
  let source = "title = \"demo\""
  let output = set_value(source, ["display.name"], "2").unwrap()
  assert_eq(output, "title = \"demo\"\n\"display.name\" = 2\n")
}

///|
test "set inserts at the end of the exact normal table block" {
  let source = "[package]\nname = \"tool\"\n[other]\nname = \"same\"\n"
  let output = set_value(source, ["package", "count"], "2").unwrap()
  assert_eq(
    output, "[package]\nname = \"tool\"\ncount = 2\n[other]\nname = \"same\"\n",
  )
}

///|
test "set inserts a quoted Unicode key at table EOF without concatenation" {
  let source = "[package]\r\nname = \"tool\""
  let output = set_value(source, ["package", "显示名"], "\"工具\"").unwrap()
  assert_eq(
    output, "[package]\r\nname = \"tool\"\r\n\"显示名\" = \"工具\"\r\n",
  )
}

///|
test "remove deletes the target line only" {
  let source = "# configuration\na = 1 # same line\nb = 2\n"
  let output = remove_key(source, ["a"]).unwrap()
  assert_eq(output, "# configuration\nb = 2\n")
}

///|
test "remove deletes a CRLF target line" {
  let source = "a = 1\r\nb = 2 # remove\r\nc = 3\r\n"
  let output = remove_key(source, ["b"]).unwrap()
  assert_eq(output, "a = 1\r\nc = 3\r\n")
}

///|
test "remove deletes an EOF line without a newline" {
  let source = "[table]\nkeep = 1\nremove = 2 # gone"
  let output = remove_key(source, ["table", "remove"]).unwrap()
  assert_eq(output, "[table]\nkeep = 1\n")
}

///|
test "set rejects invalid and injected encoded values" {
  assert_true(set_value("a = 1\n", ["a"], "[") is Err(_))
  assert_true(set_value("a = 1\n", ["a"], "2\ninjected = 3") is Err(_))
  assert_true(set_value("a = 1\n", ["a"], "2\n[table]\nx = 3") is Err(_))
}

///|
test "operations reject scanner errors before producing output" {
  let source = "a = \"unterminated"
  assert_true(set_value(source, ["a"], "2") is Err(_))
  assert_true(remove_key(source, ["a"]) is Err(_))
  assert_eq(source, "a = \"unterminated")
}

///|
test "operations reject an existing array-table key" {
  let source = "[[products]]\nname = \"hammer\"\n"
  assert_true(set_value(source, ["products", "name"], "\"new\"") is Err(_))
  assert_true(remove_key(source, ["products", "name"]) is Err(_))
}

///|
test "set rejects insertion into an array table" {
  let source = "[[products]]\nname = \"hammer\"\n"
  assert_true(set_value(source, ["products", "price"], "2") is Err(_))
}

///|
test "operations reject duplicate matching paths as ambiguous" {
  let source = "a = 1\na = 2\n"
  match set_value(source, ["a"], "3") {
    Err(AmbiguousPath(_)) => ()
    _ => fail("expected ambiguous set error")
  }
  match remove_key(source, ["a"]) {
    Err(AmbiguousPath(_)) => ()
    _ => fail("expected ambiguous remove error")
  }
}

///|
test "remove reports a missing path" {
  match remove_key("a = 1\n", ["missing"]) {
    Err(NotFound(_)) => ()
    _ => fail("expected missing-path error")
  }
}

///|
test "set rejects empty paths and nondeterministic parents" {
  assert_true(set_value("", [], "1") is Err(_))
  assert_true(set_value("[a.b]\nx = 1\n", ["a", "x"], "2") is Err(_))
  assert_true(set_value("[a]\nx = 1\n[a]\ny = 2\n", ["a", "z"], "2") is Err(_))
  assert_true(set_value("title = \"demo\"\n", ["missing", "x"], "2") is Err(_))
}

///|
test "set returns no candidate when the complete result is invalid" {
  let source = "a = 1\na.b = 2\n"
  let result = set_value(source, ["a"], "3")
  assert_true(result is Err(_))
  assert_eq(source, "a = 1\na.b = 2\n")
}
