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
/// A key/value statement indexed by its decoded TOML key path.
pub struct KeyValueEntry {
  path : Array[String]
  key_span : SourceSpan
  value_span : SourceSpan
  line_span : SourceSpan
  table_span : SourceSpan?
  editable : Bool
} derive(Debug)

///|
/// One explicit table header and the source block governed by it.
///
/// `end_offset` is the UTF-8 byte offset of the next table header or EOF.
/// Normal tables nested below an array table remain discoverable but are not
/// editable, because their instance is not uniquely determined.
pub struct TableBlock {
  path : Array[String]
  header_span : SourceSpan
  end_offset : Int
  array : Bool
  editable : Bool
} derive(Debug)

///|
/// The scanner's lossless view of one source document.
pub struct Document {
  source : String
  statements : Array[Statement]
  entries : Array[KeyValueEntry]
  tables : Array[TableBlock]
}

///|
/// The non-throwing result of scanning a TOML source document.
pub struct ScanResult {
  document : Document
  errors : Array[SyntaxError]
}
