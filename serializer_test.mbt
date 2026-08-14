///|
/// Blackbox tests for the serializer and round-trip behavior.

///|
test "serialize scalar values" {
  let t = @toml-mbt.parse("a = 1\nb = \"x\"\nc = true\n").unwrap()
  assert_eq(@toml-mbt.serialize(t), "a = 1\nb = \"x\"\nc = true")
}

///|
test "serialize quoted key" {
  let t = @toml-mbt.parse("\"a b\" = 1\n").unwrap()
  assert_eq(@toml-mbt.serialize(t), "\"a b\" = 1")
}

///|
test "serialize nested table as header" {
  let t = @toml-mbt.parse("[server]\nport = 8080\n").unwrap()
  let out = @toml-mbt.serialize(t)
  assert_true(out.contains("[server]"))
  assert_true(out.contains("port = 8080"))
}

///|
test "serialize array" {
  let t = @toml-mbt.parse("nums = [1, 2, 3]\n").unwrap()
  assert_eq(@toml-mbt.serialize(t), "nums = [1, 2, 3]")
}

///|
test "serialize inline table" {
  let t = @toml-mbt.parse("p = { x = 1, y = 2 }\n").unwrap()
  let out = @toml-mbt.serialize(t)
  assert_true(out.contains("x = 1"))
  assert_true(out.contains("y = 2"))
}

///|
test "round-trip scalar document" {
  let text = "a = 1\nb = 2.5\nc = \"x\"\nd = false\n"
  let t = @toml-mbt.parse(text).unwrap()
  assert_eq(@toml-mbt.parse(@toml-mbt.serialize(t)).unwrap(), t)
}

///|
test "round-trip nested tables" {
  let text = "[a]\nx = 1\n[a.b]\ny = 2\n"
  let t = @toml-mbt.parse(text).unwrap()
  assert_eq(@toml-mbt.parse(@toml-mbt.serialize(t)).unwrap(), t)
}

///|
test "round-trip array of tables" {
  let text = "[[p]]\nn = \"a\"\n[[p]]\nn = \"b\"\n"
  let t = @toml-mbt.parse(text).unwrap()
  assert_eq(@toml-mbt.parse(@toml-mbt.serialize(t)).unwrap(), t)
}

///|
test "round-trip datetime" {
  let text = "d = 1979-05-27\n"
  let t = @toml-mbt.parse(text).unwrap()
  assert_eq(@toml-mbt.parse(@toml-mbt.serialize(t)).unwrap(), t)
}
