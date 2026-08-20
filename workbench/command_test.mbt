///|
test "parse check commands with an optional final JSON flag" {
  assert_eq(
    parse_args(["check", "config.toml"]),
    Ok(Check(file="config.toml", json=false)),
  )
  assert_eq(
    parse_args(["check", "config.toml", "--json"]),
    Ok(Check(file="config.toml", json=true)),
  )
}

///|
test "parse get with TOML quoted path segments" {
  assert_eq(
    parse_args(["get", "config.toml", "package.\"display.name\""]),
    Ok(Get(file="config.toml", path=["package", "display.name"])),
  )
}

///|
test "parse set keeps the encoded TOML value in one argument" {
  assert_eq(
    parse_args(["set", "config.toml", "items", "[1, 2]"]),
    Ok(Set(file="config.toml", path=["items"], encoded="[1, 2]", write=false)),
  )
  assert_eq(
    parse_args(["set", "config.toml", "package.name", "\"changed\"", "--write"]),
    Ok(
      Set(
        file="config.toml",
        path=["package", "name"],
        encoded="\"changed\"",
        write=true,
      ),
    ),
  )
}

///|
test "parse remove with an optional final write flag" {
  assert_eq(
    parse_args(["remove", "config.toml", "obsolete"]),
    Ok(Remove(file="config.toml", path=["obsolete"], write=false)),
  )
  assert_eq(
    parse_args(["remove", "config.toml", "obsolete", "--write"]),
    Ok(Remove(file="config.toml", path=["obsolete"], write=true)),
  )
}

///|
test "reject unknown commands and missing positional arguments" {
  assert_eq(parse_args([]), Err(MissingArgument("command")))
  assert_eq(parse_args(["lint"]), Err(UnknownCommand("lint")))
  assert_eq(parse_args(["check"]), Err(MissingArgument("file")))
  assert_eq(parse_args(["get", "config.toml"]), Err(MissingArgument("path")))
  assert_eq(
    parse_args(["set", "config.toml", "name"]),
    Err(MissingArgument("toml-value")),
  )
  assert_eq(parse_args(["remove", "config.toml"]), Err(MissingArgument("path")))
}

///|
test "reject extra and unsupported arguments" {
  assert_eq(
    parse_args(["check", "config.toml", "extra"]),
    Err(UnexpectedArgument("extra")),
  )
  assert_eq(
    parse_args(["get", "config.toml", "name", "--json"]),
    Err(UnexpectedArgument("--json")),
  )
  assert_eq(
    parse_args(["set", "config.toml", "name", "1", "--json"]),
    Err(UnexpectedArgument("--json")),
  )
  assert_eq(
    parse_args(["remove", "config.toml", "name", "--json"]),
    Err(UnexpectedArgument("--json")),
  )
}

///|
test "reject duplicate supported flags before other argument errors" {
  assert_eq(
    parse_args(["check", "config.toml", "--json", "--json"]),
    Err(DuplicateFlag("--json")),
  )
  assert_eq(
    parse_args(["set", "config.toml", "name", "1", "--write", "--write"]),
    Err(DuplicateFlag("--write")),
  )
  assert_eq(
    parse_args(["remove", "config.toml", "--write", "name", "--write"]),
    Err(DuplicateFlag("--write")),
  )
}

///|
test "reject known flags outside their documented final positions" {
  assert_eq(
    parse_args(["check", "--json", "config.toml"]),
    Err(UnexpectedArgument("--json")),
  )
  assert_eq(
    parse_args(["set", "config.toml", "--write", "1"]),
    Err(UnexpectedArgument("--write")),
  )
  assert_eq(
    parse_args(["remove", "--write", "name"]),
    Err(UnexpectedArgument("--write")),
  )
}

///|
test "reject invalid paths and flag-shaped positional arguments" {
  assert_true(
    parse_args(["get", "config.toml", "one..two"]) is Err(InvalidPath(_)),
  )
  assert_eq(
    parse_args(["get", "--unknown", "name"]),
    Err(UnexpectedArgument("--unknown")),
  )
  assert_eq(
    parse_args(["set", "config.toml", "name", "--unknown"]),
    Err(UnexpectedArgument("--unknown")),
  )
}

///|
test "command errors have stable sanitized adapter messages and exit status" {
  assert_eq(CommandError::MissingArgument("file").exit_code(), 2)
  assert_eq(
    CommandError::UnexpectedArgument("bad\nargument").to_string(),
    "unexpected argument: bad\\nargument",
  )
  assert_true(usage().contains("check <file> [--json]"))
}

///|
test "every command error renders one sanitized line with exit status two" {
  let cases : Array[(CommandError, String)] = [
    (UnknownCommand("bad\ncommand"), "unknown command: bad\\ncommand"),
    (MissingArgument("file\nname"), "missing argument: file\\nname"),
    (UnexpectedArgument("bad\targument"), "unexpected argument: bad\\targument"),
    (DuplicateFlag("--json\r"), "duplicate flag: --json\\r"),
    (InvalidPath("bad\u0001path"), "invalid path: bad\\u{1}path"),
  ]
  for item in cases {
    let (error, expected) = item
    assert_eq(error.to_string(), expected)
    assert_eq(error.exit_code(), 2)
    assert_eq(error.to_string().split("\n").to_array().length(), 1)
  }
}
