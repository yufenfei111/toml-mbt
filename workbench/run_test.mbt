///|
test "check accepts valid TOML without adding output bytes" {
  let plain = run(Check(file="config.toml", json=false), "name = \"MoonBit\"\n")
  assert_eq(plain.stdout, "")
  assert_eq(plain.stderr, "")
  assert_eq(plain.exit_code, 0)
  assert_eq(plain.proposed_source, None)
  let structured = run(
    Check(file="config.toml", json=true),
    "name = \"MoonBit\"\n",
  )
  assert_eq(structured.stdout, "")
  assert_eq(structured.stderr, "")
  assert_eq(structured.exit_code, 0)
}

///|
test "check reports semantic failures as human TOML100 diagnostics" {
  let result = run(
    Check(file="bad\nname.toml", json=false),
    "name = 1\nname = 2\n",
  )
  assert_eq(result.stdout, "")
  assert_eq(result.exit_code, 1)
  assert_true(result.stderr.contains("bad\\nname.toml:"))
  assert_true(result.stderr.contains("error[TOML100]: duplicate key"))
  assert_true(!result.stderr.has_suffix("\n"))
  assert_eq(result.proposed_source, None)
}

///|
test "check JSON reports scan and semantic failures on stdout only" {
  let result = run(Check(file="bad.toml", json=true), "value = ]")
  assert_eq(result.stderr, "")
  assert_eq(result.exit_code, 1)
  match @json.parse(result.stdout) {
    Array(items) => {
      assert_eq(items.length(), 2)
      match (items[0], items[1]) {
        (Object(first), Object(second)) => {
          assert_eq(first["code"], Json::string("TOML100"))
          assert_eq(second["code"], Json::string("WB100"))
        }
        _ => fail("expected structured diagnostics")
      }
    }
    _ => fail("expected diagnostic array")
  }
}

///|
test "semantic error positions map through CRLF and UTF-8 to byte offsets" {
  let result = run(Check(file="utf8.toml", json=true), "a = 1\r\n\"é\" = nope")
  match @json.parse(result.stdout) {
    Array([Object(item)]) =>
      match item["span"] {
        Object(span) => {
          assert_eq(span["start_offset"], Json::number(18.0))
          assert_eq(span["end_offset"], Json::number(18.0))
          assert_eq(span["line"], Json::number(2.0))
          assert_eq(span["column"], Json::number(11.0))
        }
        _ => fail("expected semantic diagnostic span")
      }
    _ => fail("expected one semantic diagnostic")
  }
}

///|
test "get emits the selected semantic value as compact tagged JSON" {
  let result = run(
    Get(file="config.toml", path=["package", "count"]),
    "[package]\ncount = 42\n",
  )
  assert_eq(result.stdout, "{\"type\":\"integer\",\"value\":\"42\"}")
  assert_eq(result.stderr, "")
  assert_eq(result.exit_code, 0)
  assert_eq(result.proposed_source, None)
  assert_true(!result.stdout.has_suffix("\n"))
}

///|
test "get emits nested tables and complete arrays of tables" {
  let table = run(
    Get(file="config.toml", path=["package"]),
    "[package]\nz = 1\na = 2\n",
  )
  assert_eq(
    table.stdout,
    "{\"a\":{\"type\":\"integer\",\"value\":\"2\"}," +
    "\"z\":{\"type\":\"integer\",\"value\":\"1\"}}",
  )
  let array = run(
    Get(file="config.toml", path=["products"]),
    "[[products]]\nname = \"hammer\"\n[[products]]\nname = \"nail\"\n",
  )
  match @json.parse(array.stdout) {
    Array(items) => assert_eq(items.length(), 2)
    _ => fail("expected tagged array-of-tables")
  }
  assert_eq(array.exit_code, 0)
}

///|
test "get traverses one array table but rejects ambiguous traversal" {
  let unique = run(
    Get(file="config.toml", path=["products", "name"]),
    "[[products]]\nname = \"hammer\"\n",
  )
  assert_eq(unique.stdout, "{\"type\":\"string\",\"value\":\"hammer\"}")
  let ambiguous = run(
    Get(file="config.toml", path=["products", "name"]),
    "[[products]]\nname = \"hammer\"\n[[products]]\nname = \"nail\"\n",
  )
  assert_eq(ambiguous.stdout, "")
  assert_eq(
    ambiguous.stderr,
    "error[WB201]: ambiguous key path: [\"products\",\"name\"]",
  )
  assert_eq(ambiguous.exit_code, 1)
  assert_eq(ambiguous.proposed_source, None)
}

///|
test "get distinguishes missing and non-table paths" {
  let missing = run(
    Get(file="config.toml", path=["missing"]),
    "name = \"value\"\n",
  )
  assert_eq(missing.stderr, "error[WB200]: key not found: [\"missing\"]")
  let non_table = run(
    Get(file="config.toml", path=["name", "child"]),
    "name = \"value\"\n",
  )
  assert_eq(
    non_table.stderr,
    "error[WB202]: key path crosses a non-table value: [\"name\",\"child\"]",
  )
  assert_eq(non_table.exit_code, 1)
}

///|
test "set returns the complete proposed TOML without acting on write" {
  let source = "title  =  \"old\" # keep\n"
  for write in [false, true] {
    let result = run(
      Set(file="config.toml", path=["title"], encoded="\"new\"", write~),
      source,
    )
    assert_eq(result.stdout, "title  =  \"new\" # keep\n")
    assert_eq(result.stderr, "")
    assert_eq(result.exit_code, 0)
    assert_eq(result.proposed_source, Some("title  =  \"new\" # keep\n"))
  }
}

///|
test "remove returns the complete proposed TOML without acting on write" {
  let result = run(
    Remove(file="config.toml", path=["obsolete"], write=true),
    "keep = 1\nobsolete = 2 # remove\n",
  )
  assert_eq(result.stdout, "keep = 1\n")
  assert_eq(result.stderr, "")
  assert_eq(result.exit_code, 0)
  assert_eq(result.proposed_source, Some("keep = 1\n"))
}

///|
test "edit failures use stable codes and never expose a proposal" {
  let invalid_path = run(
    Set(file="config.toml", path=[], encoded="1", write=false),
    "a = 1\n",
  )
  assert_eq(
    invalid_path.stderr,
    "error[WB202]: invalid key path: key path must contain at least one segment",
  )
  let invalid_value = run(
    Set(file="config.toml", path=["a"], encoded="]", write=false),
    "a = 1\n",
  )
  assert_true(
    invalid_value.stderr.has_prefix("error[WB203]: invalid TOML value:"),
  )
  let unsupported = run(
    Set(file="config.toml", path=["missing", "child"], encoded="1", write=false),
    "a = 1\n",
  )
  assert_eq(
    unsupported.stderr,
    "error[WB204]: unsupported insertion path: [\"missing\",\"child\"]",
  )
  let not_found = run(
    Remove(file="config.toml", path=["missing"], write=false),
    "a = 1\n",
  )
  assert_eq(not_found.stderr, "error[WB200]: key not found: [\"missing\"]")
  for result in [invalid_path, invalid_value, unsupported, not_found] {
    assert_eq(result.stdout, "")
    assert_eq(result.exit_code, 1)
    assert_eq(result.proposed_source, None)
  }
}

///|
test "edit ambiguity and invalid source failures have stable mappings" {
  let ambiguous = run(
    Remove(file="config.toml", path=["products", "name"], write=false),
    "[[products]]\nname = \"hammer\"\n[[products]]\nname = \"nail\"\n",
  )
  assert_eq(
    ambiguous.stderr,
    "error[WB201]: ambiguous key path: [\"products\",\"name\"]",
  )
  let invalid_source = run(
    Remove(file="config.toml", path=["a"], write=false),
    "a = ]",
  )
  assert_true(
    invalid_source.stderr.has_prefix("error[WB205]: invalid edit result:"),
  )
  assert_eq(ambiguous.proposed_source, None)
  assert_eq(invalid_source.proposed_source, None)
}
