# MoonBit TOML Workbench

A format-preserving TOML inspection and editing toolchain for MoonBit.

This project began as an independent TOML parser prototype. MoonBit already has the
actively maintained [`moonbit-community/toml-parser`](https://github.com/moonbit-community/toml-parser); the parser in this repository is
retained as a compatibility and experimentation layer, not presented as a replacement.
The hackathon contribution is the lossless syntax model, structured diagnostics,
minimal text patches, and the `check/get/set/remove` workflow.

本项目面向“只改一个配置值，不重排整份文件”的场景。默认编辑只把完整候选文本输出到标准输出；只有显式传入 `--write` 才会替换文件。当前语法目标是 TOML 1.0，不开启 TOML 1.1 扩展；尚未通过的 1.0 用例在下文如实列出。

> 发布状态：原解析器模块 `yufenfei111/toml-mbt@0.1.0` 已可在 [mooncakes.io](https://mooncakes.io/docs/#/yufenfei111/toml-mbt/) 查到；本页描述的 Workbench 包和原生 CLI 目前应从本仓库构建，尚未作为新版本发布。

## 三分钟演示

需要 MoonBit 工具链，并在仓库根目录执行。以下为 PowerShell 7 示例：

```powershell
$demo = Join-Path $env:TEMP 'toml-workbench-demo.toml'
Set-Content -LiteralPath $demo -NoNewline -Encoding utf8 -Value "title  =  `"old`" # keep`n[server]`nport = 8080`n"

moon run --target native cmd/workbench -- check $demo
moon run --target native cmd/workbench -- get $demo server.port
moon run --target native cmd/workbench -- set $demo title '"new"'
moon run --target native cmd/workbench -- set $demo title '"new"' --write
Get-Content -Raw -LiteralPath $demo
```

预期：`check` 成功时无输出；`get` 输出带类型标签的 JSON；第一次 `set` 只预览、不改文件；第二次带 `--write`，最终仍保留 `title` 两侧空格和 `# keep` 注释。

命令接口：

```text
toml-workbench check <file> [--json]
toml-workbench get <file> <key.path>
toml-workbench set <file> <key.path> <toml-value> [--write]
toml-workbench remove <file> <key.path> [--write]
```

## 当前能力

| 能力 | 当前行为 | 证据 |
| --- | --- | --- |
| `check` | 同时运行无损扫描与严格 TOML 1.0 语义解析；支持人类文本或 JSON 诊断 | [`workbench/run.mbt`](workbench/run.mbt)、[`run_test.mbt`](workbench/run_test.mbt) |
| `get` | 读取确定的键路径，输出确定性 tagged JSON；多实例数组表路径会拒绝歧义 | [`workbench/run.mbt`](workbench/run.mbt) |
| `set` | 只替换目标值范围，保留键写法、空格、注释和换行风格；可在有限且确定的位置插入 | [`edit/operations.mbt`](edit/operations.mbt)、[`operations_test.mbt`](edit/operations_test.mbt) |
| `remove` | 删除唯一匹配的键值语句，不删除前置独立注释 | [`edit/operations.mbt`](edit/operations.mbt) |
| 安全写入 | 默认只预览；`--write` 经同目录独占临时文件、完整写入/同步、字节回读、重解析后再替换 | [`cmd/workbench/main.mbt`](cmd/workbench/main.mbt)、[`io_test.mbt`](cmd/workbench/io_test.mbt) |
| 兼容 API | 保留 `parse`、`serialize`、`to_json`、`Table`、`Value`、`TomlError` | [`pkg.generated.mbti`](pkg.generated.mbti) |

## 架构

```text
raw TOML
  ├─ root parser/serializer        semantic compatibility layer
  ├─ syntax/                       lossless statements, UTF-8 spans, key index
  ├─ diagnostics/                  stable human + JSON diagnostics
  ├─ edit/                         validated minimal text patches
  ├─ workbench/                    pure command parsing and behavior
  └─ cmd/workbench/                native file I/O and explicit atomic --write
```

`syntax` 只读取原始文本，不依赖语义解析器；`workbench` 不做文件 I/O；所有文件系统副作用集中在原生适配器。编辑候选文本在返回或替换前会重新扫描并调用语义解析器验证。

## 可复现验证

2026-08-20 在 Windows、Moon `0.1.20260807`、moonc `v0.10.7+bc794d341` 上重新执行：

```powershell
moon check --deny-warn
moon test
moon test --target native -p yufenfei111/toml-mbt/cmd/workbench
moon build --target native
git diff --check
```

结果分别为：无警告；项目测试 **420/420**；原生 CLI 文件系统测试 **11/11**；原生构建和空白检查通过。项目测试数量与官方一致性测试严格分开。

CI 运行同类检查，并固定调用 [`toml-test` v2.2.0](https://github.com/toml-lang/toml-test/tree/v2.2.0)；见 [`.github/workflows/ci.yml`](.github/workflows/ci.yml)。

## 官方 `toml-test` 结果

先构建 decoder，再使用官方 v2 模块路径运行。Windows 上为排除每个子进程默认 1 秒超时造成的启动抖动，证据命令固定为单并发和 10 秒单例超时：

```powershell
moon build --release --target native cmd/toml-test-decoder
$env:TOML_TEST_DECODER_NO_BUILD = '1'
go run github.com/toml-lang/toml-test/v2/cmd/toml-test@v2.2.0 test `
  -decoder .\scripts\toml-test-decoder.cmd -timeout 10s -parallel 1 -color never
Remove-Item Env:TOML_TEST_DECODER_NO_BUILD
```

2026-08-20 连续两次结果一致：有效用例 **181/205**，无效用例 **421/474**。命令退出码为 `1`，因为仍有 **24** 个有效用例和 **53** 个无效用例未通过；这不是全量合规声明。CI 的脚本把结果作为公开的非回归基线，而不是把失败隐藏为成功。

## 已知限制与安全边界

- 语义兼容层仍有上述 TOML 1.0 差距；三个无效日期时间样例会使当前 native decoder 异常终止。不要把本项目用于需要完整 TOML 1.0 覆盖的高风险配置入口。
- `set/remove` 只处理唯一、可证明安全的目标。重复路径、数组表中的可写歧义、隐式或不存在的父表等情况会返回稳定错误，不猜测修改位置。
- “格式保留”指未触及文本按字节保留和局部最小补丁，不是任意文档的自动格式化器。
- `--write` 的 MVP 信任稳定、可信、非符号链接的目标路径，且假设没有并发写入者或目录/链接交换。它不是敌对文件系统事务协议。
- 临时文件从首字节起以 `0600` 请求创建。Unix 替换后权限可能收窄为 `0600`；当前 async API 不能复制原文件的 mode、owner、扩展属性或 Windows ACL。Windows 会忽略 mode 参数并采用目录 ACL 行为。
- Workbench 新包与 CLI 尚未发布到 mooncakes.io 新版本，当前从源码运行。

## 路线图（尚未完成）

- 修复剩余 TOML 1.0 一致性差距及 native decoder 异常终止；
- 为受支持平台增加经审查的文件元数据保留层和并发修改检测；
- 增加机器可读 patch/diff 输出，并扩大数组表的无歧义编辑范围；
- 完成 Workbench 新版本的 mooncakes.io 发布和独立 CLI 安装说明。

## 与现有项目的关系

本仓库不是 `moonbit-community/toml-parser` 的替代品，也不把对方的工作计入本项目。上游当前侧重 TOML 1.1 语义解析、序列化和 `check/format/tojson` CLI；本项目的申报增量侧重源文本范围、诊断、最小补丁和显式安全写入。基于 2026-08-20 证据的中性比较见 [`docs/comparison.md`](docs/comparison.md)，重新申报文本见 [`docs/application.md`](docs/application.md)。

## License

[Apache-2.0](LICENSE)，为 OSI 认可的开源许可证。
