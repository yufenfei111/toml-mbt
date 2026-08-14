///|
/// A TOML parse error carrying a 1-based source position and a description.
///
/// `line` and `column` locate the error in the input; `message` describes it.
pub suberror TomlError {
  ParseError(Int, Int, String)
} derive(Debug)

///|
/// Constructs a `TomlError` at the given 1-based line and column.
pub fn TomlError::new(line : Int, column : Int, message : String) -> TomlError {
  ParseError(line, column, message)
}

///|
/// Renders the error as `line N, column M: message`.
impl Show for TomlError with fn output(self : TomlError, logger) {
  match self {
    ParseError(line, column, message) =>
      logger.write_string("line \{line}, column \{column}: \{message}")
  }
}
