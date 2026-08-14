///|
/// A runnable example that parses a TOML document, walks the result, and
/// prints the tagged JSON representation. Run with `moon run cmd/main`.

///|
fn main {
  let toml = "title = \"TOML demo\"\n" +
    "enabled = true\n" +
    "retries = 3\n" +
    "ratio = 0.75\n" +
    "release = 2026-08-14T00:00:00Z\n" +
    "\n" +
    "[server]\n" +
    "host = \"localhost\"\n" +
    "ports = [8080, 8081]\n" +
    "\n" +
    "[[workers]]\n" +
    "name = \"alice\"\n" +
    "cores = 4\n"

  match @toml-mbt.parse(toml) {
    Ok(table) => {
      println("Parsed successfully.")
      println("Top-level keys: \{table.length()}")
      println("")
      println("Tagged JSON (toml-test format):")
      println(@toml-mbt.to_json(table).stringify())
    }
    Err(e) => println("Parse error: \{e.to_string()}")
  }
}
