///|
extern "C" fn exit_with_code(code : Int) = "exit"

///|
async fn main {
  let source = @stdio.stdin.read_all().text()
  match @toml-mbt.decode_tagged_json(source) {
    Ok(output) => @stdio.stdout.write(output + "\n")
    Err(error) => {
      @stdio.stderr.write(error.to_string() + "\n")
      exit_with_code(1)
    }
  }
}
