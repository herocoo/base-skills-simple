# 任务单:修复审查问题 {{group}}

> 主会话把 `{{变量}}` 替换成实际值后写入 `{flowDir}/briefs/fix-{group}-r{round}.md`,再委派给 base-coder,或内联执行。

按审查报告修复 `{{group}}` 中圈定的问题。轮次 {{round}}。

## 基准

- 读写源码、执行命令:一律在 `{{workDir}}` 内。
- **先核对分支**:`git branch --show-current` 须等于 `{{branch}}`,不一致就返回 `blocked`,不要自己切换。
- 审查报告(**只读**,待修编号都出自这一份):`{{report}}`
- 实现计划(只读,需要上下文时参考):`{{planPath}}`
- 不写 `flow-state.json`,不修改报告文件,不合并、不推送、不新建或切换分支。

## 任务

本轮待修编号:{{fixIds}}

1. 在报告里定位这些编号,**只修这些编号**。报告里未圈定的问题(包括 low)一律不碰。
2. 每个编号做最小修复:只改问题所在文件,以及修复必需的测试。不顺手重构,不扩展范围。**行为类问题**(逻辑、边界、异常、安全)先写一个能复现它的测试,确认失败,再修到通过;命名、注释、日志、格式类问题不需要。
3. **验证**(全部编号修完后):
   - 跑受影响模块的测试:Maven `mvn -q -pl <模块> -am test`,Gradle `gradle test --quiet`,前端 `npm test --silent`(watch 型脚本加 `-- --run` 或设 `CI=true`)。
   - 前端另跑类型检查,按顺序选第一个可用的:`npm run type-check` → 依赖含 `vue-tsc` 时 `npx vue-tsc --noEmit` → 有 `tsconfig.json` 时 `npx tsc --noEmit` → 都没有记 `types=n/a`。
   - 验收以计划写明的条件为准;计划注明基线已有错误的,按"**不新增**错误"判定。
   - 失败就据错误修正后重跑;**同一失败修 2 次仍不过**,丢弃导致失败的未提交改动(`git restore .`,只限你自己刚做的改动),返回 `blocked`。
4. **提交**:message `fix({{group}}): 修复审查问题 [{id}][{id}]...`。收尾 `git status --porcelain` 必须为空。
5. 输出截断:构建与测试输出超过 50 行时只取末尾 50 行。
6. **不询问用户**,需要裁决的情况一律 `blocked` 返回。

## 完成标志

只输出这五行:

```
result: <done|blocked>
commits: <本次新增提交数> <短 SHA 列表,逗号分隔>
fixed: <已修复编号,逗号分隔>
checks: tests=<pass|fail|none> types=<pass|fail|n/a>
reason: <done 时留空;blocked 时一行原因 + 建议动作>
```
