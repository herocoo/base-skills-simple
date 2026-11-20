# base 流程共享协议

> 四个技能的 `references/` 下各有一份相同副本(技能须自包含)。修改后运行 `install.ps1 -SyncOnly`。

## 0. 约定

- **技能目录**:含本技能 `SKILL.md` 的目录。`references/…`、`assets/…` 相对它读取,读不到依次试 `.kiro/skills/{技能名}/`(工作区)、`~/.kiro/skills/{技能名}/`(全局)。
- **`{root}`**:工作区根目录绝对路径(首次用 `pwd`,PowerShell 用 `Get-Location` 确认)。**`{flowDir}`** = `{root}/.base/dev/{flowId}-outputs/`,存放全部阶段产物;**`{statePath}`** = `{root}/.base/dev/{flowId}-flow-state.json`,状态文件,与产物目录并列,不放进产物目录。**读写一律用绝对路径。**阶段产物(含 demo.html 原型)只写进 `{flowDir}`,不写进工作区根目录或"涉及项目"的目录。
- **阶段** `prod → tech → code → review` 各为独立技能,只经 `{statePath}` 衔接。
- **产物文件名固定,不登记进 flow-state.json**:`prod-design.md`、`demo.html`(可选)、`tech-explore-{g}.md`、`tech-design-{g}.md`(末尾含决策记录)、`api-contract-{g}.md`(仅被其他 group 依赖时)、`impl-plan-{g}.md`、`review-{g}.md`(每轮覆盖)。`{g}` = group 名。**只写流程必需的文件**:任务单不落盘,收敛结论写进 tech-design,不另建中间文档。
- "读/写文件""执行命令"指客户端内置工具,不硬编码工具名。Windows 的 shell 是 PowerShell:多条命令分开执行,不用 `&&`、`$(...)`。
- 不依赖提问工具、todo 工具、其他技能与插件:提问按 §3 在正文里完成,进度靠 flow-state.json 与计划里的复选框。

## 1. 入口

1. **扫描** `{root}/.base/dev/*-flow-state.json`,忽略 `result` 非 null 的。
   - 有未完成流程:按 `updatedAt` 倒序列出(flowId = 文件名去掉 `-flow-state.json` / 当前阶段 / 状态),按 §3 问 `继续某流程` / `新建流程` / `废弃某流程`(置 `result=abandoned`,不删文件)。当前阶段 = 首个 status 不是 approved/skipped 的阶段。
   - 没有:新建。
   - `.base/dev/` 为空但用户说"继续":先确认当前目录是不是原目录,不要静默重建。
2. **新建**:问需求名;取日期(PowerShell `Get-Date -Format yyyy-MM-dd`,其他 `date +%F`);`flowId = {日期}-{需求名}`(去掉 `\ / : * ? " < > |`,空格换 `-`);建 `{flowDir}`,按 §2 写初始 `{statePath}`。
3. **忽略规则**(每次入口都检查):`{root}` 在 git 仓库内且 `git -C {root} check-ignore -q .base/dev/x` 退出码非 0 → 用 `git -C {root} rev-parse --git-path info/exclude` 取文件路径(相对路径基于 `{root}` 拼成绝对路径),写文件工具追加一行 `.base/`(写 `.git/` 会请求批准,属正常)。不改项目 `.gitignore`。
4. **前置**:上游阶段须 approved 或 skipped,否则提示"请先运行 base-{上游}"并停止。
5. **入场判断**(本阶段 status):

   | status | 行为 |
   |---|---|
   | pending | 首次,`entry=first` |
   | in_progress | 上次中断。按 §3 问 `继续(复用已有产物)` / `从头重做` / `取消` |
   | approved | 问 `查看产物` / `重新执行`(`entry=redo`) |
   | stale | 提示"上游已变更:{note}",直接重做(`entry=redo`),以已有产物和 `note` 为基础 |
   | skipped | 提示已跳过,问是否仍要执行 |

   开始时写 `status=in_progress` 与 `entry`。**续作不改写 `entry`**。

## 2. flow-state.json

```json
{
  "flowId": "2026-11-19-用户登录",
  "updatedAt": "2026-11-19T10:00:00",
  "result": null,
  "stages": {
    "prod":   { "status": "pending", "entry": null, "note": null },
    "tech":   { "status": "pending", "entry": null, "note": null },
    "code":   { "status": "pending", "entry": null, "note": null },
    "review": { "status": "pending", "entry": null, "note": null }
  },
  "groups": [],
  "dependencies": {},
  "subagent": { "explorer": null, "planner": null, "coder": null, "reviewer": null }
}
```

- `status`:`pending / in_progress / approved / skipped / stale`。"不通过"不单设状态:留在 `in_progress`,反馈写 `note`。
- `entry`:`first` / `redo`(从 approved 或 stale 进入),通过时据此判断是否级联(§6)。`note`:返工、上游变更或跳过的原因,一两句话。
- `result`(顶层):`null` 进行中 / `success` / `failed` / `abandoned`,非 null 即了结。
- `groups[]`:`{ name, type(backend|frontend), path, exposesApi, repo, branch, baseBranch, baseCommit }`。`path` 相对 `{root}` 或绝对;`repo` 由 §4 写入;`branch`、`baseBranch`、`baseCommit` 由 base-code 写入(`baseCommit` 只首次写,是所有 diff 的固定起点)。`dependencies`:`{ 消费方: [被依赖方…] }`。
- `subagent`:按角色记预检结果,取 `"custom"` / `"inline"` / `null`(未预检),见 §5。
- 阶段私有字段由各技能负责:
  - code:`stages.code.mode`(`code` / `code+review`,执行模式,问过一次后沿用)、`stages.code.progress.{g} = { step: "planned"|"coded", roundBase }`;`stages.code.scopeAdditions[] = { group, file, reason }`。
  - review:`fixRound`(修复循环唯一计数器,上限 2)、`fixBase.{repo}`、`reports.{g} = { path, result, round }`、`waived.{g}[] = { file, issue, reason }`、`merge.{repo}`(`merged` / `kept` / `in-place`)。

**写入纪律**:每次**读 → 改 → 整文件写回**,只改本次涉及的字段,其余原样保留(尤其 `groups` 的 git 信息、`note`、`entry`),并更新 `updatedAt`(PowerShell `Get-Date -Format s`,其他 `date +%FT%T`)。只有主会话写 flow-state.json,子代理不写。

## 3. 提问与闸门

没有内置提问工具,统一这样做:

- 问题写在回复正文里,**然后结束本轮,等用户回复**。收到回答前,不做依赖该回答的动作。
- 格式:每题一行问题 + 编号选项,推荐项放第一个并写理由。一次最多 4 题,每题 2–4 个选项,末尾写"回复如 `1:2 2:1`,或直接说你的想法"。用户可以不选而自由回答。
- 需求/方案澄清最多 2 轮。影响走向的决策一次问全,不逐条追问。
- **阶段闸门**:先把本阶段 `status` 写成 `in_progress`,再展示摘要与产物路径,选项固定为 `1 通过 / 2 不通过(请说明原因) / 3 跳过本阶段`(review 无跳过)。回复不明确就重问,**不默认通过**。用户中途给出修改意见,等同"不通过"。
- 跳过规则:review 不可跳过(流程终点);跳过 code 必须同时跳过 review,并置顶层 `result=success`。

## 4. Group 确认(tech / code / review)

`groups` 非空 → 直接使用。否则:

1. 来源:prod approved → 读 `prod-design.md` 的"涉及项目"表;表为空或 prod 已跳过 → 扫描 `{root}` 及下一层子目录的 `pom.xml`、`build.gradle*`、`package.json`。
2. 展示候选(name / type / path / exposesApi),按 §3 请用户确认并补充;group 多于 1 个时再问依赖(谁调用谁的 API)。
3. 每个 group 的目录须存在;不存在(新项目)就按 §3 问 `创建空目录` / `改路径` / `取消`。`git -C {path} rev-parse --show-toplevel` 的结果写入 `repo`;不是 git 仓库时 tech 可继续,code 入口须先经用户确认执行 `git -C {path} init`,init 后重写 `repo` 并重做 §1 第 3 步的忽略规则。
4. `path` 在 `{root}` 之外 → 提醒:Kiro 默认只信任工作区,跨目录读写会反复请求授权,建议把公共父目录作为工作区打开;用户可选择继续。
5. 写入 `groups`、`dependencies`。**执行顺序**按依赖拓扑,被依赖方先;无依赖按数组顺序。同一 `repo` 的多个 group 共用一个功能分支。

## 5. 子代理(预检 → 委派 → 降级)

子代理只用来隔离上下文,**不是流程依赖**:任何委派都能由主会话内联完成(§5.4)。文档没写明的行为一律不假设:子代理不得向用户提问、不得再启动子代理、不依赖它加载 skills,返回文字不可信,成败以**产物文件与 git 实况**为准。子代理的工具调用同时受父会话与子代理权限约束(取更严者),弹确认属正常;headless 下被拒则内联。

### 5.1 角色

| 角色(`subagent` 的键) | agent | 用于 |
|---|---|---|
| explorer | `base-explorer` | tech 阶段代码探索 |
| planner | `base-planner` | code 阶段生成实现计划 |
| coder | `base-coder` | code 阶段实现、review 阶段修复 |
| reviewer | `base-reviewer` | review 阶段审查 |

agent 是 `{root}/.kiro/agents/{agent}.json` 或 `~/.kiro/agents/{agent}.json`,JSON 格式,文件名即 agent 名,各自可设 `model`。只读任务(探索、审查)可并行,一次 ≤3 个,**并行时同一条消息内发起**;写源码的任务同一 repo 内串行,不同 repo 可并行。

### 5.2 预检

按角色惰性做:某角色第一次需要委派时检查,结果写 `subagent.{角色}`,已有值则跳过。

1. **工具**:当前工具里是否有子代理委派工具(`invoke_sub_agent` 或名称含 `subagent`)。没有 → 四个角色一并置 `inline`,并说明原因(客户端不支持,或主 agent 的 `tools` 未含 `subagent`)。
2. **配置**:`{agent}.json` 是否存在于上述两处目录。不存在 → 按 §3 问 `我去安装后重试`(给出 README 的安装命令)/ `本流程内联执行` / `取消`。工作区 agent 仅在工作区受信任时加载。
3. **冒烟**:点名委派该 agent,任务只有一句"只回复 `base-ok` 一个词,不读写文件,不执行命令。"。回复含 `base-ok` → `custom`;报错、未知 agent、无回复 → `inline`,把原始报错一行展示给用户,不重试。报错与模型有关(不存在或无权限)时,提示用户核对该 agent JSON 的 `model`(ID 取自 `/model` 列表)或删掉该字段。

### 5.3 委派(`subagent.{角色} == "custom"`)

1. 读本技能 `references/brief-*.md` 任务单模板,把 `{{变量}}` 全部替换成实际值(绝对路径),**不写文件**。
2. 委派消息 = 一行 `使用 {agent} 子代理执行下面的任务单。严格照做,完成后只输出任务单规定的"完成标志"。` + 空行 + 任务单全文。并行时每个任务各发一次委派,**在同一条消息内发起**。
3. 返回后核对"完成标志"字段是否齐全;缺失或与产物/git 不符时以实况为准,仍无法判断按 `blocked` 处理。

### 5.4 内联(`subagent.{角色} == "inline"`)

主会话按同一份任务单模板执行:替换变量后照做,遵守其中全部约束,同样输出"完成标志"各行。代价是读写量落在主会话上下文,每个 group 完成后建议开新会话再继续(进度在 flow-state.json 与计划复选框里,可续作)。

## 6. 级联失效与回退

- **级联**:本阶段以 `entry=redo` 通过时,所有下游 approved 阶段**无条件**置 `stale`,`note = "上游 {stage} 于 {时间} 变更"`;已是 stale 的下游同样改写 `note`(否则旧原因会残留)。不做时间比对。
- **回退**(下游发现上游问题,如 review 回退 code/tech):上游阶段写 `status=stale`、`note=问题摘要`;下游各阶段 `stale` 并写原因。回退修复(review → code)不回收功能分支,由 code 在原分支继续。

## 7. 交接

阶段通过后输出:

```
✅ {stage} 已通过,产物在 {flowDir}。
下一步:开新会话(CLI 输入 /clear,IDE 新建 Chat)后运行 /base-{下游}。
```

例外:base-code 以 `code+review` 模式自动衔接时不输出本提示,同会话直接进入 base-review。review 通过后改为"✅ base 流程已完成",并写明代码所在分支与是否已合并。
