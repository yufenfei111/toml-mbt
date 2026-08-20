///|
test "scanner preserves CRLF and comments" {
  let source = "# lead\r\nname  =  \"Moon\" # keep\r\n\r\n[tool]\r\ncount=2\r\n"
  let result = scan(source)
  assert_eq(result.errors.length(), 0)
  let document = result.document
  assert_eq(document.statements.length(), 5)
  assert_eq(document.statements[0].text(source), "# lead\r\n")
  assert_eq(document.statements[1].text(source), "name  =  \"Moon\" # keep\r\n")
  assert_eq(document.statements[2].text(source), "\r\n")
  assert_eq(document.statements[3].text(source), "[tool]\r\n")
  assert_eq(document.statements[4].text(source), "count=2\r\n")
  assert_eq(document.statements[1].span.line, 2)
  assert_eq(document.statements[1].span.column, 1)
  assert_eq(document.statements[1].span.start_offset, 8)
  assert_eq(document.statements[1].span.end_offset, 32)
}

///|
test "scanner keeps multiline strings and arrays as single statements" {
  let source = "basic = \"\"\"line # one\nline two\"\"\"\nliteral = '''raw\n# still text'''\nitems = [\n  \"a#b\",\n  2,\n]\n"
  let result = scan(source)
  assert_eq(result.errors.length(), 0)
  let statements = result.document.statements
  assert_eq(statements.length(), 3)
  assert_eq(
    statements[0].text(source),
    "basic = \"\"\"line # one\nline two\"\"\"\n",
  )
  assert_eq(statements[1].text(source), "literal = '''raw\n# still text'''\n")
  assert_eq(statements[2].text(source), "items = [\n  \"a#b\",\n  2,\n]\n")
  assert_eq(statements[0].kind, StatementKind::KeyValue)
  assert_eq(statements[1].kind, StatementKind::KeyValue)
  assert_eq(statements[2].kind, StatementKind::KeyValue)
}

///|
test "scanner recognizes table and array-table headers" {
  let source = "[tool.build] # comment\n[[tool.plugins]]\n"
  let result = scan(source)
  assert_eq(result.errors.length(), 0)
  let statements = result.document.statements
  assert_eq(statements.length(), 2)
  assert_eq(statements[0].kind, StatementKind::TableHeader)
  assert_eq(statements[1].kind, StatementKind::ArrayTableHeader)
  assert_eq(statements[0].text(source), "[tool.build] # comment\n")
  assert_eq(statements[1].text(source), "[[tool.plugins]]\n")
}

///|
test "scanner does not split inside an inline table" {
  let source = "config = {\n  marker = \"# not a comment\",\n  nested = { count = 2 },\n}\nnext = true\n"
  let result = scan(source)
  assert_eq(result.errors.length(), 0)
  let statements = result.document.statements
  assert_eq(statements.length(), 2)
  assert_eq(
    statements[0].text(source),
    "config = {\n  marker = \"# not a comment\",\n  nested = { count = 2 },\n}\n",
  )
  assert_eq(statements[1].text(source), "next = true\n")
}

///|
test "scanner preserves invalid trailing text and reports its span" {
  let source = "name = \"unterminated"
  let result = scan(source)
  assert_eq(result.document.statements.length(), 1)
  let statement = result.document.statements[0]
  assert_eq(statement.kind, StatementKind::Invalid)
  assert_eq(statement.text(source), source)
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].span.start_offset, 0)
  assert_eq(result.errors[0].span.end_offset, source.length())
  assert_eq(result.errors[0].span.line, 1)
  assert_eq(result.errors[0].span.column, 1)
}

///|
test "scanner retains an unterminated array" {
  let source = "items = [\n  1,\n"
  let result = scan(source)
  assert_eq(result.document.statements.length(), 1)
  let statement = result.document.statements[0]
  assert_eq(statement.kind, StatementKind::Invalid)
  assert_eq(statement.text(source), source)
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].message, "unterminated array")
}

///|
test "scanner reports balanced invalid trailing text" {
  let source = "not an assignment"
  let result = scan(source)
  assert_eq(result.document.statements.length(), 1)
  assert_eq(result.document.statements[0].kind, StatementKind::Invalid)
  assert_eq(result.document.statements[0].text(source), source)
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].message, "invalid statement")
}

///|
test "scanner source spans are UTF-8 byte offsets" {
  let source = "title = \"é\"\nnext = 1\n"
  let result = scan(source)
  let statements = result.document.statements
  assert_eq(statements[0].text(source), "title = \"é\"\n")
  assert_eq(statements[0].span.end_offset, 13)
  assert_eq(statements[1].span.start_offset, 13)
}
