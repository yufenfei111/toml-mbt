///|
pub struct CliResult {
  stdout : String
  stderr : String
  exit_code : Int
} derive(Eq, Debug)

///|
extern "C" fn exit_with_code(code : Int) = "exit"

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
fn temp_path_for_nonce(target : String, nonce : String) -> String {
  let (parent, basename, separator) = path_parts(target)
  parent + separator + "." + basename + ".toml-workbench-" + nonce + ".tmp"
}

///|
fn random_temp_candidates(target : String) -> Result[Array[String], String] {
  let candidates : Array[String] = []
  for attempt = 0; attempt < 8; attempt = attempt + 1 {
    guard @env.rand(16) is Some(bytes) else {
      return Err("operating system random source is unavailable")
    }
    let nonce = StringBuilder(size_hint=32)
    for byte in bytes {
      nonce.write_string(byte.to_hex())
    }
    candidates.push(
      temp_path_for_nonce(target, nonce.to_string() + "-" + attempt.to_string()),
    )
  }
  Ok(candidates)
}

///|
/// Best-effort cleanup for a temporary file created by this process. Cleanup
/// is cancellation-protected. If removal fails, the exact residual path and
/// cleanup error are added to the original failure.
pub async fn cleanup_after_failure(path : String, failure : String) -> String {
  let cleanup_error : String? = try {
    @async.protect_from_cancel(() => @fs.remove(path), resume_on_cancel=true)
    None
  } catch {
    error => Some(error.to_string())
  }
  match cleanup_error {
    None => failure
    Some(error) =>
      failure +
      "; cleanup failed; temporary file retained at \"" +
      path +
      "\": " +
      error
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
/// explicit test seam; normal callers receive bounded random candidates.
pub async fn atomic_replace(
  target : String,
  candidate : String,
  temp_path? : String,
) -> Result[Unit, String] {
  let candidates = match temp_path {
    Some(path) => [path]
    None =>
      match random_temp_candidates(target) {
        Ok(candidates) => candidates
        Err(error) => return Err(error)
      }
  }
  atomic_replace_with_candidates(target, candidate, candidates)
}

///|
priv enum TempOpen {
  Opened(String, @fs.File)
  Collision
  Failed(String)
}

///|
async fn try_open_temp(path : String) -> TempOpen {
  Opened(
    path,
    @fs.open(
      path,
      mode=WriteOnly,
      create_mode=CreateNew,
      permission=0o600,
      sync=Full,
    ),
  ) catch {
    @os_error.OSError(_) as error if error.is_EEXIST() => Collision
    error => Failed(error.to_string())
  }
}

///|
/// Atomic replacement with explicit ordered candidates. An existing candidate
/// is never overwritten or removed; creation continues with the next path.
pub async fn atomic_replace_with_candidates(
  target : String,
  candidate : String,
  candidates : Array[String],
) -> Result[Unit, String] {
  let attempt_count = candidates.length()
  let mut opened : (String, @fs.File)? = None
  for temporary in candidates {
    if !resolved_parents_match(target, temporary) {
      return Err("temporary file must be in the target directory")
    }
    match try_open_temp(temporary) {
      Collision => continue
      Failed(error) => return Err(error)
      Opened(path, file) => {
        opened = Some((path, file))
        break
      }
    }
  }
  guard opened is Some((temporary, temporary_file)) else {
    return Err(
      "unable to create a unique temporary file after " +
      attempt_count.to_string() +
      " attempts",
    )
  }
  let write_error : String? = try {
    temporary_file.write(candidate)
    temporary_file.sync()
    None
  } catch {
    error => Some(error.to_string())
  }
  temporary_file.close()
  if write_error is Some(error) {
    return Err(cleanup_after_failure(temporary, error))
  }
  let outcome : Result[Unit, String] = try {
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
  } catch {
    error => Err(error.to_string())
  }
  match outcome {
    Ok(_) => Ok(())
    Err(error) => Err(cleanup_after_failure(temporary, error))
  }
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
        _ => return io_error("cannot read source: \"" + target + "\"")
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
