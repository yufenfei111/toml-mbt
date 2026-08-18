///|
test "decoder tags scalar values" {
  let source = "name = \"MoonBit\"\ncount = 2\nenabled = true\n"
  let output = decode_tagged_json(source).unwrap()
  assert_true(output.contains("\"type\":\"string\""))
  assert_true(output.contains("\"value\":\"MoonBit\""))
  assert_true(output.contains("\"type\":\"integer\""))
  assert_true(output.contains("\"type\":\"bool\""))
}

///|
test "decoder emits every official scalar tag and nested structures" {
  let source = "escaped = \"line\\n\\\"quoted\\\"\"\n" +
    "integer = 42\n" +
    "float = 1.5\n" +
    "bool = false\n" +
    "datetime = 1979-05-27T07:32:00Z\n" +
    "datetime_local = 1979-05-27T07:32:00\n" +
    "date_local = 1979-05-27\n" +
    "time_local = 07:32:00.123\n" +
    "array = [1, \"two\"]\n" +
    "inline = { child = true }\n"
  assert_eq(
    decode_tagged_json(source).unwrap(),
    "{\"array\":[{\"type\":\"integer\",\"value\":\"1\"},{\"type\":\"string\",\"value\":\"two\"}]," +
    "\"bool\":{\"type\":\"bool\",\"value\":\"false\"}," +
    "\"date_local\":{\"type\":\"date-local\",\"value\":\"1979-05-27\"}," +
    "\"datetime\":{\"type\":\"datetime\",\"value\":\"1979-05-27T07:32:00Z\"}," +
    "\"datetime_local\":{\"type\":\"datetime-local\",\"value\":\"1979-05-27T07:32:00\"}," +
    "\"escaped\":{\"type\":\"string\",\"value\":\"line\\n\\\"quoted\\\"\"}," +
    "\"float\":{\"type\":\"float\",\"value\":\"1.5\"}," +
    "\"inline\":{\"child\":{\"type\":\"bool\",\"value\":\"true\"}}," +
    "\"integer\":{\"type\":\"integer\",\"value\":\"42\"}," +
    "\"time_local\":{\"type\":\"time-local\",\"value\":\"07:32:00.123\"}}",
  )
}

///|
test "decoder sorts nested object keys" {
  let source = "[z]\nb = 2\na = 1\n[a]\nz = 3\n"
  assert_eq(
    decode_tagged_json(source).unwrap(),
    "{\"a\":{\"z\":{\"type\":\"integer\",\"value\":\"3\"}}," +
    "\"z\":{\"a\":{\"type\":\"integer\",\"value\":\"1\"}," +
    "\"b\":{\"type\":\"integer\",\"value\":\"2\"}}}",
  )
}

///|
test "decoder rejects invalid TOML" {
  match decode_tagged_json("a = { b = 1, }") {
    Ok(_) => abort("expected decoder error")
    Err(_) => ()
  }
}
