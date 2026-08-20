///|
fn diagnostic(code : String, span : @syntax.SourceSpan) -> Diagnostic {
  {
    severity: Severity::Error,
    code,
    message: "problem",
    span,
    suggestion: None,
  }
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
