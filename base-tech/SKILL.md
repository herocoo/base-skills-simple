---
name: base-tech
description: 技术方案阶段。已有 prod-design 或明确需求、要出技术方案时使用,产出 tech-design 与 api-contract(支持多项目、前后端分组,按依赖顺序逐个推进)。base 开发流程第二阶段,上游 base-prod,下游 base-code。
---

# base-tech 技术方案

先探索现有代码(只读),再用提问收敛方向,最后按模板写技术方案和 API 契约。

## 0. 先读协议

读 `references/protocol.md`(读不到试 `.kiro/skills/base-tech/references/` 与 `~/.kiro/skills/base-tech/references/`)。按 §1 完成入口(前置:prod 须 approved 或 skipped),再按 §4 确认 Group。按 `dependencies` 拓扑**逐个 group 串行**:被依赖方的契约定稿前,依赖方不进入收敛。

## 1. 单个 group 的流程

1. **收集上游契约**:读所有直接依赖 group 的 `api-contract-{dep}.md`,作为收敛时的背景,把范围收窄到本 group 的实现层面。

2. **代码探索**(不让 20–40k 的源码进入主会话):
   - 已有 `tech-explore-{g}.md` 且是重做 → 复用;仅当本次改动涉及报告未覆盖的模块才重新探索。
   - 否则读 `references/brief-explore.md`,任务单写到 `{flowDir}/briefs/explore-{g}.md`,委派 explorer 角色 `base-explorer`(预检见 §5.2)。变量:`group`、`groupType`、`workDir`(group.path 绝对路径)、`reportPath`(`{flowDir}/tech-explore-{g}.md`)、`focus`(本次需求涉及的能力点 2–4 条)、`apiContracts`、`prodDesign`。同层无依赖的 group 可并行(≤3 个),**同一条消息内发起**(逐条发等于串行)。
   - 只读 `tech-explore-{g}.md`,**不在主会话重新读源码**,报告不足就再探索一次。

3. **头脑风暴(收敛方向)**:
   - 先读探索报告、上游契约和 prod-design;用户已定的(范围、非目标、已选方案)不重问,也不推翻。
   - **列做法**:列出真正可行的 2–3 种(去掉与用户目标冲突的、被现有代码排除的),每种结合探索报告落到本仓库(复用哪个模块、改哪里)并写明取舍,先亮推荐与理由。只有一种合理做法就直说,并说明其他做法为何不适用。按需求做,不为未来可能用到的东西加设计。
   - **谁来拍板**:用户在问取舍或技术细节 → 给选项和推荐让其选;用户只谈结果 → 你定并用一行说明,记为"我的决定",不当作用户同意过。
   - 影响架构走向的决策按协议 §3 **一次问全**,每题说明答案会改变什么;提问前先用 ≤200 字复述你的理解(目标、范围、非目标、已定的、你倾向的),便于用户顺手纠正。一轮不够可再问一轮,**全程 ≤2 轮**。其余细节按推荐方案处理,不逐条追问。
   - 把结论写入 `{flowDir}/tech-converge-{g}.md`:备选方案(各一行取舍)、推荐方案与理由、关键约束、非目标、已决策点(标"用户决定"或"我的决定")、待明确点。

4. **撰写方案**:backend 用 `assets/tech-design-backend-template.md`,frontend 用 `assets/tech-design-frontend-template.md`,写入 `{flowDir}/tech-design-{g}.md`。
   - 保留:决策结论与理由、接口签名代码块、字段表、文件清单(一句话职责)、错误码与异常约定。
   - 禁止:模板里的说明文字、示例业务实现、伪代码、被否决方案的完整论述(只留一行结论)、空小节、占位符、TBD。模板里没有对应内容的章节直接删。
   - 体积目标 ≤48 KB/group(软限)。写完自检大小:超标先删示例和冗余论述,**不删决策内容与接口签名**;删完仍超就在首行写 `> 体积 X KB / 目标 48 KB`,直接交付。
   - **实施者自检**(不读源码):站在"要照着方案实现、又不能再问用户"的人的角度读一遍。接口签名、字段、错误码、文件清单有缺就补;只有用户能回答的缺口不要自己编,列入闸门摘要的"待确认"。

5. **API 契约**(仅 `exposesApi=true` 的 group):按 `assets/api-contract-template.md` 写 `{flowDir}/api-contract-{g}.md`,只写调用方需要的路径、方法、入参、出参、错误码,目标 ≤16 KB(约 8–15 个接口);超标同样在首行写明体积。

## 2. 重做(entry=redo)

先读已有的 `tech-converge-{g}.md`、`tech-design-{g}.md` 和 `stages.tech.note`,在此基础上调整,不推翻已论证的取舍。

## 3. 闸门与衔接

1. 展示各 group 的方案摘要(决策要点、接口数、风险),单列"我的决定"与"待确认"供核对,按协议 §3 走阶段闸门(通过 / 不通过 / 跳过)。不通过:按反馈修改对应 group 后重审。跳过:`status=skipped`。
2. **通过**:写 `stages.tech.status=approved`;`entry=redo` 时按协议 §6 级联失效下游。
3. 按协议 §7 输出交接提示,下一步 `/base-code`。
