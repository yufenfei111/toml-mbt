# MoonBit TOML Workbench 重新申报验收清单

> 核验日期：2026-08-20。`[x]` 表示已有本地或仓库证据；`[ ]` 表示仍需项目作者或最终控制任务完成。未勾选项不能因文档已经写好而视为完成。

## 先回答：是否只重新提交新申请书即可

**不建议只提交一份新文字。** 应先让报名表、约一页 PDF、公开仓库 `main`、CI、Mooncakes 版本和申请书中的链接指向同一份可验证成果，再提交更新后的报名信息。当前可直接作为内容底稿的是 [`docs/application.md`](application.md)，但在重新提交前仍须完成本文“提交前人工动作”中的所有项目。

建议提交顺序：

1. 将 `feature/toml-workbench` 的完整提交历史合并到 `main` 并推送；
2. 发布 `yufenfei111/toml-mbt@0.2.0`，记录可匿名访问的 Mooncakes 链接；
3. 用已审核的 [`docs/application.md`](application.md) 同步外部申报书并导出约一页 PDF；
4. 在未登录浏览器中检查仓库、CI、Mooncakes、PDF、`main` 和固定 commit 链接；
5. 更新报名表并在 **2026-08-24 24:00** 前重新提交。

## 官方要求摘要

2026-08-20 复核的主来源为 [MoonBit 开源创新赛官网](https://moonbitlang.github.io/OSC2026/)、[官方站点仓库](https://github.com/moonbitlang/OSC2026)及其[八月黑客松页面数据](https://github.com/moonbitlang/OSC2026/blob/main/site-assets/main.js)。八月黑客松沿用主赛道的主要规则和验收标准但不进入决赛；重复、拆分或仅作简单修改的项目不计入验收/奖励，截止时间为 **2026-08-24 24:00**。

与本项目直接相关的提交要求：

- 公开代码仓库，MoonBit 为主要实现语言；
- 清楚的 README、可运行示例、测试和 CI；
- 在 mooncakes.io 发布可验证版本；
- 使用 OSI 认可的开源许可证；
- 提供约一页的项目介绍 PDF；
- 已有项目可以继续参赛，但申请材料必须明确区分 2026-04-29 前的既有基础与此后有效新增工作；
- 不把与现有项目重叠、拆分或轻量修改的内容包装成新成果。

本清单是对官方公开页面的项目级执行解释；若报名系统字段或群内通知临时更新，以组委会最新通知为准，并通过 **CCF开源大赛-MoonBit赛题交流群** 或 MoonBit 小助手 `moonbit_helper` 确认。

## 给初审评委的说明

> 原申报与现有 TOML 解析器重叠。修订后的项目明确承认并区分 `moonbit-community/toml-parser`，把参赛增量收窄为保留格式的分析与安全源文本编辑。原解析器现在仅是兼容基础；无损语法、结构化诊断、补丁引擎和 Workbench CLI 才是本次可评审成果。

English reference note:

> The original submission overlapped with an existing TOML parser. The revised project explicitly acknowledges that work and narrows its contribution to format-preserving analysis and safe source editing. The parser is now compatibility infrastructure, while the lossless syntax, diagnostics, patch engine, and Workbench CLI are the reviewable hackathon deliverables.

## 2026-08-20 最终本地证据

| 核验项 | 实际结果 | 状态 |
| --- | --- | --- |
| 工具链 | Moon `0.1.20260807`；moonc `v0.10.7+bc794d341` | 通过 |
| 接口/格式 | `moon info` 通过；`moon fmt --check` 通过；实际 `moon fmt` 后 `git diff --exit-code` 无差异 | 通过 |
| 静态检查 | `moon check --deny-warn` exit 0 | 通过 |
| 项目测试 | `moon test`：**420/420** | 通过 |
| 原生 CLI 测试 | **11/11**；当前工具链另有 main-package blackbox 测试未来兼容提示 | 通过，提示已记录 |
| 原生构建 | `moon build --target native` exit 0 | 通过 |
| 官方套件 | `toml-test` v2.2.0：valid **181/205**、invalid **421/474**、exit 1 | 真实基线，仍有差距 |
| 三分钟演练 | `check/get/set` 预览/`set --write`/`remove` 预览均 exit 0；预览不写盘；CRLF、空格和注释保留；落盘文件与删除候选均重新解析成功 | 通过 |
| 仓库分支 | `feature/toml-workbench` 包含完整 Workbench 提交历史；尚未合并、推送 | 未完成 |
| Mooncakes | 旧解析器 `0.1.0` 已发布；Workbench 元数据为 `0.2.0`，尚未发布 | 未完成 |

官方复现使用正确的 v2 模块路径：

```powershell
moon build --release --target native cmd/toml-test-decoder
$env:TOML_TEST_DECODER_NO_BUILD = '1'
go run github.com/toml-lang/toml-test/v2/cmd/toml-test@v2.2.0 test `
  -timeout 10s -parallel 1 -decoder .\scripts\toml-test-decoder.cmd -color never
Remove-Item Env:TOML_TEST_DECODER_NO_BUILD
```

初始计划中的 `github.com/BurntSushi/toml-test/...@v2.2.0` 不能解析该版本；v2.2.0 的[官方 `go.mod`](https://raw.githubusercontent.com/toml-lang/toml-test/v2.2.0/go.mod)声明模块为 `github.com/toml-lang/toml-test/v2`。不得为了照抄旧命令而换回错误路径。

## 仓库与材料检查

- [x] README 标题和第一屏定位为 “MoonBit TOML Workbench”。
- [x] README 首屏承认持续维护的 [`moonbit-community/toml-parser`](https://github.com/moonbit-community/toml-parser)，并明确“不替代”。
- [x] [`docs/comparison.md`](comparison.md) 使用有日期、可追溯且中性的能力比较，不声称对方源码中不存在未核验能力。
- [x] 申请书把旧的解析器基础与 2026-08-18 至 2026-08-20 的新增 Workbench 成果分开。
- [x] 已完成功能与“路线图/尚未完成”在 README 和申请书中分开。
- [x] README 提供可执行的三分钟演示、架构、测试命令和精确输出说明。
- [x] CI 配置包含 deny-warn、项目测试、格式检查以及固定 `toml-test` v2.2.0 非回归基线。
- [x] 官方结果写作 valid 181/205、invalid 421/474，并明确 exit 1 与剩余差距；没有“全部用例已通过”的暗示。
- [x] 已披露三个无效日期时间输入的 native decoder 异常、受限编辑、可信路径/无并发写入假设和元数据保留限制。
- [x] 根目录存在 OSI 认可的 [Apache-2.0 `LICENSE`](../LICENSE)。
- [x] [`docs/application.md`](application.md) 已包含驳回整改、差异、证据、边界、三分钟评审和后续计划。
- [x] 本地三分钟评审路径已从全新临时目录中的注释 TOML 样例复演。
- [ ] 将 GitHub 仓库 About/Description 更新为“Format-preserving TOML inspection and safe editing Workbench for MoonBit”，并补充合适 topics。
- [ ] 将完整 Workbench 历史合并到默认分支并推送；不要只复制最终文件而丢失开发历史。
- [ ] 等推送后的 GitHub Actions 完成，记录公开且通过的 CI run 链接。
- [ ] 在未登录/无缓存浏览器中按 README 再执行一次演示，并确认相对链接均可访问。

## 发布、PDF 与报名表

- [x] 旧包 [`yufenfei111/toml-mbt@0.1.0`](https://mooncakes.io/docs/yufenfei111/toml-mbt) 与未发布 Workbench `0.2.0` 的状态已明确区分。
- [ ] 正式执行并核验 `moon publish`，确认 mooncakes.io 展示 `0.2.0`；dry-run 或 `202 Accepted` 不能代替发布成功。
- [ ] 把 `0.2.0` 的最终公开链接回填到 README、申请书、PDF 和报名表。
- [x] 已审核的 [`docs/application.md`](application.md) 已同步到工作区外的 `C:\Users\雨\Desktop\github\申报书.md`，内容一致。
- [x] 已按官方要求导出 [一页 PDF](../output/pdf/MoonBit-TOML-Workbench-八月黑客松重新申报书.pdf)，并检查页数、字体嵌入、乱码、截断、视觉布局和超链接注释。
- [ ] 把 PDF 放到可匿名访问的位置，在退出登录的窗口中下载复核，并将 URL 填入报名表。
- [ ] 确认报名表项目名、仓库 URL、Mooncakes URL、PDF URL、项目说明和联系人信息完全一致。
- [ ] 在不登录 GitHub/Mooncakes/文档托管服务的浏览器中逐一检查所有 `main`、固定 commit、CI、版本和 PDF 链接。
- [ ] 通过赛事微信群或 MoonBit 小助手 `moonbit_helper` 确认“修改原报名还是新建报名”的最新操作口径；保留沟通截图。
- [ ] 在 **2026-08-24 24:00** 前提交更新后的报名表，并保存成功页面/邮件回执。

## 提交前最后否决条件

出现以下任一情况，不应直接点击重新提交：

- 公开 `main` 仍是旧解析库，或申请书链接无法匿名打开；
- Mooncakes 仍只显示 `0.1.0`，但材料声称 Workbench `0.2.0` 已发布；
- PDF 与 [`docs/application.md`](application.md) 内容不一致；
- 把 420 个项目测试写成 420 个官方一致性用例；
- 把官方 exit 1 或 181/205、421/474 描述成全部用例通过；
- 未明确承认并区分 `moonbit-community/toml-parser`；
- 把路线图当成已完成功能；
- 未在截止时间前获得报名成功回执。
