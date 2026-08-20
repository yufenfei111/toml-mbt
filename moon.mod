// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "yufenfei111/toml-mbt"

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/yufenfei111/toml-mbt"

license = "Apache-2.0"

keywords = [ "toml", "workbench", "lossless", "diagnostics", "editor", "cli" ]

preferred_target = "wasm"

description = "Format-preserving TOML inspection and safe editing workbench for MoonBit"

import {
  "moonbitlang/async@0.20.1",
}
