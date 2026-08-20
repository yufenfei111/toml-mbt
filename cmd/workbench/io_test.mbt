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
