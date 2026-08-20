# 与 `moonbit-community/toml-parser` 的中性比较

检视日期：**2026-08-20**。

## 证据范围

- 上游仓库：[`moonbit-community/toml-parser`](https://github.com/moonbit-community/toml-parser)
- 检视提交：[`27897deb42fa9f420fd74b75f14e86e2ed7c6c81`](https://github.com/moonbit-community/toml-parser/commit/27897deb42fa9f420fd74b75f14e86e2ed7c6c81)（2026-08-19）
- 固定版本 README：[该提交的 `README.mbt.md`](https://github.com/moonbit-community/toml-parser/blob/27897deb42fa9f420fd74b75f14e86e2ed7c6c81/README.mbt.md)
- 固定版本模块元数据：[该提交的 `moon.mod`](https://github.com/moonbit-community/toml-parser/blob/27897deb42fa9f420fd74b75f14e86e2ed7c6c81/moon.mod)
- GitHub Releases 页面当日显示的 latest release：[`v0.4.1`](https://github.com/moonbit-community/toml-parser/releases/tag/v0.4.1)（2026-06-06）；同时，检视提交的 `moon.mod` 声明模块版本 `0.4.3`。这里分别报告，不把 GitHub release 标签和模块版本混为一谈。

以下“上游”列只概括上述 README/元数据公开记录；“未作为核心能力记录”不等于断言源码中绝对不存在。

## 对比

| 维度 | `moonbit-community/toml-parser`（检视证据） | MoonBit TOML Workbench（本仓库） |
| --- | --- | --- |
| 定位 | 轻量 TOML 语义解析器；README 声明 TOML 1.1 支持 | TOML 1.0 源文本检查和保格式编辑工具链；根解析器是兼容层 |
| 值解析 | README 记录完整值模型、日期时间校验、表/数组表等 | `parse -> Table/Value`；官方 v2.2.0 当前为 valid 181/205、invalid 421/474，不声称全量覆盖 |
| 序列化 | `TomlValue::to_string`，README 展示结构转 TOML | 保留 `serialize(Table)`；不把语义序列化当作源文本保留 |
| 官方测试 | README 自述 736/745、valid 262/262；本比较未独立复跑该仓库 | 固定 v2.2.0 decoder 命令，公开当前失败数和非零退出码；另有项目测试 420/420 |
| 源文本保留 | 检视 README 未把 byte-exact 语句、源范围或未触及文本保留列为核心能力 | `syntax` 保存半开 UTF-8 范围、语句文本、键和值范围及表上下文 |
| 文本补丁 | 检视 README 未把基于源范围的最小 patch API 列为核心能力 | `TextEdit` 校验范围/重叠；`set/remove` 只改确定范围并重解析完整候选 |
| 诊断 | README 记录精确行列错误 | 稳定错误码、人类源行/插入符输出、结构化 JSON 范围；控制字符安全转义 |
| CLI | 配套 `toml_cli` 提供 `check`、`format`、`tojson` | `check`、`get`、`set`、`remove`；编辑默认预览，只有 `--write` 才替换文件 |
| 写入边界 | 本次只按 README 所列 CLI 描述，不推断内部写入协议 | 同目录独占临时文件、同步、字节回读、重解析、替换；明确披露元数据和敌对文件系统限制 |

## 结论

两个项目不是同一目标下的替代关系。上游在语义解析覆盖、TOML 1.1 和既有 CLI 上明显更成熟；本项目不应重复申报“MoonBit TOML 解析库”。本次申报的可区分贡献是：把原始 TOML 当作需要保留的文本工件，建立源范围、稳定诊断、验证后的最小补丁，以及默认不落盘的安全编辑工作流。

如果上游文档或实现更新，本页应重新检视并更新，不应沿用本次日期的结论。
