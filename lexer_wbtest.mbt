///|
/// Whitebox tests for the lexer token stream and source positions.

///|
fn kind_of(tokens : Array[Token], i : Int) -> TokenKind {
  tokens[i].kind
}

///|
test "lexer: key value pair" {
  let tokens = Lexer::tokenize("a = 1")
  assert_eq(tokens.length(), 4)
  assert_eq(kind_of(tokens, 0), Word("a"))
  assert_eq(kind_of(tokens, 1), Equal)
  assert_eq(kind_of(tokens, 2), Word("1"))
  assert_eq(kind_of(tokens, 3), EOF)
}

///|
test "lexer: tracks line and column" {
  let tokens = Lexer::tokenize("a = 1\nb = 2")
  // tokens: Word(a) Equal Word(1) Newline Word(b) Equal Word(2) EOF
  assert_eq(tokens[4].line, 2)
  assert_eq(tokens[4].column, 1)
}

///|
test "lexer: skips whitespace" {
  let tokens = Lexer::tokenize("  a\t=  1  ")
  assert_eq(kind_of(tokens, 0), Word("a"))
  assert_eq(kind_of(tokens, 1), Equal)
  assert_eq(kind_of(tokens, 2), Word("1"))
}

///|
test "lexer: skips comments" {
  let tokens = Lexer::tokenize("# comment\na = 1")
  assert_eq(kind_of(tokens, 0), Newline)
  assert_eq(kind_of(tokens, 1), Word("a"))
}

///|
test "lexer: comment to end of line" {
  let tokens = Lexer::tokenize("a = 1 # trailing\nb = 2")
  assert_eq(kind_of(tokens, 0), Word("a"))
  assert_eq(kind_of(tokens, 3), Newline)
  assert_eq(kind_of(tokens, 4), Word("b"))
}

///|
test "lexer: brackets and braces" {
  let tokens = Lexer::tokenize("[a] = { b = [1] }")
  assert_eq(kind_of(tokens, 0), LBracket)
  assert_eq(kind_of(tokens, 1), Word("a"))
  assert_eq(kind_of(tokens, 2), RBracket)
  assert_eq(kind_of(tokens, 3), Equal)
  assert_eq(kind_of(tokens, 4), LBrace)
  assert_eq(kind_of(tokens, 5), Word("b"))
  assert_eq(kind_of(tokens, 6), Equal)
  assert_eq(kind_of(tokens, 7), LBracket)
  assert_eq(kind_of(tokens, 8), Word("1"))
  assert_eq(kind_of(tokens, 9), RBracket)
  assert_eq(kind_of(tokens, 10), RBrace)
}

///|
test "lexer: basic string token" {
  let tokens = Lexer::tokenize("s = \"hello\"")
  assert_eq(kind_of(tokens, 2), Str("hello"))
}

///|
test "lexer: literal string token" {
  let tokens = Lexer::tokenize("s = 'hello'")
  assert_eq(kind_of(tokens, 2), Str("hello"))
}

///|
test "lexer: multiline basic string" {
  let tokens = Lexer::tokenize("s = \"\"\"\nhello\n\"\"\"")
  assert_eq(kind_of(tokens, 2), Str("hello\n"))
}

///|
test "lexer: word with dots stays together" {
  let tokens = Lexer::tokenize("a.b.c = 1")
  assert_eq(kind_of(tokens, 0), Word("a.b.c"))
}

///|
test "lexer: word with number stays together" {
  let tokens = Lexer::tokenize("x = 3.14")
  assert_eq(kind_of(tokens, 2), Word("3.14"))
}

///|
test "lexer: word with datetime stays together" {
  let tokens = Lexer::tokenize("d = 1979-05-27T07:32:00Z")
  assert_eq(kind_of(tokens, 2), Word("1979-05-27T07:32:00Z"))
}

///|
test "lexer: carriage return newline" {
  let tokens = Lexer::tokenize("a = 1\r\nb = 2")
  assert_eq(kind_of(tokens, 3), Newline)
  assert_eq(tokens[4].line, 2)
}

///|
test "lexer: empty input" {
  let tokens = Lexer::tokenize("")
  assert_eq(tokens.length(), 1)
  assert_eq(kind_of(tokens, 0), EOF)
}

///|
test "lexer: string escape produces unescaped value" {
  let tokens = Lexer::tokenize("s = \"a\\tb\"")
  assert_eq(kind_of(tokens, 2), Str("a\tb"))
}

///|
test "lexer: triple quote inside multiline is literal" {
  let tokens = Lexer::tokenize("s = \"\"\"a\"\"b\"\"\"")
  assert_eq(kind_of(tokens, 2), Str("a\"\"b"))
}

///|
test "lexer: unterminated string raises" {
  try Lexer::tokenize("s = \"oops") catch {
    _ => ()
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "lexer: invalid escape raises" {
  try Lexer::tokenize("s = \"\\q\"") catch {
    _ => ()
  } noraise {
    _ => assert_true(false)
  }
}

///|
test "lexer: multiline line-ending backslash trims whitespace" {
  let tokens = Lexer::tokenize(
    "s = \"\"\"\nThe quick brown \\\n  fox jumps\"\"\"",
  )
  assert_eq(kind_of(tokens, 2), Str("The quick brown fox jumps"))
}

///|
test "lexer: word terminates at equals" {
  let tokens = Lexer::tokenize("key=value")
  assert_eq(kind_of(tokens, 0), Word("key"))
  assert_eq(kind_of(tokens, 1), Equal)
  assert_eq(kind_of(tokens, 2), Word("value"))
}

///|
test "lexer: word terminates at comma" {
  let tokens = Lexer::tokenize("a = [1,2]")
  assert_eq(kind_of(tokens, 3), Word("1"))
  assert_eq(kind_of(tokens, 4), Comma)
  assert_eq(kind_of(tokens, 5), Word("2"))
}

///|
test "lexer: token slices stay aligned after a supplementary scalar" {
  let tokens = Lexer::tokenize("emoji = \"😀\"\ntitle = \"new\"\n")
  assert_eq(tokens[4], Token::new(Word("title"), 2, 1))
}
