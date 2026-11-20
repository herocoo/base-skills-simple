# base-skills-simple

面向 Kiro 的 base 开发流程精简版:`prod → tech → code → review` 四个技能,不依赖其他技能、插件、MCP,不使用 worktree,直接在功能分支上开发。

## 与原版 base-skills 的差异

| 项 | 原版 | 本版 |
|---|---|---|
| 隔离方式 | per-group git worktree | 功能分支,不建 worktree;同一 repo 的 group 共用一个分支 |
| 状态文件 | flow-state.json + PowerShell 脚本定点读写 | 沿用原版命名:状态 `.base/dev/{flowId}-flow-state.json`,产物目录 `.base/dev/{flowId}-outputs/`(两者并列);字段精简,主会话读-改-整文件写回,无脚本依赖 |
| 提问 | `AskUserQuestion` | 正文提问 + 编号选项,等用户回复(文档的内置工具清单里没有提问工具) |
| 头脑风暴 / 写计划 / TDD | 依赖 superpowers 等外部技能 | 写进技能自身:base-prod 的需求澄清(复述、开放提问、非目标、"我的假设")、base-tech 的方案收敛(备选与取舍、"用户决定/我的决定"、实施者自检)、base-code 的计划任务单、任务单里的 TDD 纪律(红 → 绿 → 重构;先写实现要删掉重来;仓库无测试框架时 planner 返回 blocked,由用户选搭建框架或本次不写自动化测试;coder 返回 `tdd: 先红后绿数/应写测试数` 供闸门核对,该数字是模型自报,没有独立验证手段)。**没有搬过来的**:superpowers 的"每次只问一个问题"(改为 ≤2 轮一次问全,省上下文)、浏览器可视化陪伴、设计文档的子代理审阅(prod/tech 阶段闸门由用户审) |
| 子代理 | 三个专用 agent,按 `general-purpose` 兜底 | 四个角色 agent(JSON):`base-explorer` / `base-planner` / `base-coder` / `base-reviewer`,配合任务单;**先预检再用,不可用就内联**,流程不依赖它 |
| 模型分工 | 代码波指定 sonnet | 每个角色 agent 各有可选的 `model` 字段,安装时指定;不指定就跟随会话默认模型 |
| code → review 衔接 | base-code 入口可选 `code 且自动 review`,同会话直接审查 | 保留,状态里记 `stages.code.mode`。简化版多一条保护:`coder` 降级为内联时不自动衔接,走阶段闸门并开新会话 |
| 审查重审 | 增量 + verify 模式 + 遗留项 | 首轮全量;修复后只审增量(`fixBase..HEAD`),只核对本轮圈定的编号和修复引入的新问题,读上轮报告而不重读技术方案,只重派修过的 group;每个 group 只保留一份报告 `review-{g}.md`,每轮覆盖;diff 排除锁文件与构建产物;不维护遗留项;修复循环上限仍为 2 轮 |
| 并行 | 按执行单元并行 | 执行单元 = repo:同 repo 的 group 串行(共用分支,提交不能交叉),不同 repo 的计划、实现、修复并行(≤3,同一条消息内发起);探索、审查只读,按 group 并行 |
| 前端原型 | 可调用 `frontend-design` | 保留"低保真/高保真"选项,由主会话直接写 HTML |

## 目录

```
base-prod/ base-tech/ base-code/ base-review/   四个技能(SKILL.md + references/,prod 与 tech 另有 assets/ 模板)
agents/base-*.json                              四个角色子代理定义,JSON 格式(可选安装)
shared/protocol.md                              协议唯一源,install.ps1 安装时同步到四个技能
models.json                                     各角色模型 ID(填了就写进对应 agent;null 表示不指定)
install.ps1                                     Windows 安装脚本
install.sh                                      Linux / macOS 安装脚本(功能与 install.ps1 对等)
```

每个技能里的 `references/protocol.md` 是 `shared/protocol.md` 的相同副本:技能需要自包含,不跨技能读文件。

## 安装

```powershell
.\install.ps1                  # 默认装到 ~\.kiro\(全局,所有项目可用)
.\install.ps1 -Target D:\proj  # 装到指定工作区 D:\proj\.kiro\(可随仓库提交共享);当前目录用 -Target .
.\install.ps1 -Check           # 只检查,不改动(会显示每个 agent 当前的 model)
```

Linux / macOS(需要 bash;有 python3 或 jq 时会额外校验 JSON):

```bash
bash install.sh                        # 默认装到 ~/.kiro/(全局,所有项目可用)
bash install.sh --target ~/proj        # 装到指定工作区 ~/proj/.kiro/;当前目录用 --target .
bash install.sh --check                # 只检查,不改动
bash install.sh --coder-model <ID> --reviewer-model <ID>   # 指定模型,优先于 models.json
```

一行命令(克隆并安装,不保留源码目录):

```bash
git clone --depth 1 https://github.com/herocoo/base-skills-simple.git /tmp/base-skills-simple && bash /tmp/base-skills-simple/install.sh && rm -rf /tmp/base-skills-simple
```

安装后新开一个会话,输入 `/` 应能看到 `base-prod`、`base-tech`、`base-code`、`base-review`。

同名时工作区优先于全局。**自定义 agent 默认不加载技能**:若你在用自定义主 agent,需在它的 `resources` 加 `skill://.kiro/skills/*/SKILL.md`(全局技能再加 `skill://~/.kiro/skills/*/SKILL.md`)。本流程的四个子代理**不需要**配 `resources`:任务单由主会话填好变量后直接作为消息发给它们(不落盘),不依赖技能。

### 指定子代理模型

四个角色可以各用各的模型,典型做法是实现和修复用性价比高的模型,审查用更强的模型。

```powershell
.\install.ps1 -CoderModel <ID> -ReviewerModel <ID>
```

也可以把 ID 填进 `models.json`(`explorer` / `planner` / `coder` / `reviewer` 四项),再运行 `.\install.ps1`。命令行参数优先于 `models.json`;两处都没填,就不写 `model` 字段,该角色跟随会话默认模型。安装结果就是 `.kiro/agents/{name}.json` 里的 `"model"` 字段,也可以直接手改这个文件。

**模型 ID 要自己从环境里取,不要猜。** 文档只列出了模型的显示名(例如 Opus 5.5、Sonnet 5.5、Haiku 5.5),没有给出这些模型对应的 ID 字符串;文档里原样出现过的 ID 只有 `claude-sonnet-4.6`、`claude-opus-4.7`、`claude-opus-4.8`、`gpt-5.6-sol`、`gpt-5.6-terra`。取法:

- 会话里输入 `/model` 看列表;
- 或在终端运行 `kiro-cli chat --list-models --format json`。

注意三点:`kiro-cli chat --model <ID>` 启动参数会覆盖 agent 里的 `model`;模型不可用时文档说首个提示可能直接失败、不会自动回退;每次委派时单独选模型,文档没有写明支持,所以只能按角色在 agent 文件里固定。如果填错了 ID,预检的冒烟那一步会失败,该角色降级为内联,并提示你修正 `model`。

## 使用

1. `/base-prod` 写产品文档 → 通过
2. 新会话 `/base-tech` 写技术方案 → 通过
3. 新会话 `/base-code` 写计划与代码 → 通过
4. 新会话 `/base-review` 审查、修复、合并

每阶段结束都有闸门(通过 / 不通过 / 跳过),状态在 `{工作区}/.base/dev/{flowId}-flow-state.json`,产物在 `{工作区}/.base/dev/{flowId}-outputs/`(只写流程必需的文件:prod-design、tech-explore、tech-design、被依赖时的 api-contract、impl-plan、review 报告)。中途中断后重新运行同一技能即可续作。

## 子代理:怎么保证"一定能用"

子代理只用来隔离上下文。**每个委派点都有等价的内联路径**,所以即使子代理完全不可用,流程也能跑完(代价是主会话上下文更大,每个 group 做完建议开新会话)。

第一次需要某个角色的子代理时做三步预检,结果按角色写入 flow-state.json 的 `subagent`(`explorer` / `planner` / `coder` / `reviewer`):

1. 当前会话工具列表里是否有 `invoke_sub_agent`(或名称含 `subagent` 的工具)。
2. 对应的 `{agent}.json` 是否存在于 `.kiro/agents/` 或 `~/.kiro/agents/`。
3. 冒烟:点名委派一句"只回复 base-ok",收到才判定可用。

任何一步失败,该角色降级为内联,并把原因告诉你。四个角色互不影响:比如只装了 `base-coder`,探索、计划、审查就内联,实现和修复仍走子代理。

### 已核实与未能核实(来源:kiro.dev/docs 的 subagents、configuration-reference、tools、permissions、skills 页)

| 已核实 | 文档**没写明**,本流程按保守处理 |
|---|---|
| 委派工具名是 `invoke_sub_agent`,IDE 与 CLI V3 都有 | 每次调用能否单独指定模型(本流程改为按角色在 agent 文件里固定) |
| 自定义 agent 可被点名调用,名字不存在不会回退到默认 | 子代理能否向用户提问 / 能否再嵌套 |
| agent 用 JSON 定义,放 `.kiro/agents/{name}.json`,文件名即 agent 名;JSON 在各版本通用,Markdown 仅 IDE 1.x 与 CLI V3 | 返回内容的格式 |
| agent JSON 有 `model` 字段(字符串 ID);启动参数 `--model` 会覆盖它 | Opus / Sonnet / Haiku 5.x 的 ID 字符串 |
| 父会话与子代理的权限取更严者;headless 下 `ask` 视为 `deny` | 子代理是否继承主会话已加载的 skills(本流程不依赖,任务单自包含) |
| 并行在四端均支持 | 并行数量上限(本流程自限 ≤3) |
| 多数写操作会弹确认 | |
| 自定义 agent 默认不加载 skills,要在它的 `resources` 里用 `skill://` 显式添加(skills 页) | |

## 兼容性与已知限制

- 目标版本:IDE 1.x、CLI V3(文档中 Skills、Steering、子代理、权限均以此为准)。**调研时官方 changelog 与文档里没有找到名为"Kiro 2.0"的版本**,所以本版按文档当前的版本体系(IDE 1.x / CLI 3.x)编写。CLI 2.x 只认 JSON 格式的 agent,会触发预检失败并内联,流程仍可跑。
- 文档里没有提问工具、没有 todo 工具(CLI V3),因此全部用正文提问与复选框。
- Skills 里相对路径(`references/…`)的解析基准,文档**未明确说明**。各 SKILL.md 因此写了回退路径(工作区、全局两处 `.kiro/skills/{名}/`)。
- Windows 下 shell 为 PowerShell:协议里已避免 `&&` 与 `$(...)`。
- 子代理产出以**产物文件与 git 实况**为准核对,不信任返回文字。

## 维护

`shared/protocol.md` 是协议唯一源。`install.ps1` 每次安装前会把它同步到四个技能的 `references/`,改完协议直接重新安装即可;只想同步不安装,运行 `.\install.ps1 -SyncOnly`。
