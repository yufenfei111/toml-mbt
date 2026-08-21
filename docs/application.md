# MoonBit TOML Workbench｜八月黑客松重新申报书

**项目仓库：** [github.com/yufenfei111/toml-mbt](https://github.com/yufenfei111/toml-mbt)　**许可证：** [Apache-2.0](https://github.com/yufenfei111/toml-mbt/blob/main/LICENSE)　**主要语言：** MoonBit

## 一、驳回整改与项目定位

初次申报以“TOML 解析库”为中心，与持续维护的 [`moonbit-community/toml-parser`](https://github.com/moonbit-community/toml-parser) 重叠，且没有说明关系，这是本次整改的直接原因。本仓库不是该项目的 fork，也不申报替代它：上游当前聚焦 TOML 1.1 语义解析、序列化及 `check/format/tojson`；本项目把原解析器保留为兼容/实验层，重新定位为 **保留原文格式的 TOML 检查与安全编辑 Workbench**。完整、按日期固定的证据比较见 [`docs/comparison.md`](https://github.com/yufenfei111/toml-mbt/blob/main/docs/comparison.md)。

官方规则允许已有基础继续维护，但要求区分新增贡献；八月黑客松不接受重复、拆分或简单修改项目（[官方赛事页](https://moonbitlang.github.io/OSC2026/)）。本仓库 8 月 14 日已有基础是 `parse/serialize/Value` 与单元测试；8 月 18–20 日公开提交的本次新增是下表 Workbench 全链路，旧基础不重复计入新增成果。

## 二、用户问题、已完成功能与创新

运维脚本、依赖升级器和 IDE 经常只需改一个 TOML 值；“解析后整份序列化”会重排空格、注释和换行，难以审阅。现在用户可执行 `check → get → set/remove 预览 → --write`：

| 已完成增量 | 实现与测试证据 |
| --- | --- |
| byte-exact 语句、UTF-8 span、键路径/表上下文 | [`syntax/scan.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/syntax/scan.mbt)、[`path.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/syntax/path.mbt)、[`syntax tests`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/syntax/scan_test.mbt) |
| 稳定错误码、人类诊断和 JSON 诊断 | [`diagnostics/diagnostic.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/diagnostics/diagnostic.mbt)、[`tests`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/diagnostics/diagnostic_test.mbt) |
| 范围校验、最小 `set/remove` 补丁、候选全文重解析 | [`edit/operations.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/edit/operations.mbt)、[`tests`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/edit/operations_test.mbt) |
| 纯 `check/get/set/remove` 命令层 | [`workbench/run.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/workbench/run.mbt)、[`tests`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/workbench/run_test.mbt) |
| 默认只预览；显式 `--write` 才经同目录临时文件、同步、回读、重解析后替换 | [`cmd/workbench/main.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/cmd/workbench/main.mbt)、[`11 项原生测试`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/cmd/workbench/io_test.mbt) |
| 固定官方 decoder、Windows/Linux launcher 与 CI 非回归门禁 | [`decoder.mbt`](https://github.com/yufenfei111/toml-mbt/blob/cdeed54825e798c1d6d42f751c9635223e1e09e3/decoder.mbt)、[`CI`](https://github.com/yufenfei111/toml-mbt/blob/main/.github/workflows/ci.yml) |

技术差异不在“再写一个 parser”，而在 **源文本范围 → 稳定诊断 → 验证后的局部补丁 → 显式安全落盘** 的组合；歧义路径、数组表写入、隐式父表和无效候选会被拒绝，不猜测修改。

## 三、可复现证据与边界

2026-08-21，Moon `0.1.20260807` / moonc `v0.10.7+bc794d341`：`moon check --deny-warn` 通过；`moon test` 为 **420/420**；原生 CLI 为 **11/11**；native build 通过。[Ubuntu CI](https://github.com/yufenfei111/toml-mbt/actions/runs/32453249291) 全绿；官方 `toml-test` **v2.2.0** 在 Windows 两次及 Ubuntu CI 均为 valid **181/205**、invalid **421/474**，因仍有差距而正常返回 exit 1。复现命令见 [README](https://github.com/yufenfei111/toml-mbt#%E5%8F%AF%E5%A4%8D%E7%8E%B0%E9%AA%8C%E8%AF%81)，项目测试与官方用例从不混计。

已知限制：仅支持 TOML 1.0；语义兼容层仍有 24 个 valid、53 个 invalid 官方差距，其中三个无效日期时间样例会使 native decoder 异常终止；不安全编辑会拒绝。原子替换假设可信、稳定、非符号链接路径且无并发写入；Unix 权限可能收窄为 `0600`，不保留 owner/xattr/Windows ACL。Workbench [`0.2.0`](https://mooncakes.io/docs/yufenfei111/toml-mbt) 已发布，并由全新临时项目完成指定版本安装、依赖解析与 `moon check`。

## 四、评审三分钟复现与后续计划

1. 按 [README 三分钟演示](https://github.com/yufenfei111/toml-mbt#%E4%B8%89%E5%88%86%E9%92%9F%E6%BC%94%E7%A4%BA) 创建样例并运行 `check/get/set`；确认无 `--write` 时文件不变。
2. 加 `--write`；确认仅值变化，原空格和行尾注释保留。
3. 运行 `moon test` 与 `moon test --target native -p yufenfei111/toml-mbt/cmd/workbench`。

**尚未完成、只列为后续：** 优先修复 decoder 异常终止；之后再处理剩余 TOML 1.0 差距、文件元数据保留、并发修改检测、独立 `moonx` CLI 包和 patch/diff 输出。申请目标是证明新增工具链与现有解析器项目有清晰边界；以上材料提升初审可核验性，但不承诺审核结果。
