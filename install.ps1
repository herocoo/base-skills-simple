# 安装 base-skills-simple 到 Kiro
# 用法(在本目录执行):
#   .\install.ps1                  默认安装到全局:~\.kiro\(所有项目可用)
#   .\install.ps1 -Target D:\proj  安装到指定工作区:D:\proj\.kiro\(装到当前目录用 -Target .)
#   .\install.ps1 -Check           只检查已安装内容,不改动
#   .\install.ps1 -SyncOnly        只把 shared\protocol.md 同步到四个技能,不安装(改完协议后用)
# 每次安装前会自动同步协议副本,所以改完 shared\protocol.md 直接重新安装即可。
# 指定各角色子代理的模型(ID 取自会话里 /model 的列表,不要猜):
#   .\install.ps1 -CoderModel <ID> -ReviewerModel <ID> -ExplorerModel <ID> -PlannerModel <ID>
# 也可以把 ID 填进本目录的 models.json。命令行参数优先于 models.json。两处都没填,就不写 model 字段,子代理跟随会话默认模型。
[CmdletBinding()]
param(
    [string]$Target,
    [switch]$Check,
    [switch]$SyncOnly,
    [string]$ExplorerModel,
    [string]$PlannerModel,
    [string]$CoderModel,
    [string]$ReviewerModel
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$skills = @('base-prod', 'base-tech', 'base-code', 'base-review')
$roles = [ordered]@{ explorer = 'base-explorer'; planner = 'base-planner'; coder = 'base-coder'; reviewer = 'base-reviewer' }
$utf8 = New-Object System.Text.UTF8Encoding($false)

if ($Target) {
    # 相对路径按 PowerShell 当前位置解析(.NET 的进程目录与 Set-Location 不同步)
    if (-not [IO.Path]::IsPathRooted($Target)) { $Target = Join-Path (Get-Location).Path $Target }
    $InstallRoot = Join-Path ([IO.Path]::GetFullPath($Target)) '.kiro'
} else { $InstallRoot = Join-Path $env:USERPROFILE '.kiro' }
$skillsDir = Join-Path $InstallRoot 'skills'
$agentsDir = Join-Path $InstallRoot 'agents'

function Get-AgentModel([string]$path) {
    $j = [IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
    if ($j.PSObject.Properties.Name -contains 'model') { return [string]$j.model }
    return $null
}

# 1. 同步协议:shared\protocol.md 是唯一源,四个技能各放一份副本(技能须自包含)。-Check 只报告,不改动
$master = Join-Path $here 'shared\protocol.md'
$masterHash = (Get-FileHash $master).Hash
foreach ($s in $skills) {
    $dest = Join-Path $here "$s\references\protocol.md"
    if ((Test-Path $dest) -and ((Get-FileHash $dest).Hash -eq $masterHash)) { continue }
    if ($Check) { Write-Warning "$s 的 protocol.md 与 shared\protocol.md 不一致,请运行 .\install.ps1 -SyncOnly"; continue }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Copy-Item -Force $master $dest
    Write-Host "已同步 $s\references\protocol.md"
}
if ($SyncOnly) { return }

# 2. 校验源:技能 name 必须与目录名一致,agent JSON 必须可解析且 name 与文件名一致
foreach ($s in $skills) {
    $md = Join-Path $here "$s\SKILL.md"
    $head = (Get-Content $md -TotalCount 3 -Encoding UTF8) -join "`n"
    if ($head -notmatch "(?m)^name:\s*$s\s*$") { throw "$md 的 name 与目录名不一致(Kiro 要求相同)" }
}
foreach ($a in $roles.Values) {
    $p = Join-Path $here "agents\$a.json"
    if (-not (Test-Path $p)) { throw "缺少 $p" }
    try { $j = [IO.File]::ReadAllText($p, $utf8) | ConvertFrom-Json } catch { throw "$p 不是合法 JSON:$($_.Exception.Message)" }
    if ($j.name -ne $a) { throw "$p 的 name 必须等于文件名 $a" }
}

if ($Check) {
    Write-Host "检查目标: $InstallRoot"
    foreach ($s in $skills) {
        $ok = Test-Path (Join-Path $skillsDir "$s\SKILL.md")
        Write-Host ("  skill  {0,-14} {1}" -f $s, $(if ($ok) { 'OK' } else { '未安装' }))
    }
    foreach ($a in $roles.Values) {
        $p = Join-Path $agentsDir "$a.json"
        if (Test-Path $p) {
            $m = Get-AgentModel $p
            Write-Host ("  agent  {0,-14} OK  model={1}" -f $a, $(if ($m) { $m } else { '(跟随会话默认)' }))
        } else {
            Write-Host ("  agent  {0,-14} 未安装(可选;不装则该角色内联执行)" -f $a)
        }
    }
    return
}

# 3. 解析各角色模型:命令行参数 > models.json > 不指定
$fromFile = $null
$mf = Join-Path $here 'models.json'
if (Test-Path $mf) { $fromFile = [IO.File]::ReadAllText($mf, $utf8) | ConvertFrom-Json }
$fromArgs = @{ explorer = $ExplorerModel; planner = $PlannerModel; coder = $CoderModel; reviewer = $ReviewerModel }
$models = @{}
foreach ($r in $roles.Keys) {
    $id = $fromArgs[$r]
    if (-not $id -and $fromFile -and ($fromFile.PSObject.Properties.Name -contains $r)) { $id = [string]$fromFile.$r }
    if ($id) {
        if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._:/-]*$') { throw "角色 $r 的模型 ID 含非法字符:$id" }
        $models[$r] = $id
    }
}

# 4. 复制(同名覆盖,不删除目标里的其他内容)
New-Item -ItemType Directory -Force -Path $skillsDir, $agentsDir | Out-Null
foreach ($s in $skills) {
    $dest = Join-Path $skillsDir $s
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Recurse -Force -Path (Join-Path $here "$s\*") -Destination $dest
    Write-Host "已安装 skill: $dest"
}
foreach ($r in $roles.Keys) {
    $a = $roles[$r]
    $raw = [IO.File]::ReadAllText((Join-Path $here "agents\$a.json"), $utf8)
    if ($models.ContainsKey($r)) {
        $line = '  "model": "' + $models[$r] + '",'
        if ($raw -match '(?m)^\s*"model"\s*:') { $raw = [regex]::Replace($raw, '(?m)^\s*"model"\s*:.*$', $line) }
        else { $raw = [regex]::Replace($raw, '(?m)^(\s*"name"\s*:\s*"[^"]+",)\s*$', "`$1`n$line", 1) }
    }
    $null = $raw | ConvertFrom-Json   # 写入前再验一次,保证产物是合法 JSON
    $out = Join-Path $agentsDir "$a.json"
    [IO.File]::WriteAllText($out, $raw, $utf8)
    Write-Host ("已安装 agent: {0}  model={1}" -f $out, $(if ($models.ContainsKey($r)) { $models[$r] } else { '(跟随会话默认)' }))
}

Write-Host ""
Write-Host "完成。下一步:"
Write-Host "  1. 新开一个会话(IDE 新建 Chat;CLI 重新进入),让技能和 agent 重新加载。"
Write-Host "  2. 输入 / 能看到 base-prod、base-tech、base-code、base-review 即表示技能已被识别。"
Write-Host "  3. 从 /base-prod 开始。子代理是否可用,流程第一次需要时会按角色自动预检,详见 README。"
