# toml-mbt 设计文档

> MoonBit 实现的 TOML 1.0 解析与序列化库 —— 8 月黑客松参赛项目

## 1. 目标与非目标

**目标**：通过 TOML 1.0 官方 toml-test 一致性测试，发布为 mooncakes.io 上生产可用的配置解析库。

**非目标**（YAGNI，本期不做）：流式/增量解析、TOML 之外格式、命令行工具、大文件内存优化。

## 2. 数据模型（AST）

```
Value = String(String) | Integer(Int64) | Float(Double) | Boolean(Bool)
      | OffsetDateTime | LocalDateTime | LocalDate | LocalTime
      | Array(Array[Value]) | InlineTable(Table)
Table = Map[String, Value]        // 顶层文档即一张 Table
```

日期时间 4 种类型用结构体存储解析后的字段（年/月/日/时/分/秒/纳秒/时区偏移），而非仅存原始字符串，保证 API 真正可用。

## 3. 模块架构

```
src/toml/
├── value.mbt       # AST 类型 + 日期时间类型 + 构造辅助
├── token.mbt       # Token 类型（含 source span：行/列/偏移）
├── lexer.mbt       # 词法：字符串(4种)/数字/布尔/日期时间/标点 → Token 流
├── parser.mbt      # 递归下降：键值对、[table]、[[数组表]]、内联表、数组
├── error.mbt       # TomlError{ line, column, message }
└── serializer.mbt  # Value/Table → TOML 文本
```

数据流：`文本 → Lexer → Token 流 → Parser → Table(Value)`；反向 `Table → Serializer → 文本`。

## 4. 错误处理

解析失败返回 `Result[Table, TomlError]`，`TomlError` 带精确行号/列号 + 可读信息（如 `invalid integer at line 3, column 12`）。所有 invalid 用例断言报错且位置正确。

## 5. 测试策略

1. **toml-test conformance**：官方 toml-test 的 `valid/*.toml` + `invalid/*.toml` 约 300+ 用例，harness 把 AST 转 JSON 与预期对比，接入 CI 全自动跑。
2. **单元测试**：词法、数字、日期时间、错误定位逐模块覆盖。
3. **往返属性测试**：`parse(serialize(x)) == x` 对一组构造值成立。
4. **错误测试**：invalid 输入报错且行列号正确。

## 6. CI（GitHub Actions）

`moonup` 装工具链，流水线：`moon check` → `moon test`（含 conformance）→ `moon build` → `moon fmt --check` → `moon publish --dry-run`。native + wasm-gc 双后端。

## 7. 发布与文档

- `moon publish` 发布 mooncakes.io，License 用 **Apache-2.0**。
- README：用途 / 特性 / 安装（`moon add`）/ 快速上手 / API / 规范版本 / 许可证。

## 8. 提交计划（10+ commits）

| 提交 | 内容 |
|---|---|
| 1 | 脚手架：`moon new`、moon.pkg.json、LICENSE、.gitignore |
| 2 | `feat` 数据模型 + 日期时间 |
| 3 | `feat` lexer |
| 4 | `feat` parser |
| 5 | `feat` error 类型 |
| 6 | `feat` serializer |
| 7-8 | `test` 单元 + conformance harness |
| 9 | `ci` GitHub Actions |
| 10 | `docs` README + examples + CHANGELOG |

## 9. 代码量估算

| 模块 | 行数 |
|---|---|
| value + datetime | ~500 |
| token + lexer | ~700 |
| parser | ~1000 |
| error | ~150 |
| serializer | ~500 |
| 测试 + harness | ~1800 |
| **合计** | **~4650 行**（不含 README/docs）|

## 10. 10 天排期（截至 8 月 24 日）

- D1-D2（8/14-15）：脚手架 + 数据模型 + lexer
- D3-D4（8/16-17）：parser + error
- D5（8/18）：serializer
- D6-D7（8/19-20）：单元测试 + conformance harness
- D8（8/21）：CI + README + examples + CHANGELOG
- D9（8/22）：mooncakes 发布 + 打磨
- D10（8/23）：提交申报书（预留 8/24 截止前缓冲）
