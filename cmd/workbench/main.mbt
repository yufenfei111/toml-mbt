///|
pub struct CliResult {
  stdout : String
  stderr : String
  exit_code : Int
} derive(Eq, Debug)

///|
extern "C" fn exit_with_code(code : Int) = "exit"

///|
extern "C" fn process_id() -> UInt = "moonbitlang_async_getpid"

///|
fn command_file(command : @wb.Command) -> String {
  match command {
    Check(file~, ..) | Get(file~, ..) | Set(file~, ..) | Remove(file~, ..) =>
      file
  }
}

///|
fn command_writes(command : @wb.Command) -> Bool {
  match command {
    Set(write~, ..) | Remove(write~, ..) => write
    Check(_) | Get(_) => false
  }
}

///|
fn path_parts(path : String) -> (String, String, String) {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  let separator_index = match (slash, backslash) {
    (Some(left), Some(right)) => Some(if left > right { left } else { right })
    (Some(index), None) | (None, Some(index)) => Some(index)
    (None, None) => None
  }
  match separator_index {
    None => (".", path, "/")
    Some(index) => {
      let separator = path[index:index + 1].to_owned()
      let parent = if index == 0 {
        separator
      } else if index == 2 && path.length() >= 3 && path[1] == ':' {
        path[0:3].to_owned()
      } else {
        path[0:index].to_owned()
      }
      (parent, path[index + 1:].to_owned(), separator)
    }
  }
}

///|
fn generated_temp_path(target : String) -> String {
  let (parent, basename, separator) = path_parts(target)
  parent +
  separator +
  "." +
  basename +
  ".toml-workbench-" +
  process_id().to_string() +
  "-" +
  @env.now().to_string() +
  ".tmp"
}

///|
async fn cleanup_created_temp(path : String) -> Unit {
  @fs.remove(path) catch {
    _ => ()
  }
}

///|
async fn resolved_parents_match(target : String, temporary : String) -> Bool {
  let (target_parent, _, _) = path_parts(target)
  let (temporary_parent, _, _) = path_parts(temporary)
  @fs.realpath(target_parent) == @fs.realpath(temporary_parent)
}

///|
/// Replaces `target` only after a same-directory temporary file contains the
/// exact candidate bytes and the candidate parses as TOML. `temp_path` is an
/// explicit test seam; normal callers receive a process/time-derived name.
pub async fn atomic_replace(
  target : String,
  candidate : String,
  temp_path? : String,
) -> Result[Unit, String] {
  let temporary = temp_path.unwrap_or_else(() => generated_temp_path(target))
  let mut created = false
  let outcome : Result[Unit, String] = try {
    if !resolved_parents_match(target, temporary) {
      Err("temporary file must be in the target directory")
    } else {
      let temporary_file = @fs.open(
        temporary,
        mode=WriteOnly,
        create_mode=CreateNew,
        sync=Full,
      )
      created = true
      let write_error : String? = try {
        temporary_file.write(candidate)
        temporary_file.sync()
        None
      } catch {
        error => Some(error.to_string())
      }
      temporary_file.close()
      match write_error {
        Some(message) => Err(message)
        None => {
          let readback_data = @fs.read_file(temporary)
          let exact_bytes = readback_data.binary() == @utf8.encode(candidate)
          let readback = readback_data.text()
          if !exact_bytes || readback != candidate {
            Err("temporary file readback did not match the candidate bytes")
          } else {
            match @toml-mbt.parse(readback) {
              Err(error) =>
                Err("temporary file is not valid TOML: " + error.to_string())
              Ok(_) =>
                if !resolved_parents_match(target, temporary) {
                  Err("temporary file parent changed before replacement")
                } else {
                  @fs.rename(temporary, target, replace=true)
                  Ok(())
                }
            }
          }
        }
      }
    }
  } catch {
    error => Err(error.to_string())
  }
  if created && outcome is Err(_) {
    cleanup_created_temp(temporary)
  }
  outcome
}

///|
fn from_run_result(result : @wb.RunResult) -> CliResult {
  { stdout: result.stdout, stderr: result.stderr, exit_code: result.exit_code }
}

///|
fn usage_error(error : @wb.CommandError) -> CliResult {
  {
    stdout: "",
    stderr: error.to_string() + "\n" + @wb.usage(),
    exit_code: error.exit_code(),
  }
}

///|
fn io_error(message : String) -> CliResult {
  { stdout: "", stderr: "error[WB300]: " + message, exit_code: 1 }
}

///|
/// Runs the native adapter against explicit argv (without executable name).
/// The source file is read exactly once before control passes to pure Workbench
/// logic. An injected `temp_path` is used only for a successful `--write`.
pub async fn execute(args : Array[String], temp_path? : String) -> CliResult {
  match @wb.parse_args(args) {
    Err(error) => usage_error(error)
    Ok(command) => {
      let target = command_file(command)
      let source = @fs.read_file(target).text() catch {
        error => return io_error("cannot read source: " + error.to_string())
      }
      let result = @wb.run(command, source)
      if command_writes(command) && result.exit_code == 0 {
        match result.proposed_source {
          None => io_error("successful write command produced no candidate")
          Some(candidate) =>
            match atomic_replace(target, candidate, temp_path?) {
              Ok(_) => from_run_result(result)
              Err(message) => io_error("atomic write failed: " + message)
            }
        }
      } else {
        from_run_result(result)
      }
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:].to_owned()
  let result = execute(args)
  if !result.stdout.is_empty() {
    @stdio.stdout.write(result.stdout)
  }
  if !result.stderr.is_empty() {
    @stdio.stderr.write(result.stderr)
  }
  if result.exit_code != 0 {
    exit_with_code(result.exit_code)
  }
}
