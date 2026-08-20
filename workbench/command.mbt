///|
/// A fully parsed Workbench command. File contents are deliberately absent;
/// the native adapter supplies them separately to `run`.
pub(all) enum Command {
  Check(file~ : String, json~ : Bool)
  Get(file~ : String, path~ : Array[String])
  Set(file~ : String, path~ : Array[String], encoded~ : String, write~ : Bool)
  Remove(file~ : String, path~ : Array[String], write~ : Bool)
} derive(Eq, Debug)

///|
/// Deterministic command-line validation failures.
pub(all) enum CommandError {
  UnknownCommand(String)
  MissingArgument(String)
  UnexpectedArgument(String)
  DuplicateFlag(String)
  InvalidPath(String)
} derive(Eq, Debug)

///|
/// Canonical usage text used by the native adapter.
pub fn usage() -> String {
  "usage:\n" +
  "  toml-workbench check <file> [--json]\n" +
  "  toml-workbench get <file> <key.path>\n" +
  "  toml-workbench set <file> <key.path> <toml-value> [--write]\n" +
  "  toml-workbench remove <file> <key.path> [--write]"
}

///|
/// Argument errors are adapter/usage failures, distinct from source or edit
/// failures returned by `run`.
pub fn CommandError::exit_code(_self : CommandError) -> Int {
  2
}

///|
/// Renders a single-line message. Untrusted argv text cannot inject terminal
/// lines or raw control characters.
pub fn CommandError::to_string(self : CommandError) -> String {
  match self {
    UnknownCommand(command) => "unknown command: " + sanitize_argument(command)
    MissingArgument(argument) =>
      "missing argument: " + sanitize_argument(argument)
    UnexpectedArgument(argument) =>
      "unexpected argument: " + sanitize_argument(argument)
    DuplicateFlag(flag) => "duplicate flag: " + sanitize_argument(flag)
    InvalidPath(message) => "invalid path: " + sanitize_argument(message)
  }
}

///|
fn sanitize_argument(value : String) -> String {
  let output = StringBuilder(size_hint=value.length())
  for character in value {
    match character {
      '\r' => output.write_string("\\r")
      '\n' => output.write_string("\\n")
      '\t' => output.write_string("\\t")
      _ => {
        let code = character.to_int()
        if unsafe_human_control(code) {
          output.write_string("\\u{")
          output.write_string(code.to_string(radix=16))
          output.write_char('}')
        } else {
          output.write_char(character)
        }
      }
    }
  }
  output.to_string()
}

///|
fn unsafe_human_control(code : Int) -> Bool {
  code < 0x20 ||
  (code >= 0x7F && code <= 0x9F) ||
  code == 0x061C ||
  code == 0x200E ||
  code == 0x200F ||
  code == 0x2028 ||
  code == 0x2029 ||
  (code >= 0x202A && code <= 0x202E) ||
  (code >= 0x2066 && code <= 0x2069)
}

///|
fn parse_path(argument : String) -> Result[Array[String], CommandError] {
  match @syntax.parse_key_path(argument) {
    Ok(path) => Ok(path)
    Err(error) => Err(InvalidPath(error.message))
  }
}

///|
fn parse_check(args : Array[String]) -> Result[Command, CommandError] {
  if args.length() < 2 {
    return Err(MissingArgument("file"))
  }
  if args.length() == 2 {
    return Ok(Check(file=args[1], json=false))
  }
  if args[2] != "--json" {
    return Err(UnexpectedArgument(args[2]))
  }
  if args.length() > 3 {
    return if args[3] == "--json" {
      Err(DuplicateFlag("--json"))
    } else {
      Err(UnexpectedArgument(args[3]))
    }
  }
  Ok(Check(file=args[1], json=true))
}

///|
fn parse_get(args : Array[String]) -> Result[Command, CommandError] {
  if args.length() < 2 {
    return Err(MissingArgument("file"))
  }
  if args.length() < 3 {
    return Err(MissingArgument("path"))
  }
  if args.length() > 3 {
    return Err(UnexpectedArgument(args[3]))
  }
  match parse_path(args[2]) {
    Ok(path) => Ok(Get(file=args[1], path~))
    Err(error) => Err(error)
  }
}

///|
fn parse_set(args : Array[String]) -> Result[Command, CommandError] {
  if args.length() < 2 {
    return Err(MissingArgument("file"))
  }
  if args.length() < 3 {
    return Err(MissingArgument("path"))
  }
  if args.length() < 4 {
    return Err(MissingArgument("toml-value"))
  }
  let write = if args.length() == 4 {
    false
  } else {
    if args[4] != "--write" {
      return Err(UnexpectedArgument(args[4]))
    }
    if args.length() > 5 {
      return if args[5] == "--write" {
        Err(DuplicateFlag("--write"))
      } else {
        Err(UnexpectedArgument(args[5]))
      }
    }
    true
  }
  match parse_path(args[2]) {
    Ok(path) => Ok(Set(file=args[1], path~, encoded=args[3], write~))
    Err(error) => Err(error)
  }
}

///|
fn parse_remove(args : Array[String]) -> Result[Command, CommandError] {
  if args.length() < 2 {
    return Err(MissingArgument("file"))
  }
  if args.length() < 3 {
    return Err(MissingArgument("path"))
  }
  let write = if args.length() == 3 {
    false
  } else {
    if args[3] != "--write" {
      return Err(UnexpectedArgument(args[3]))
    }
    if args.length() > 4 {
      return if args[4] == "--write" {
        Err(DuplicateFlag("--write"))
      } else {
        Err(UnexpectedArgument(args[4]))
      }
    }
    true
  }
  match parse_path(args[2]) {
    Ok(path) => Ok(Remove(file=args[1], path~, write~))
    Err(error) => Err(error)
  }
}

///|
/// Parses argv without an executable name. Optional flags are recognized only
/// in their documented final positions; positional values are never counted
/// as flags when detecting a repeated optional flag.
pub fn parse_args(args : Array[String]) -> Result[Command, CommandError] {
  if args.length() == 0 {
    return Err(MissingArgument("command"))
  }
  match args[0] {
    "check" | "get" | "set" | "remove" => ()
    command => return Err(UnknownCommand(command))
  }
  match args[0] {
    "check" => parse_check(args)
    "get" => parse_get(args)
    "set" => parse_set(args)
    "remove" => parse_remove(args)
    command => Err(UnknownCommand(command))
  }
}
