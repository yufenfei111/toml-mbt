///|
/// Blackbox tests for the toml-test tagged JSON conversion.

///|
test "to_json tags an integer" {
  let t = @toml-mbt.parse("a = 42\n").unwrap()
  match @toml-mbt.to_json(t) {
    Object(obj) =>
      match obj.get("a") {
        Some(Object(tag)) => {
          assert_eq(tag.get("type"), Some(Json::string("integer")))
          assert_eq(tag.get("value"), Some(Json::string("42")))
        }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "to_json tags a string" {
  let t = @toml-mbt.parse("a = \"hi\"\n").unwrap()
  match @toml-mbt.to_json(t) {
    Object(obj) =>
      match obj.get("a") {
        Some(Object(tag)) => {
          assert_eq(tag.get("type"), Some(Json::string("string")))
          assert_eq(tag.get("value"), Some(Json::string("hi")))
        }
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "to_json tags a boolean" {
  let t = @toml-mbt.parse("a = true\n").unwrap()
  match @toml-mbt.to_json(t) {
    Object(obj) =>
      match obj.get("a") {
        Some(Object(tag)) =>
          assert_eq(tag.get("type"), Some(Json::string("bool")))
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "to_json tags a datetime" {
  let t = @toml-mbt.parse("a = 1979-05-27T07:32:00Z\n").unwrap()
  match @toml-mbt.to_json(t) {
    Object(obj) =>
      match obj.get("a") {
        Some(Object(tag)) =>
          assert_eq(tag.get("type"), Some(Json::string("datetime")))
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}

///|
test "to_json leaves arrays untagged" {
  let t = @toml-mbt.parse("a = [1, 2]\n").unwrap()
  match @toml-mbt.to_json(t) {
    Object(obj) =>
      match obj.get("a") {
        Some(Array(items)) => assert_eq(items.length(), 2)
        _ => assert_true(false)
      }
    _ => assert_true(false)
  }
}
