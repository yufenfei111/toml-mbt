///|
fn diagnostic(code : String, span : @syntax.SourceSpan) -> Diagnostic {
  diagnostic_with_message(code, "problem", span)
}

///|
fn diagnostic_with_message(
  code : String,
  message : String,
  span : @syntax.SourceSpan,
) -> Diagnostic {
  { severity: Severity::Error, code, message, span, suggestion: None }
}

///|
test "sort diagnostics by byte range and code without mutating the input" {
  let spans = @syntax.scan("a = 1\nlonger = 2\nx = 3\n").document.statements
  let items = [
    diagnostic("WB201", spans[2].span),
    diagnostic("TOML100", spans[0].span),
    diagnostic("WB100", spans[0].span),
    diagnostic("WB201", spans[1].span),
  ]
  let sorted = sort_diagnostics(items)
  assert_eq(sorted.map(item => item.code), [
    "TOML100", "WB100", "WB201", "WB201",
  ])
  assert_eq(items.map(item => item.code), ["WB201", "TOML100", "WB100", "WB201"])
}

///|
test "sort diagnostics preserves caller order for identical sort keys" {
  let source_span = @syntax.scan("key = 1\n").document.statements[0].span
  let items = [
    diagnostic_with_message("WB100", "first", source_span),
    diagnostic_with_message("WB100", "second", source_span),
    diagnostic_with_message("WB100", "third", source_span),
  ]
  let sorted = sort_diagnostics(items)
  assert_eq(sorted.map(item => item.message), ["first", "second", "third"])
  assert_eq(items.map(item => item.message), ["first", "second", "third"])
}

///|
test "text rendering shows file position severity code message and one CRLF source line" {
  let source = "title = 1\r\nnext = 2\r\n"
  let source_span = @syntax.scan(source).document.statements[1].span
  let item : Diagnostic = {
    severity: Severity::Error,
    code: "WB100",
    message: "unreadable path",
    span: source_span,
    suggestion: None,
  }
  let output = render_text("config.toml", source, item)
  assert_true(output.contains("config.toml:2:1: error[WB100]: unreadable path"))
  assert_true(output.contains("next = 2"))
  assert_true(output.contains("^^^^"))
  assert_true(!output.contains("\r"))
}

///|
test "text rendering sanitizes header controls without adding physical lines" {
  let source_span = @syntax.scan("x = ]").errors[0].span
  let item : Diagnostic = {
    severity: Severity::Error,
    code: "WB\t100\nnext",
    message: "badé\rmessage\u0001\u007F",
    span: source_span,
    suggestion: None,
  }
  let output = render_text("configé\r\ninjected.toml", "x = ]", item)
  assert_eq(output.split("\n").to_array().length(), 3)
  assert_true(output.contains("configé\\r\\ninjected.toml"))
  assert_true(output.contains("WB\\t100\\nnext"))
  assert_true(output.contains("badé\\rmessage\\u{1}\\u{7f}"))
}

///|
test "text rendering expands tabs at four-column stops for excerpts and carets" {
  let invalid_source = "\tkey\t= ]\n"
  let invalid_span = @syntax.scan(invalid_source).errors[0].span
  let invalid : Diagnostic = {
    severity: Severity::Error,
    code: "WB100",
    message: "unmatched closing delimiter",
    span: invalid_span,
    suggestion: None,
  }
  let invalid_output = render_text("tabs.toml", invalid_source, invalid)
  assert_true(invalid_output.contains("\n    key = ]\n          ^"))

  let multiline_source = "\tvalue = [\t]\n"
  let multiline_span = @syntax.scan(multiline_source).document.statements[0].span
  let multiline : Diagnostic = {
    severity: Severity::Error,
    code: "TOML100",
    message: "invalid array",
    span: multiline_span,
    suggestion: None,
  }
  let multiline_output = render_text("tabs.toml", multiline_source, multiline)
  assert_true(
    multiline_output.contains("\n    value = [   ]\n^^^^^^^^^^^^^^^^^"),
  )
}

///|
test "JSON rendering parses with numeric offsets and escaped structured suggestions" {
  let source_span = @syntax.scan("key = 1\n").document.statements[0].span
  let item : Diagnostic = {
    severity: Severity::Warning,
    code: "WB201",
    message: "cannot edit \"value\"\\line\nnext\t",
    span: source_span,
    suggestion: Some({ span: source_span, replacement: "new\"value\\line\r\n" }),
  }
  let output = render_json([item])
  let parsed = @json.parse(output)
  match parsed {
    Array(items) => {
      assert_eq(items.length(), 1)
      match items[0] {
        Object(fields) => {
          assert_eq(fields["severity"], Json::string("warning"))
          assert_eq(fields["code"], Json::string("WB201"))
          assert_eq(
            fields["message"],
            Json::string("cannot edit \"value\"\\line\nnext\t"),
          )
          match fields["span"] {
            Object(span) => {
              assert_eq(span["start_offset"], Json::number(0.0))
              assert_eq(span["end_offset"], Json::number(8.0))
              assert_eq(span["line"], Json::number(1.0))
              assert_eq(span["column"], Json::number(1.0))
            }
            _ => fail("expected structured span")
          }
          match fields["suggestion"] {
            Object(suggestion) => {
              assert_eq(
                suggestion["replacement"],
                Json::string("new\"value\\line\r\n"),
              )
              match suggestion["span"] {
                Object(span) => {
                  assert_eq(span["start_offset"], Json::number(0.0))
                  assert_eq(span["end_offset"], Json::number(8.0))
                }
                _ => fail("expected suggested span")
              }
            }
            _ => fail("expected structured suggestion")
          }
        }
        _ => fail("expected diagnostic object")
      }
    }
    _ => fail("expected diagnostic array")
  }
}

///|
test "text rendering keeps multiline UTF-8 source spans on one physical line" {
  let source = "items = [\n  \"é\",\n]\n"
  let source_span = @syntax.scan(source).document.statements[0].span
  let item : Diagnostic = {
    severity: Severity::Error,
    code: "TOML100",
    message: "invalid array",
    span: source_span,
    suggestion: None,
  }
  let output = render_text("unicode.toml", source, item)
  assert_true(output.contains("items = ["))
  assert_true(!output.contains("  \"é\","))
  assert_true(output.contains("^^^^^^^^^"))
}

///|
test "JSON rendering uses null when no suggestion is supplied" {
  let source_span = @syntax.scan("x = ]").errors[0].span
  let item : Diagnostic = {
    severity: Severity::Error,
    code: "WB100",
    message: "unmatched closing delimiter",
    span: source_span,
    suggestion: None,
  }
  match @json.parse(render_json([item])) {
    Array(items) =>
      match items[0] {
        Object(fields) => assert_true(fields["suggestion"] is Null)
        _ => fail("expected diagnostic object")
      }
    _ => fail("expected diagnostic array")
  }
}
