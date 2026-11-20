# 任务单:代码审查 {{group}}

> 主会话把 `{{变量}}` 替换成实际值后,把全文作为委派消息直接发给 base-reviewer(不写文件),或内联执行。

审查 `{{group}}` 功能分支在 `{{diffRange}}` 范围内的变更。轮次 {{round}}。**只读源码,不修改任何源码。**

## 基准

- 读文件、执行 git 命令:一律在 `{{workDir}}` 内。
- 先核对分支:`git branch --show-current` 须等于 `{{branch}}`,不一致就返回 `blocked`,不要自己切换。
- 报告写到 `{{reportPath}}`(绝对路径,在 `.base/dev/` 下,不在源码仓库里)。
- 不写 `flow-state.json`,不运行编译或测试(code 阶段收尾已跑过全量测试与类型检查)。

## 输入(主会话已注入,不要回读 flow-state.json)

- 变更范围:`{{diffRange}}`(首轮为分支起点到当前 HEAD 的全量;修复后的重审为上一轮修复起点到当前 HEAD 的增量)
- **本任务的性质**:{{scope}} —— `全量` 时按下面全部重点逐项审查;`增量` 时只核对待核对编号是否已修好、修复有没有引入新问题,不复审无关代码。
- 待核对编号:{{fixIds}}(出自上轮报告,即 `{{reportPath}}` 的现有内容;全量时为"无")
- 技术方案:`{{design}}`
- 变更文件清单(同仓库多个 group 时,清单含其他 group 的文件,按方案判断哪些属于本 group,只审本 group):
{{changedFiles}}
- **已批准的计划外变更**(code 闸门已裁决,不是未授权偏离;仍审其正确性,但不因"不在方案或计划清单内"判 medium/high):
{{scopeAdditions}}
- **用户已豁免的问题**(已裁决不修,除非相关代码又变了,否则不再报告):
{{waived}}

## 任务流程(工具调用预算:全程 ≤ 8 次,超出即停并按已有信息判定)

1. **读依据**(1 次):`全量` 读技术方案 `{{design}}`;`增量` **不读方案**(首轮已对照过),改读上轮报告 `{{reportPath}}`(本轮会覆盖它,先读),定位待核对编号的问题和建议修复,并记下其中未圈定的 low 行。增量轮确需核对某个接口签名时,在第 3 步定向读方案的对应行段。
2. **一次取回全部 diff**(1 次,不逐文件;排除锁文件和构建产物,它们审不出问题,仍在变更文件清单里):

   ```
   git diff {{diffRange}} --stat -- . ':(exclude,glob)**/package-lock.json' ':(exclude,glob)**/yarn.lock' ':(exclude,glob)**/pnpm-lock.yaml' ':(exclude,glob)**/*.min.js' ':(exclude,glob)**/*.min.css' ':(exclude,glob)**/*.map' ':(exclude,glob)**/dist/**'
   git diff {{diffRange}} -U5 --no-color -- . ':(exclude,glob)**/package-lock.json' ':(exclude,glob)**/yarn.lock' ':(exclude,glob)**/pnpm-lock.yaml' ':(exclude,glob)**/*.min.js' ':(exclude,glob)**/*.min.css' ':(exclude,glob)**/*.map' ':(exclude,glob)**/dist/**'
   ```

   - 锁文件有变动时,只在报告里核对依赖变更是否与方案一致(看 `package.json` 等清单文件的 diff),不逐行审锁文件。
   - 新文件在 diff 里以全文出现,无需另读。
   - diff 超过约 3000 行,就按变更文件清单分 2–3 批(每批一条命令,`--` 后接多个路径)。
   - 不要用不带范围的 `git diff`:它只显示未提交的改动,本流程的变更已提交。
3. **按需补读**(0–4 次):只有判断依赖被调用方签名、类字段、既有约定时才定向读取行段,不整文件读。达到上限就在报告里写"未核实:…",并按保守判断给严重度。
4. **分析**(0 次):对照技术方案与下方"审查重点"。
5. **写报告**(1 次,覆盖 `{{reportPath}}`),结构见下方。
6. **返回完成标志**。

## 审查重点

1. 实现是否符合技术方案(接口签名、字段、流程)。"已批准的计划外变更"清单内的文件不按此条判偏离。
2. 逻辑正确性:边界条件、异常处理、幂等、事务边界。
3. 安全:SQL 注入、XSS、越权、敏感信息、外部输入校验。
4. 性能:N+1 查询、循环里的 IO、批量操作逐条访问数据库、缓存。
5. 可观测性:关键操作有日志、级别恰当、异常不被吞(空 catch、只打 `e.getMessage()`)。
6. 测试:核心逻辑有单测、有边界用例、外部依赖已隔离;断言的是行为而不是 mock 的调用次数。
7. 规范:命名语义化、注释必要、结构简洁、不过度设计、修改精准、遵循既有风格。

## 严重度与编号

- `high`:阻断性(功能错误、安全漏洞、严重性能问题),必须修。
- `medium`:需修复,不阻断但影响质量。
- `low`:建议改进(风格、可读性),可不修。

每条 high / medium 给唯一编号 `{{group}}-1`、`{{group}}-2`…(本轮报告内从 1 连续编号)。**low 按文件合并成一行**,一个编号对应一个文件的全部 low 项,逗号分隔要点。

## 判定规则

`blocked` 只用于**审查本身没能完成或结论不可信**:`workDir` 不存在、分支不对、取不到 diff、方案文件缺失。**代码有问题一律判 `needs_fix`**。

- 有 high → `needs_fix`
- 仅有 medium → `needs_fix`
- 仅有 low,且合并前原始条数 < 5 → `passed`
- 仅有 low,且合并前原始条数 ≥ 5 → `needs_fix`
- 无问题 → `passed`

## 报告结构

high / medium 逐条写;low 按文件合并;"与技术方案对照"每项 ≤ 3 条。

```markdown
# 审查报告 - {{group}}(第 {{round}} 轮)

## 总体结论
result: passed | needs_fix | blocked
range: {{diffRange}}
摘要:一句话
未核实:(预算耗尽时列出未能确认的点,无则省略)

## 问题列表
| 编号 | 严重度 | 文件 | 问题 | 建议修复 |
|------|-------|------|------|---------|
| {{group}}-1 | high | path:line | ... | ... |
| {{group}}-2 | low | path | 要点 A,要点 B | ... |

## 与技术方案对照
- 已实现:...
- 偏离:...
- 缺失:...

## 上轮未圈定的 low(仅增量轮,原样抄自旧报告,不计入本轮判定和 counts;无则省略)
| 编号 | 文件 | 要点 |
```

## 完成标志

只输出这三行:

```
result: <passed|needs_fix|blocked>
report: <报告绝对路径>
counts: high=<n> medium=<n> low=<n>
```

blocked 时再加一行 `reason: <一行原因>`。
