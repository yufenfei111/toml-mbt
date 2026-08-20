///|
/// Pure command output. No field implies I/O: `proposed_source` tells the
/// native adapter whether a complete, validated replacement is available.
pub struct RunResult {
  stdout : String
  stderr : String
  exit_code : Int
  proposed_source : String?
} derive(Eq, Debug)

///|
priv enum SourceValidation {
  Valid(Map[String, @toml-mbt.Value])
  Invalid(Array[@diagnostics.Diagnostic])
}

///|
fn source_validation(source : String) -> SourceValidation {
  let diagnostics : Array[@diagnostics.Diagnostic] = []
  let scanned = @syntax.scan(source)
  for error in scanned.errors {
    diagnostics.push({
      severity: @diagnostics.Severity::Error,
      code: "WB100",
      message: error.message,
      span: error.span,
      suggestion: None,
    })
  }
  let parsed = @toml-mbt.parse(source)
  match parsed {
    Err(error) => {
      match error {
        @toml-mbt.ParseError(line, column, message) =>
          diagnostics.push({
            severity: @diagnostics.Severity::Error,
            code: "TOML100",
            message,
            span: @syntax.source_span_at_position(source, line, column),
            suggestion: None,
          })
      }
      Invalid(@diagnostics.sort_diagnostics(diagnostics))
    }
    Ok(table) =>
      if diagnostics.length() == 0 {
        Valid(table)
      } else {
        Invalid(@diagnostics.sort_diagnostics(diagnostics))
      }
  }
}

///|
fn success(stdout : String, proposed_source : String?) -> RunResult {
  { stdout, stderr: "", exit_code: 0, proposed_source }
}

///|
fn failure(message : String) -> RunResult {
  { stdout: "", stderr: message, exit_code: 1, proposed_source: None }
}

///|
fn diagnostic_failure(
  file : String,
  source : String,
  diagnostics : Array[@diagnostics.Diagnostic],
  json : Bool,
) -> RunResult {
  if json {
    {
      stdout: @diagnostics.render_json(diagnostics),
      stderr: "",
      exit_code: 1,
      proposed_source: None,
    }
  } else {
    let rendered : Array[String] = []
    for diagnostic in diagnostics {
      rendered.push(@diagnostics.render_text(file, source, diagnostic))
    }
    failure(rendered.join("\n"))
  }
}

///|
fn run_check(file : String, json : Bool, source : String) -> RunResult {
  match source_validation(source) {
    Valid(_) => success("", None)
    Invalid(diagnostics) => diagnostic_failure(file, source, diagnostics, json)
  }
}

///|
priv enum LookupError {
  Missing
  Ambiguous
  NonTable
}

///|
fn contains_only_tables(values : Array[@toml-mbt.Value]) -> Bool {
  if values.length() == 0 {
    return false
  }
  for value in values {
    match value {
      @toml-mbt.Table(_) => ()
      _ => return false
    }
  }
  true
}

///|
fn lookup_nested(
  value : @toml-mbt.Value,
  path : Array[String],
  index : Int,
) -> Result[@toml-mbt.Value, LookupError] {
  if index == path.length() {
    return Ok(value)
  }
  match value {
    @toml-mbt.Table(table) =>
      match table.get(path[index]) {
        Some(next) => lookup_nested(next, path, index + 1)
        None => Err(Missing)
      }
    @toml-mbt.Array(values) =>
      if !contains_only_tables(values) {
        Err(NonTable)
      } else if values.length() == 1 {
        lookup_nested(values[0], path, index)
      } else {
        Err(Ambiguous)
      }
    _ => Err(NonTable)
  }
}

///|
fn lookup_value(
  table : Map[String, @toml-mbt.Value],
  path : Array[String],
) -> Result[@toml-mbt.Value, LookupError] {
  if path.length() == 0 {
    return Err(Missing)
  }
  match table.get(path[0]) {
    Some(value) => lookup_nested(value, path, 1)
    None => Err(Missing)
  }
}

///|
fn render_path(path : Array[String]) -> String {
  let segments : Array[String] = []
  for segment in path {
    segments.push(Json::string(segment).stringify())
  }
  "[" + segments.join(",") + "]"
}

///|
fn run_get(file : String, path : Array[String], source : String) -> RunResult {
  match source_validation(source) {
    Invalid(diagnostics) => diagnostic_failure(file, source, diagnostics, false)
    Valid(table) =>
      if path.length() == 0 {
        failure(
          "error[WB202]: invalid key path: key path must contain at least one segment",
        )
      } else {
        match lookup_value(table, path) {
          Err(Missing) =>
            failure("error[WB200]: key not found: " + render_path(path))
          Err(Ambiguous) =>
            failure("error[WB201]: ambiguous key path: " + render_path(path))
          Err(NonTable) =>
            failure(
              "error[WB202]: key path crosses a non-table value: " +
              render_path(path),
            )
          Ok(value) => success(@toml-mbt.encode_tagged_value(value), None)
        }
      }
  }
}

///|
fn edit_error_message(error : @edit.EditError) -> String {
  match error {
    @edit.InvalidRange(start, end) =>
      "invalid edit range: " + start.to_string() + ".." + end.to_string()
    @edit.OutOfBounds(start, end) =>
      "edit range is out of bounds: " +
      start.to_string() +
      ".." +
      end.to_string()
    @edit.Overlap(left, right) =>
      "overlapping edit ranges: " +
      left.start_offset.to_string() +
      ".." +
      left.end_offset.to_string() +
      " and " +
      right.start_offset.to_string() +
      ".." +
      right.end_offset.to_string()
  }
}

///|
fn operation_failure(error : @edit.OperationError) -> RunResult {
  match error {
    @edit.InvalidPath(message) =>
      failure("error[WB202]: invalid key path: " + sanitize_argument(message))
    @edit.InvalidValue(message) =>
      failure("error[WB203]: invalid TOML value: " + sanitize_argument(message))
    @edit.NotFound(path) =>
      failure("error[WB200]: key not found: " + render_path(path))
    @edit.AmbiguousPath(path) =>
      failure("error[WB201]: ambiguous key path: " + render_path(path))
    @edit.UnsupportedInsertion(path) =>
      failure("error[WB204]: unsupported insertion path: " + render_path(path))
    @edit.ResultIsInvalid(message) =>
      failure(
        "error[WB205]: invalid edit result: " + sanitize_argument(message),
      )
    @edit.TextEdit(error) =>
      failure("error[WB206]: text edit failed: " + edit_error_message(error))
  }
}

///|
fn proposed(result : Result[String, @edit.OperationError]) -> RunResult {
  match result {
    Ok(source) => success(source, Some(source))
    Err(error) => operation_failure(error)
  }
}

///|
/// Executes a parsed command solely against supplied source text. `write` is
/// intentionally ignored here and remains metadata for the native adapter.
pub fn run(command : Command, source : String) -> RunResult {
  match command {
    Check(file~, json~) => run_check(file, json, source)
    Get(file~, path~) => run_get(file, path, source)
    Set(path~, encoded~, ..) => proposed(@edit.set_value(source, path, encoded))
    Remove(path~, ..) => proposed(@edit.remove_key(source, path))
  }
}
