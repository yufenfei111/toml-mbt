# MoonBit TOML Workbench 设计

日期：2026-08-18

## 1. 背景与定位

现有 `toml-mbt` 已实现 TOML 数据模型、解析、序列化、错误位置和项目内测试，但“MoonBit 的 TOML 解析库”与近期维护的 [`moonbit-community/toml-parser`](https://github.com/moonbit-community/toml-parser) 重叠。比赛项目因此改名为 **MoonBit TOML Workbench**，参赛目标从“再实现一个解析器”调整为“为 MoonBit 提供保留源码格式的 TOML 分析和安全修改工具链”。

现有解析器保留为兼容层和独立技术原型，不再作为参赛创新点，也不宣称替代已有生态项目。申报材料必须明确披露已有项目，分别说明复用、兼容和差异边界。

## 2. 目标与非目标

### 2.1 目标

1. 建立 Lossless CST，保存注释、空白、键顺序、原始字面量和源码区间。
2. 提供结构化诊断，包含严重级别、源码区间、错误说明和可选修复建议。
3. 提供最小文本补丁，使 `set` 和 `remove` 不重排或重写无关内容。
4. 提供可直接演示的 CLI：`check`、`get`、`set`、`remove`。
5. 接入官方 `toml-test` decoder 协议，公布可复现的真实通过结果。
6. 保持现有解析和序列化 API 可用，避免破坏已经完成的工作。

### 2.2 2026-08-24 前的非目标

- 不实现完整 TOML Schema 语言；只在后续阶段增加 Schema 校验。
- 不实现 LSP、编辑器插件或 Web IDE；这些作为比赛开发期的演进方向。
- 不实现通用三路合并、实时协同编辑或增量解析。
- 不承诺尚未由官方测试验证的“完整 TOML 1.0 合规”。
- 不伪造、拆分或回填历史提交；从本设计开始保留真实迭代记录。

## 3. 方案选择

采用 **CLI 型 Workbench**：以 Lossless CST 和补丁引擎作为核心，以 CLI 提供完整用户路径。

未采用仅提供 Lossless CST 库的方案，因为它缺少直接用户体验；未采用立即开发 LSP/Web IDE 的方案，因为在补交期限内无法可靠完成和验证。CLI 架构保留公共库边界，后续可被 LSP 和 WebAssembly 前端复用。

## 4. 系统架构

```text
TOML source
    |
    v
lossless syntax package -----> exact source spans and trivia
    |                                      |
    |                                      v
    +----> semantic compatibility ----> diagnostics
    |             layer                    |
    v                                      v
edit operations ----------------------> text patches
    |                                      |
    +-------------------> apply atomically-+
                           |
                           v
                    updated TOML source

CLI: check/get/set/remove 调用上述公共包，不直接复制解析逻辑。
```

### 4.1 现有兼容层

根包继续提供 `parse`、`serialize`、`to_json`、`Table`、`Value` 和 `TomlError`。首先修正已知 TOML 1.0 误判和 MoonBit 弃用语法，再作为 Workbench 的语义检查器使用。

兼容层的职责是提供值语义；它不负责保留注释和原始格式。未来若改用或适配 `moonbit-community/toml-parser`，Lossless CST、诊断和补丁 API 不随之改变。

### 4.2 `syntax` 包

`syntax` 把源码拆为有序节点，并保留每个节点在原始字符串中的起止偏移。

核心类型：

```text
SourceSpan { start_offset, end_offset, line, column }
Trivia = Whitespace | Newline | Comment
SyntaxNode = KeyValue | TableHeader | ArrayTableHeader | Trivia | Invalid
Document { source, nodes }
```

`KeyValue` 至少记录规范化键路径、键区间、值区间、整行区间和关联 trivia。MVP 支持顶层键、点号键和普通表中的键。数组表内部的定位可读取和检查，但不作为首版自动修改的保证范围。

### 4.3 `diagnostics` 包

诊断类型：

```text
Diagnostic {
  severity: Error | Warning,
  code: String,
  message: String,
  span: SourceSpan,
  suggestion: Option[TextEdit]
}
```

首版错误来自严格 TOML 1.0 解析和路径解析；警告包括重复键、无法安全自动修改的路径以及 Workbench 尚不支持的编辑结构。诊断必须稳定排序，并能输出人类文本和 JSON，方便后续接入编辑器。

### 4.4 `edit` 包

公共操作：

- `set_value(document, key_path, encoded_value)`：替换已有值区间；找不到路径时，在确定的表尾插入新键。
- `remove_key(document, key_path)`：删除目标键值行，保留邻近注释；若注释位于同行则随该行删除。
- `apply_edits(source, edits)`：验证编辑区间不重叠，从后向前应用，返回新字符串。

首版的 `encoded_value` 必须先通过现有解析器验证为单个 TOML 值，禁止把任意文本直接拼入文档。任何定位歧义、无效值或重叠补丁都返回错误，不产生部分输出。

### 4.5 `cmd/workbench` 包

命令接口：

```text
toml-workbench check <file> [--json]
toml-workbench get <file> <key.path>
toml-workbench set <file> <key.path> <toml-value> [--write]
toml-workbench remove <file> <key.path> [--write]
```

默认情况下，修改命令把结果写到标准输出；只有显式 `--write` 才覆盖原文件。`--write` 使用同目录临时文件加重命名，避免中途失败破坏源文件。诊断写入标准错误；成功为退出码 0，语法或操作错误为非零退出码。

## 5. 数据流与错误处理

1. CLI 读取 UTF-8 文件。
2. `syntax` 生成 Lossless CST；无法识别的区域保留为 `Invalid` 节点。
3. 兼容层生成值语义或严格解析错误。
4. `diagnostics` 合并语法、语义和编辑能力诊断。
5. 只读命令直接输出结果；修改命令先生成 `TextEdit` 列表。
6. `apply_edits` 验证所有区间后一次性返回新文本。
7. `--write` 仅在完整结果生成并再次解析成功后执行原子替换。

任何失败均返回结构化错误；不得静默跳过、自动格式化整个文档或留下部分写入。

## 6. TOML 规范与现有实现修正

在新增 Workbench 功能前完成以下修正：

1. TOML 1.0 裸键只接受 ASCII 字母、数字、下划线和连字符。
2. TOML 1.0 内联表禁止普通换行和尾逗号。
3. 项目测试中把这些扩展语法标记为无效，而不是“extra valid”。
4. 实现 `toml-test` decoder：从标准输入读取 TOML，成功时输出 tagged JSON，失败时返回非零退出码。
5. 固定官方测试版本并在 CI 中记录通过数；README 不把项目内 289 个测试等同于官方一致性用例。
6. 消除当前工具链报告的弃用语法警告，新增代码不得引入警告。

## 7. 测试策略

### 7.1 单元与回归测试

- `syntax`：节点类型、键路径、偏移和 trivia 捕获。
- `diagnostics`：错误代码、范围、排序和 JSON 表示。
- `edit`：替换、插入、删除、区间冲突和无效值。
- TOML 1.0 回归：Unicode 裸键、多行内联表和尾逗号必须失败。

### 7.2 Golden tests

每个编辑用例同时保存输入和期望全文输出。除目标区间外，输出必须与输入逐字节相同，重点覆盖：

- 行尾注释；
- 不规则等号空格；
- CRLF 与 LF；
- 引号键和点号键；
- 多个表和空行；
- Unicode 字符串值。

### 7.3 官方一致性测试

CI 使用固定版本的 `toml-test` 调用 decoder。报告必须区分项目单元测试数量和官方 valid/invalid 结果。失败用例保留清单并说明原因，不使用“完整合规”掩盖差距。

### 7.4 CLI 集成测试

通过临时文件验证退出码、标准输出、标准错误和 `--write` 后内容。失败场景必须证明原文件未改变。

## 8. 申报与文档改造

### 8.1 README

README 首屏改为 MoonBit TOML Workbench，包含：

- 一句话用户价值；
- 与 `moonbit-community/toml-parser` 的关系；
- 当前已完成与计划中的能力；
- 三分钟 CLI 演示；
- 可复现测试命令和准确结果；
- 限制与路线图。

### 8.2 申报书

申报书必须新增“相关研究与已有项目”“差异化价值”“用户流程”“风险与缓解措施”。删除“生态首个”“完整合规”“生产可用”等没有证据的表述。

项目核心交付定义为 Lossless CST、诊断、补丁引擎和 CLI；现有解析器只列入前期原型基础。申报书区分补交时已实现功能和比赛开发期计划，避免把路线图写成完成事实。

### 8.3 对比矩阵

| 能力 | `moonbit-community/toml-parser` | MoonBit TOML Workbench |
|---|---|---|
| TOML 值语义解析 | 已有项目核心能力 | 兼容层，不作为创新点 |
| 普通序列化 | 已有 | 保留兼容 API |
| 注释/空白/原始字面量保留 | 截至 2026-08-18 未在上游 README 中列为核心能力 | 参赛核心 |
| 最小文本补丁 | 截至 2026-08-18 未在上游 README 中列为核心能力 | 参赛核心 |
| 结构化诊断与修复建议 | 基础错误处理 | 参赛核心 |
| Workbench CLI | 解析/验证 CLI | 检查和安全修改工作流 |

最终提交前应再次核对上游最新能力；若上游已实现表中某项，不隐藏事实，而是进一步收窄差异或改为协作扩展。

## 9. 实施阶段与提交边界

### 阶段 1：可信基线

- 修正 TOML 1.0 误判；
- 接入官方 decoder；
- 清理弃用警告；
- 更新项目定位和准确测试表述。

### 阶段 2：Lossless CST

- 建立 `syntax` 包和源码区间；
- 完成读取路径与 golden tests。

### 阶段 3：安全修改与 CLI

- 实现补丁引擎；
- 实现 `check/get/set/remove`；
- 完成临时文件和原子写入集成测试。

### 阶段 4：申报材料

- 更新 README、设计文档和申报书；
- 增加与已有项目的事实对比；
- 记录演示命令、实际测试结果、已知限制和比赛期路线图。

每个阶段使用真实的小步提交；不为了满足数量机械拆分无意义提交。

## 10. MVP 验收标准

1. `moon check`、`moon test`、`moon build`、`moon fmt --check` 全部成功。
2. 工具链不再报告现有弃用语法警告。
3. `toml-test` decoder 可被固定版本 runner 调用，README 记录真实结果。
4. `check` 能对有效文件返回 0，对无效文件返回非零并显示源码位置。
5. `set` 能修改顶层键、点号键和普通表键，且无关文本逐字节不变。
6. `remove` 能删除同样范围的键，且失败时不修改原文件。
7. README 和申报书明确披露已有 TOML 项目，并以 Workbench 能力作为核心交付。
8. 文档明确区分“当前完成”“MVP 验收后完成”和“比赛开发期计划”。

## 11. 风险与缓解

- **补交时间有限**：优先完成可信基线和 `set` 的保留格式闭环，`remove` 次之；Schema、LSP 和 Web UI 留到比赛开发期。
- **TOML 语法边界复杂**：首版遇到数组表歧义时拒绝修改并给出诊断，不做猜测性编辑。
- **官方测试暴露大量错误**：如实公布结果，按失败类别修复；初审材料强调可复现工程流程而非虚假满分。
- **上游能力继续演进**：重新提交前检查上游 README、发布记录和接口，更新对比矩阵。
- **CLI 文件写入风险**：默认只输出，`--write` 使用临时文件、再次解析和原子替换。

## 12. 初审成功表述边界

本设计旨在显著降低“与已有 TOML 解析库重叠”的风险，但不能保证组委会通过。对外表述只承诺已经实现和验证的事实。若组委会明确不接受 TOML 工具链扩展，应保留本仓库作为作品集，另选不与 MoonBit 生态现有项目重叠的系统型项目。
