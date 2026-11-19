---
name: base-review
description: 代码审查阶段。代码已完成、要做审查时使用:对功能分支的全部变更做只读审查并产出报告,按需自动修复后重审,通过后决定是否合并到基线分支。不编译、不使用 worktree。base 开发流程第四阶段(终点),上游 base-code。
---

# base-review 代码审查

审查 base-code 在功能分支上的全部变更。审查只读,修复经任务单交给子代理(或内联)。不编译、不跑测试:code 阶段与修复步骤已跑过全量测试和类型检查。

## 0. 入口

**同会话衔接**(base-code 以 `code+review` 模式完成后进入):协议已读(内容相同),flowId、`{statePath}`、groups、分支信息都在会话里,**跳过读协议、协议 §1 入口和 §4 Group 确认**,直接从下面的初始化开始。`references/…` 相对本技能目录读取,读不到试 `.kiro/skills/base-review/references/` 与 `~/.kiro/skills/base-review/references/`。此时按非续作(首次)初始化。

否则:读 `references/protocol.md`(读不到试 `.kiro/skills/base-review/references/` 与 `~/.kiro/skills/base-review/references/`)。按 §1 完成入口(前置:code 须 approved 或 skipped;**review 不可跳过**),再按 §4 确认 Group。然后:

- 写 `stages.review.status=in_progress`。非续作(首次、stale 重做)初始化 `fixRound=0`、`reports={}`、`waived={}`;续作保留 `fixRound`。
- 续作时对每个 repo 跑 `git -C {repo} status --porcelain`。非空说明修复中断留下了未提交改动 → 按 §3 问 `丢弃未提交改动后重审`(推荐;`git -C {repo} restore --staged --worktree .`,**用户确认后才执行**)/ `保留,我手动处理` / `取消`。
- 每个 repo 当前分支须等于 `groups[].branch`;不等且工作区干净则 `git switch {branch}`,不干净先请用户处理。
- `baseCommit`、`branch`、`baseBranch` 缺失(如 code 被跳过)→ 请用户给基准提交,`branch` 设为当前分支。

## 1. 审查

1. 按 repo 预计算审查范围。**首轮(或从 stale / 回退重做进入)审全量** `diffRange = {baseCommit}..HEAD`;**修复后的重审只审增量** `diffRange = {fixBase.{repo}}..HEAD`(`fixBase` 是上一步修复开始前的 HEAD,见 §3.1),范围缩小所以成本随轮次下降。`changedFiles = git -C {repo} diff --name-status {diffRange}`。
   - 全量首轮时,没圈定修复的问题会自然再次出现,不用单独记"遗留";增量轮只核对本轮圈定的编号是否修好、是否引入新问题。
   - 标记为 `blocked` 或上轮未完成的 group 不参与增量,仍审全量。
   - **增量轮只重派本轮修过的 group**(该 group 有待修编号,且 `git -C {repo} rev-list --count {fixBase.{repo}}..HEAD` > 0);其余 group 的 `reports.{g}` 原样沿用,不重派。
2. 读 `references/brief-review.md`,每个 group 一份任务单写到 `{flowDir}/briefs/review-{g}-r{round}.md`(`round = fixRound + 1`),委派 reviewer 角色 `base-reviewer`(预检见 §5.2)。变量:`group`、`workDir`、`branch`、`diffRange`、`design`(`tech-design-{g}.md`)、`changedFiles`、`scopeAdditions`(`stages.code.scopeAdditions` 中该 group 的,file + reason 一行一个,无则"无")、`waived`(`stages.review.waived.{g}`,file + 问题 + 理由一行一个,无则"无")、`round`、`scope`(`全量` / `增量`)、`fixIds` 与 `prevReport`(增量轮填上轮圈定的编号和上轮报告路径,全量轮填"无")、`reportPath`(`round=1` → `review-{g}.md`,否则 `review-{g}-r{round}.md`,均在 `{flowDir}` 下,**每轮单独成文件,不覆盖**)。
3. 各 group 互不依赖且只读,按 §5.3 并行(≤3 个,多了分批);内联时逐个。
4. 核对返回值(`result` / `report` / `counts` 齐全,报告文件存在),写 `reports.{g} = { path, result, round }`。

## 2. 汇总与闸门

**一次展示**:每 group 一行 `{group}: {result}(high {n} / medium {n} / low {n})`;high / medium 按编号逐条列,low 只给计数和报告路径。某 group 返回 `blocked`(审查没完成)→ 只重派它,其余结果保留,且**不提供"通过"选项**。

按协议 §3 **一次问全**:

- 全部 passed:`1 通过并合并到基线分支(推荐) / 2 通过但保留分支 / 3 不通过`。
- 存在 needs_fix:
  - 处理方式:`1 自动修复并重审(推荐;fixRound ≥ 2 时不提供) / 2 豁免指定编号 / 3 回退到 base-code / 4 回退到 base-tech / 5 取消审查`。
  - 修复范围(选 1 时):`1 high + medium(推荐) / 2 全部 / 3 仅 high`,也可直接写编号。

**豁免**(用户认为某编号不是缺陷:已在 code 闸门批准、既有基线问题、有意为之):

1. 在该报告末尾追加"裁决记录":编号、理由、依据。
2. 写 `waived.{g}[] = { file, issue, reason }`(用文件和问题描述,不用编号:编号每轮从 1 重排)。
3. 按剩余问题重判:无 high / medium 且 low 合并前 < 5 → 该 group 视为 passed;否则对剩余编号再问修复选项。豁免不计入 `fixRound`。

## 3. 自动修复并重审

1. 每个涉及的 repo 记 `fixBase.{repo} = git -C {repo} rev-parse HEAD`。
2. 读 `references/brief-fix.md`,每个 group 一份任务单写到 `{flowDir}/briefs/fix-{g}-r{round}.md`,委派 coder 角色 `base-coder`。变量:`group`、`workDir`、`branch`、`report`(该 group 本轮报告路径)、`planPath`、`fixIds`、`round`。**修复写源码:同一 repo 内串行;不同 repo 的单元在同一条消息内并行(≤3)**。
3. 核对返回值:
   - `checks` 含 `fail` 却报 `done` → 按 `blocked`(审查不跑测试,带着失败过闸门会合进主分支)。
   - `blocked` → 先做第 4 步核实已落地的提交,再问 `补信息后重派` / `回退到 base-code` / `取消`。
   - `fixed` 少于 `fixIds` → 没修到的编号如实告诉用户,不静默丢弃(它们仍在 `fixIds` 里,增量重审会逐个核对)。
4. **提交校验**:`git -C {repo} status --porcelain` 须为空;`git -C {repo} log --oneline {fixBase}..HEAD` 核对提交数。
5. 写 `fixRound = fixRound + 1`(修复已落地就先计数),回到 §1 重审(增量,见 §1 第 1 步)。**第 2 次修复后重审仍未通过,不再提供自动修复**,只能回退或取消。`fixRound` 是修复循环唯一的计数器。回退到 base-code / base-tech 后重新进入时 `fixRound` 归零,下轮按全量审。
6. 重审通过 → §4。

## 4. 通过与合并

对每个 repo(同 repo 的多个 group 只处理一次),按 §2 已选的选项执行。

**合并到基线分支**:

1. `baseBranch == branch`(用户直接在当前分支开发)→ 无需合并,记 `merge.{repo}="in-place"`。
2. 否则确认工作区干净,再按协议 §3 **再确认一次**:`将把 {branch} 合并到 {baseBranch}(--no-ff),继续吗?`
3. 确认后依次执行 `git -C {repo} switch {baseBranch}`、`git -C {repo} merge --no-ff {branch}`。**冲突就停下**,把冲突文件告诉用户由其解决;不用 `--ours`、`--theirs`、`reset` 自动处理。
4. 合并成功后问是否删除功能分支:`git -C {repo} branch -d {branch}`(`-d` 只删已合并分支)。记 `merge.{repo}="merged"`。

**保留分支**:不合并,记 `merge.{repo}="kept"`,告诉用户分支名。

全部处理完:写 `stages.review.status=approved`、顶层 `result=success`,按协议 §7 输出完成提示(写明各 repo 的分支与合并结果)。

## 5. 不通过的其他出口

- **回退到 base-code**(复杂重构、多文件关联):待修编号摘要与报告路径写入 `stages.code.note`;`code`、`review` 置 `stale`;**保留原功能分支**,code 在上面继续修复(不新建分支);提示开新会话运行 `/base-code`。
- **回退到 base-tech**(方案问题:接口设计错误、架构问题、选型不当):问题摘要写入 `stages.tech.note`;`tech`、`code`、`review` 都置 `stale`,`note` 写 `"上游 tech 于 {时间} 变更(review 回退)"`(保持此格式,入场判断据此提示);提示开新会话运行 `/base-tech`。
- **取消审查**:顶层 `result=failed`(人工放弃用 `abandoned`),流程结束,分支保持原样。
