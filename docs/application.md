# MoonBit TOML Workbench｜八月黑客松重新申报书

**项目仓库：** [github.com/yufenfei111/toml-mbt](https://github.com/yufenfei111/toml-mbt)　**许可证：** [Apache-2.0](https://github.com/yufenfei111/toml-mbt/blob/main/LICENSE)　**主要语言：** MoonBit

## 一、为什么重新申报

第一次申报时，我把这个项目介绍成了一个 TOML 解析库，但没有说明它与 [`moonbit-community/toml-parser`](https://github.com/moonbit-community/toml-parser) 的关系。对方一直在维护，已经支持 TOML 1.1 语义解析、序列化以及 `check/format/tojson`，原申报的定位确实重叠了。

本仓库不是它的 fork，我也不打算用它取代现有项目。这次重新申报，我把原来的解析器留作兼容和实验基础，项目重点改为：在尽量不改动注释、空格和换行的前提下，检查并修改 TOML 文件。与现有项目的详细对比记录在 [`docs/comparison.md`](https://github.com/yufenfei111/toml-mbt/blob/main/docs/comparison.md)，其中的信息按核对日期固定，便于回看。

官方规则允许在既有项目上继续开发，但要分清新旧贡献；八月黑客松也不接受重复项目、拆分项目或简单修改（[官方赛事页](https://moonbitlang.github.io/OSC2026/)）。本仓库 8 月 14 日已有的内容是 `parse/serialize/Value` 和相关单元测试。8 月 18–20 日的提交才是这次申报的新增部分，原有代码不重复算作新成果。

## 二、这次实际做了什么

我想解决的是一个很具体的问题：运维脚本、依赖升级工具或 IDE 往往只需要修改 TOML 里的一个值。如果先解析、再把整份文件序列化，原有的空格、注释和换行可能都会变，最后的 diff 很难审查。

现在可以先用 `check` 检查文件，用 `get` 读取值，再用 `set` 或 `remove` 查看修改结果。这些命令默认只预览，只有明确加上 `--write` 才会写回文件。

| 这次新增的内容 | 对应代码和测试 |
| --- | --- |
| 按原始字节保留语句，记录 UTF-8 范围、键路径和表上下文 | [`syntax/scan.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/syntax/scan.mbt)、[`path.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/syntax/path.mbt)、[`syntax tests`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/syntax/scan_test.mbt) |
| 给检查错误分配稳定错误码，同时输出便于人阅读的诊断和 JSON 诊断 | [`diagnostics/diagnostic.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/diagnostics/diagnostic.mbt)、[`tests`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/diagnostics/diagnostic_test.mbt) |
| 检查修改范围，只替换 `set/remove` 涉及的部分，然后重新解析候选全文 | [`edit/operations.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/edit/operations.mbt)、[`tests`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/edit/operations_test.mbt) |
| 实现不负责文件 I/O 的 `check/get/set/remove` 命令层 | [`workbench/run.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/workbench/run.mbt)、[`tests`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/workbench/run_test.mbt) |
| 默认只预览；使用 `--write` 时，经过同目录临时文件、同步、回读和重新解析后再替换原文件 | [`cmd/workbench/main.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/cmd/workbench/main.mbt)、[`11 项原生测试`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/cmd/workbench/io_test.mbt) |
| 修正官方 decoder，补充 Windows/Linux 启动脚本和 CI 回归检查 | [`decoder.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/decoder.mbt)、[`CI`](https://github.com/yufenfei111/toml-mbt/blob/main/.github/workflows/ci.yml) |

这部分工作的重点不是再做一个 parser，而是先找到值在原文中的位置，生成尽可能小的修改，验证修改后的内容，最后由用户决定是否写回。如果遇到歧义路径、数组表写入、隐式父表或者修改后无法解析的内容，工具会拒绝修改，而不是猜测用户意图。

## 三、目前的验证结果和局限

以 2026 年 8 月 21 日的版本为准，测试环境是 Moon `0.1.20260807` / moonc `v0.10.7+bc794d341`。`moon check --deny-warn` 通过，`moon test` 结果为 **420/420**，原生 CLI 测试为 **11/11**，native build 也已通过。[Ubuntu CI](https://github.com/yufenfei111/toml-mbt/actions/runs/32453249291) 目前全部通过。

官方 `toml-test` **v2.2.0** 的结果是 valid **181/205**、invalid **421/474**，Windows 两次和 Ubuntu CI 结果一致。这不是全部通过，命令会因剩余差距正常返回 exit 1。项目自己的 420 项测试和官方一致性测试没有混在一起计数，具体复现命令见 [README](https://github.com/yufenfei111/toml-mbt#%E5%8F%AF%E5%A4%8D%E7%8E%B0%E9%AA%8C%E8%AF%81)。

项目现在仍只支持 TOML 1.0。语义兼容层还差 24 个 valid 用例和 53 个 invalid 用例，其中三个无效日期时间样例会让 native decoder 异常终止。目前对无法确保安全的编辑会直接拒绝。文件替换还假设路径可信、稳定、不是符号链接，且没有其他程序同时写入；Unix 权限可能收窄为 `0600`，owner、xattr 和 Windows ACL 也不会保留。

Workbench [`0.2.0`](https://mooncakes.io/docs/yufenfei111/toml-mbt) 已发布。我用一个全新的临时项目指定安装该版本，完成了依赖解析，并通过 `moon check`。

## 四、评审如何快速复现

1. 按 [README 三分钟演示](https://github.com/yufenfei111/toml-mbt#%E4%B8%89%E5%88%86%E9%92%9F%E6%BC%94%E7%A4%BA) 创建样例，运行 `check/get/set`，确认没有 `--write` 时文件不变。
2. 加上 `--write`，确认只有目标值变化，原来的空格和行尾注释仍然保留。
3. 运行 `moon test` 和 `moon test --target native -p yufenfei111/toml-mbt/cmd/workbench`。

接下来我会先修复 decoder 异常终止，然后再处理剩余的 TOML 1.0 差距、文件元数据保留和并发修改检测。独立 `moonx` CLI 包和 patch/diff 输出也还没有完成，这些都只是后续计划，不算在本次成果中。

这次重新申报，我希望评审的重点是 8 月 18–20 日新增的 TOML 原文检查和安全编辑功能，而不是原来的解析器。上面的链接和命令是为了方便直接核对；最终是否通过，仍以组委会的审核为准。
