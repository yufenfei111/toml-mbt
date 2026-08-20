///|
/// A half-open byte range in the original UTF-8 source, with the 1-based
/// position at which the range begins.
pub struct SourceSpan {
  start_offset : Int
  end_offset : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// A scanning problem that still leaves the original source available to
/// diagnostics and format-preserving tools.
pub struct SyntaxError {
  message : String
  span : SourceSpan
} derive(Eq, Debug)

///|
/// The coarse source form of a top-level TOML statement.
pub(all) enum StatementKind {
  Trivia
  KeyValue
  TableHeader
  ArrayTableHeader
  Invalid
} derive(Eq, Debug)

///|
/// A lossless top-level statement in a TOML document.
pub struct Statement {
  kind : StatementKind
  span : SourceSpan
} derive(Eq, Debug)

///|
/// The scanner's lossless view of one source document.
pub struct Document {
  source : String
  statements : Array[Statement]
}

///|
/// The non-throwing result of scanning a TOML source document.
pub struct ScanResult {
  document : Document
  errors : Array[SyntaxError]
}
