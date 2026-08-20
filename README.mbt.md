# `yufenfei111/toml-mbt`

MoonBit TOML Workbench 的包级接口说明。根包保留独立解析器原型的兼容 API；新增包提供无损源文本、诊断、编辑与纯命令层。原生文件 I/O 位于 `cmd/workbench`，不属于可移植库 API。

发布状态：[`yufenfei111/toml-mbt@0.1.0`](https://mooncakes.io/docs/yufenfei111/toml-mbt) 已发布；仓库已将模块版本准备为 Workbench `0.2.0`，但尚未发布。在赛事验收前发布并回填可验证版本链接是必做事项。

## 根包：语义兼容层

```moonbit nocheck
pub fn parse(String) -> Result[Table, TomlError]
pub fn serialize(Table) -> String
pub fn to_json(Table) -> Json
pub fn decode_tagged_json(String) -> Result[String, TomlError]
pub fn encode_tagged_value(Value) -> String
```

根包以 TOML 1.0 为语法目标，不开启 TOML 1.1 扩展。当前官方 `toml-test` v2.2.0 结果为有效 **181/205**、无效 **421/474**，因此不应视为完整规范覆盖。

## `syntax`：无损语句和 UTF-8 范围

```moonbit nocheck
pub fn scan(String) -> ScanResult
pub fn parse_key_path(String) -> Result[Array[String], SyntaxError]
pub fn Document::find_entries(Self, Array[String]) -> Array[KeyValueEntry]
pub fn Statement::text(Self, String) -> String
```

`SourceSpan` 使用半开区间 UTF-8 字节偏移，位置为 1-based 行列。扫描失败时仍保留原始文档和 `Invalid` 语句。

## `diagnostics`：稳定诊断

```moonbit nocheck
pub fn sort_diagnostics(Array[Diagnostic]) -> Array[Diagnostic]
pub fn render_text(String, String, Diagnostic) -> String
pub fn render_json(Array[Diagnostic]) -> String
```

人类输出包含文件、行列、稳定代码、源行和插入符；JSON 输出包含数字范围与可选建议编辑。

## `edit`：验证后的最小补丁

```moonbit nocheck
pub fn validate_edits(String, Array[TextEdit]) -> Result[Array[TextEdit], EditError]
pub fn apply_edits(String, Array[TextEdit]) -> Result[String, EditError]
pub fn set_value(String, Array[String], String) -> Result[String, OperationError]
pub fn remove_key(String, Array[String]) -> Result[String, OperationError]
```

范围是 UTF-8 字节偏移。重叠、越界、歧义路径、不安全插入和重解析失败均返回错误；API 不会在失败时暴露候选文本。

## `workbench`：纯命令层

```moonbit nocheck
pub fn parse_args(Array[String]) -> Result[Command, CommandError]
pub fn run(Command, String) -> RunResult
pub fn usage() -> String
```

`run` 不访问文件系统。`RunResult.proposed_source` 只在成功编辑后携带完整、已验证候选文本；是否执行 `--write` 由原生适配器决定。

完整用法、验证数据和限制见 [README](README.md)。生成接口以各包的 `pkg.generated.mbti` 为准。
