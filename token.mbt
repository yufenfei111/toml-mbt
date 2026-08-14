///|
/// The lexical kind of a token produced by the lexer.
pub enum TokenKind {
  /// A bare token: an identifier, number, or date-time candidate. The raw
  /// source text is kept so the parser can interpret it by context.
  Word(String)
  /// A quoted string (basic, literal, or multiline), already unescaped.
  Str(String)
  Equal
  Comma
  LBracket
  RBracket
  LBrace
  RBrace
  Newline
  EOF
} derive(Debug, Eq)

///|
/// A token together with its 1-based source position (line and column).
pub struct Token {
  kind : TokenKind
  line : Int
  column : Int
} derive(Debug, Eq)

///|
/// Constructs a token at the given 1-based line and column.
pub fn Token::new(kind : TokenKind, line : Int, column : Int) -> Token {
  { kind, line, column }
}
