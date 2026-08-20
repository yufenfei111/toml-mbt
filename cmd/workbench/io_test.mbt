///|
async fn with_test_directory(
  name : String,
  body : async (String) -> Unit,
) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @fs.tmpdir(prefix="toml-workbench-\{name}-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @fs.rmdir(directory, recursive=true))
    }
    body(directory)
  }
}

///|
async test "execute reads a valid TOML file" {
  with_test_directory("read", directory => {
    let target = "\{directory}/input.toml"
    @fs.write_file(target, "title = \"old\"\n", create_mode=CreateNew)
    let result = execute(["check", target])
    assert_eq(result.exit_code, 0)
    assert_eq(result.stdout, "")
    assert_eq(result.stderr, "")
  })
}

///|
async test "set without write prints candidate and preserves the file" {
  with_test_directory("stdout", directory => {
    let target = "\{directory}/input.toml"
    let original = "title  =  \"old\" # keep\n"
    @fs.write_file(target, original, create_mode=CreateNew)
    let result = execute(["set", target, "title", "\"new\""])
    assert_eq(result.exit_code, 0)
    assert_eq(result.stdout, "title  =  \"new\" # keep\n")
    assert_eq(result.stderr, "")
    assert_eq(@fs.read_file(target).text(), original)
  })
}

///|
async test "set with write atomically replaces the target" {
  with_test_directory("write", directory => {
    let target = "\{directory}/input.toml"
    let temporary = "\{directory}/input.toml.explicit.tmp"
    @fs.write_file(target, "title  =  \"old\" # keep\n", create_mode=CreateNew)
    let result = execute(
      ["set", target, "title", "\"new\"", "--write"],
      temp_path=temporary,
    )
    assert_eq(result.exit_code, 0)
    assert_eq(result.stdout, "title  =  \"new\" # keep\n")
    assert_eq(result.stderr, "")
    assert_eq(@fs.read_file(target).text(), "title  =  \"new\" # keep\n")
    assert_false(@fs.exists(temporary))
  })
}

///|
async test "atomic replacement cleans an invalid candidate and preserves bytes" {
  with_test_directory("invalid", directory => {
    let target = "\{directory}/input.toml"
    let temporary = "\{directory}/input.toml.explicit.tmp"
    let original = "title = \"old\"\n"
    @fs.write_file(target, original, create_mode=CreateNew)
    let result = atomic_replace(
      target,
      "title = { broken = 1, }\n",
      temp_path=temporary,
    )
    assert_true(result is Err(_))
    assert_eq(@fs.read_file(target).text(), original)
    assert_false(@fs.exists(temporary))
  })
}

///|
async test "atomic replacement rejects a temp path outside the target directory" {
  with_test_directory("boundary", directory => {
    let target_directory = "\{directory}/target"
    let other_directory = "\{directory}/other"
    @fs.mkdir(target_directory)
    @fs.mkdir(other_directory)
    let target = "\{target_directory}/input.toml"
    let temporary = "\{other_directory}/input.toml.explicit.tmp"
    let original = "title = \"old\"\n"
    @fs.write_file(target, original, create_mode=CreateNew)
    let result = atomic_replace(
      target,
      "title = \"new\"\n",
      temp_path=temporary,
    )
    assert_true(result is Err(_))
    assert_eq(@fs.read_file(target).text(), original)
    assert_false(@fs.exists(temporary))
  })
}

///|
async test "atomic replacement retries collision without touching stale temp" {
  with_test_directory("collision", directory => {
    let target = "\{directory}/input.toml"
    let stale = "\{directory}/.input.toml.stale.tmp"
    let fresh = "\{directory}/.input.toml.fresh.tmp"
    @fs.write_file(target, "title = \"old\"\n", create_mode=CreateNew)
    @fs.write_file(stale, "stale", create_mode=CreateNew)
    let result = atomic_replace_with_candidates(target, "title = \"new\"\n", [
      stale, fresh,
    ])
    assert_true(result is Ok(_))
    assert_eq(@fs.read_file(target).text(), "title = \"new\"\n")
    assert_eq(@fs.read_file(stale).text(), "stale")
    assert_false(@fs.exists(fresh))
  })
}

///|
async test "cleanup failure reports exact residual path and preserves it" {
  with_test_directory("cleanup", directory => {
    let residual = "\{directory}/owned-temp"
    @fs.mkdir(residual)
    @fs.write_file("\{residual}/child", "keep", create_mode=CreateNew)
    let error = cleanup_after_failure(residual, "primary failure")
    assert_true(
      error.has_prefix(
        "primary failure; cleanup failed; temporary file retained at \"" +
        residual +
        "\": ",
      ),
    )
    assert_true(@fs.exists(residual))
    assert_eq(@fs.read_file("\{residual}/child").text(), "keep")
  })
}

///|
async test "usage error has exact output without filesystem access" {
  let result = execute([])
  assert_eq(result.exit_code, 2)
  assert_eq(result.stdout, "")
  assert_eq(
    result.stderr,
    "missing argument: command\n" +
    "usage:\n" +
    "  toml-workbench check <file> [--json]\n" +
    "  toml-workbench get <file> <key.path>\n" +
    "  toml-workbench set <file> <key.path> <toml-value> [--write]\n" +
    "  toml-workbench remove <file> <key.path> [--write]",
  )
}

///|
async test "read failure has stable exact adapter output" {
  with_test_directory("missing", directory => {
    let target = "\{directory}/missing.toml"
    let result = execute(["check", target])
    assert_eq(result.exit_code, 1)
    assert_eq(result.stdout, "")
    assert_eq(result.stderr, "error[WB300]: cannot read source: \"\{target}\"")
  })
}

///|
async test "failed write command does not create temp or change target" {
  with_test_directory("failed-write", directory => {
    let target = "\{directory}/input.toml"
    let temporary = "\{directory}/input.toml.explicit.tmp"
    let original = "title = \"old\"\n"
    @fs.write_file(target, original, create_mode=CreateNew)
    let result = execute(
      ["set", target, "title", "{ broken = 1, }", "--write"],
      temp_path=temporary,
    )
    assert_eq(result.exit_code, 1)
    assert_eq(result.stdout, "")
    assert_true(result.stderr.has_prefix("error[WB203]:"))
    assert_eq(@fs.read_file(target).text(), original)
    assert_false(@fs.exists(temporary))
  })
}

///|
async test "remove with write replaces the target and leaves no default temp" {
  with_test_directory("remove-write", directory => {
    let target = "\{directory}/input.toml"
    @fs.write_file(
      target,
      "remove = 1 # gone\nkeep = 2\n",
      create_mode=CreateNew,
    )
    let result = execute(["remove", target, "remove", "--write"])
    assert_eq(result.exit_code, 0)
    assert_eq(result.stdout, "keep = 2\n")
    assert_eq(result.stderr, "")
    assert_eq(@fs.read_file(target).text(), "keep = 2\n")
    assert_eq(@fs.readdir(directory), [
      target.rev_after("/").unwrap().to_owned(),
    ])
  })
}
