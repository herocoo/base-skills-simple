---
name: base-code
description: 计划与代码阶段。已有 tech-design、要生成实现计划并落地代码时使用:在功能分支上先出计划、再测试先行地实现并按任务提交、收尾跑全量测试与类型检查。不使用 worktree。base 开发流程第三阶段,上游 base-tech,下游 base-review。
---

# base-code 计划与代码

在**功能分支**上开发(不建 worktree)。每个 group 两步:先出实现计划,再按计划实现。两步之间不停顿,用户的拦截点是计划摘要展示时和阶段闸门。

## 0. 入口

读 `references/protocol.md`(读不到试 `.kiro/skills/base-code/references/` 与 `~/.kiro/skills/base-code/references/`)。按 §1 完成入口(前置:tech 须 approved 或 skipped),再按 §4 确认 Group。

**执行模式**(Group 确认后问一次,能与 §1 的分支问题合并成一条消息就合并):
- `1 code 且自动 review(推荐)`:代码完成且检查全过后不停顿,同会话直接进入 base-review。
- `2 code`:走阶段闸门,通过后开新会话再运行 base-review。

写 `stages.code.mode`(`code+review` / `code`)。已有值(续作、重做、review 回退)→ 不再问,沿用并提示一行"执行模式:{mode}(要切换请直接说)"。

## 1. 分支准备(每个 repo 一次)

`repo` 相同的 group 共用一个功能分支,只处理一次。命令都带 `git -C {repo}`:

1. 已记录 `branch`(续作、重做、review 回退)→ 只核对 `git branch --show-current` 等于它。不等且工作区干净则 `git switch {branch}`;不干净按协议 §3 请用户先处理,**不要自行 stash 或丢弃**。然后跳到第 5 步。
2. 工作区必须干净:`git status --porcelain` 非空 → 请用户先提交或处理。`.base/` 不算脏;若它出现在输出里,说明忽略规则未生效,按协议 §1 第 3 步补上后再查。
3. `cur = git branch --show-current`。为空且 `git rev-parse HEAD` 成功(游离 HEAD)→ 请用户先切到一个分支。仓库还没有任何提交(`git rev-parse HEAD` 失败)→ 请用户确认后建空初始提交 `git -C {repo} commit --allow-empty -m "chore: init"`(没有它取不到 `baseCommit`;提交失败如缺 user.name / email,如实告诉用户),`cur` 取当前分支名。
4. 按协议 §3 问一次:
   - `1 在当前分支 {cur} 上直接开发`(`cur` 不是 main / master / develop / release/* 时推荐)
   - `2 新建功能分支并切换`(`cur` 是主干类分支时推荐)。默认名 `feature/{日期}-{需求名英文短名}`,可由用户改;分支已存在而本流程没记录过它 → 让用户换名。选 2 执行 `git switch -c {名字}`。
5. 写入该 repo 所有 group 的 `branch`、`baseBranch`(新建分支时为 `cur`;在当前分支开发时等于 `branch`)、`baseCommit = git rev-parse HEAD`(**首次取,之后不改**,是所有 diff 的固定起点)。

**项目存在性**:group 目录下应有工程标志(backend:`pom.xml` / `build.gradle*`;frontend:`package.json`)。缺失 → 问 `我手动创建` / `按技术方案搭建最小骨架(搭完请你确认)` / `取消`。搭建由主会话完成。

## 2. 每个 group 的流程

**执行单元** = `repo`。同一 repo 的 group 合并为一个单元,单元内按 `dependencies` 拓扑串行(提交不能交叉);**不同 repo 的单元互不影响,并行发起**(计划的并行见 2.1,代码的并行见 2.2)。依赖关系只决定 API 契约的先后(tech 阶段已定稿),不构成代码串行的理由。非续作时先置 `stages.code.progress = {}`。

> 并行时,**同一条消息内**发起多个委派(逐条发等于串行);一次最多 3 个单元,多了分批。写源码的任务只在同一单元内串行,不同 repo 的单元可以同时进行。

### 2.1 计划

- `progress.{g}.step` 已是 `planned` 或 `coded`(续作)→ 跳过。
- 读 `references/brief-plan.md`,任务单写到 `{flowDir}/briefs/plan-{g}.md`,委派 planner 角色 `base-planner`(预检见 §5.2)。变量:`group`、`workDir`、`branch`、`planPath`(`{flowDir}/impl-plan-{g}.md`)、`design`、`apiContracts`(本 group 的 + 依赖 group 的,有才列)、`explore`、`existingPlan` 与 `revisionNote`(重做才有,否则"无")。多个 group 的计划互相独立且只读,可并行(≤3 个);不同执行单元的计划优先并行,同单元内的 group 串行。
- 拿到结果后展示计划摘要(任务数、文件数、风险),**不读计划全文**,写 `step="planned"`,然后**直接进入 2.2,不询问**。只有两种情况停下按协议 §3 问:
  - 返回 `blocked`:`补信息后重派` / `回退到 base-tech` / `取消`。仓库无测试框架时 planner 也会走这里,选项里补一条 `不写自动化测试(本次)`,选它就把"用户确认本次不写自动化测试"写进 `revisionNote` 重派。
  - 计划任务数明显偏离方案(如方案 3 个模块、计划只列 1 个)。

### 2.2 实现

1. 记 `roundBase = git -C {repo} rev-parse HEAD` 写入 `progress.{g}.roundBase`。**已有值不重取**(续作时它决定本轮提交校验的范围)。**同一 repo 的 group 共用这一个值**:单元内第二个 group 直接复用第一个的 `roundBase`,不重新取。
   **不同 repo 的单元并行**:每个单元各跑 2.1 → 2.2,彼此不等待;同一单元内严格按拓扑串行。
2. 读 `references/brief-code.md`,任务单写到 `{flowDir}/briefs/code-{g}.md`,委派 coder 角色 `base-coder`。变量:`group`、`workDir`、`branch`、`planPath`、`doneTasks`(续作时填计划里已勾选 `[x]` 的任务标题与 `git log --oneline {roundBase}..HEAD`,否则"无")。
3. 核对返回值:
   - `checks` 含 `fail` 却报 `done` → 按 `blocked`。
   - `tdd` 的分子小于分母 → 不算失败,但在闸门摘要里如实列出("有 N 个任务未能先红后绿"),交给用户判断。
   - `blocked` → **先做第 4 步核实**(可能已落地部分提交),再按协议 §3 问 `补信息后重派` / `改计划后重派`(原因作为 `revisionNote` 回到 2.1) / `回退到 base-tech` / `取消`。
   - 批准了**不在计划文件清单内**的改动(如脚手架缺陷、配置开关)时,派发修复前追加到 `stages.code.scopeAdditions[]`:`{ group, file, reason }`,review 据此不判它们为"未授权偏离"。
4. **提交校验**(主会话自己做):
   - `git -C {repo} status --porcelain` 非空 → 回派一次"补提交未入提交的变更",附明确文件清单;不要自己 commit。
   - `git -C {repo} log --oneline {roundBase}..HEAD` 对照计划任务数。出现与任务无关的零散提交 → 告知用户,**不改写历史**。
5. 写 `step="coded"`,继续下一个 group。

### 2.3 续作与重做

- **续作**(in_progress):按各 group 的 `progress` 跳到对应步骤,`roundBase` 沿用。
- **重做**(entry=redo):读 `stages.code.note`、已有 `impl-plan-{g}.md`、最新 `tech-design-{g}.md`。**计划的修订仍走 2.1**:`existingPlan` 传旧计划路径,`revisionNote` 传反馈。反馈来自 review 回退时,把 `note` 里的报告路径一并交给计划步骤,**只修报告里本轮待修的编号**。旧提交保留,新修改增量提交,message 用 `fix({group}): {编号或模块}`。

## 3. 闸门与衔接

1. 展示摘要(取自返回值与 git 校验,不读源码):每 group 的提交数、文件数、`checks`、`tdd`;有 `scopeAdditions` 一并列出。再按 `stages.code.mode` 分流:
   - `code`:按协议 §3 走阶段闸门。不通过:反馈写 `note`,回到 2.1 重做。跳过:须同时跳过 review,并置顶层 `result=success`。
   - `code+review`:全部 group 的 `result=done`、`checks` 无 `fail`、提交校验无异常,且 `subagent.coder` 不是 `inline`(内联时本会话上下文已很大,不适合再同会话审查)→ **不询问,视为通过**。任一不满足 → 停下,说明原因,按 `code` 模式走闸门。用户的拦截点移到 review 闸门(可回退 base-code / base-tech)。
2. **通过**:写 `stages.code.status=approved`;`entry=redo` 时按协议 §6 级联失效 review。
3. 衔接:
   - `code`:按协议 §7 交接,下一步 `/base-review`。
   - `code+review`:**不输出 §7 的交接提示,也不建议开新会话**。读 base-review 的 `SKILL.md`(读不到试 `.kiro/skills/base-review/SKILL.md` 与 `~/.kiro/skills/base-review/SKILL.md`),按其"同会话衔接"在本会话直接执行。

**本阶段不合并分支**。
