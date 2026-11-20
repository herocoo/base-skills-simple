#!/usr/bin/env bash
# 安装 base-skills-simple(Linux / macOS / Git Bash),功能与 install.ps1 对等。
# 用法(在本目录执行):
#   bash install.sh                       默认安装到全局:~/.kiro/(所有项目可用)
#   bash install.sh --target /path/proj   安装到指定工作区:/path/proj/.kiro/(当前目录用 --target .)
#   bash install.sh --check               只检查已安装内容,不改动
#   bash install.sh --sync-only           只把 shared/protocol.md 同步到四个技能,不安装
# 指定各角色子代理的模型(ID 取自会话里 /model 的列表,不要猜):
#   bash install.sh --coder-model <ID> --reviewer-model <ID> --explorer-model <ID> --planner-model <ID>
# 也可以把 ID 填进本目录的 models.json。命令行参数优先于 models.json。两处都没填,就不写 model 字段。
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills=(base-prod base-tech base-code base-review)
roles=(explorer planner coder reviewer)
target="" check=0 sync_only=0
declare -A arg_model=()

usage() { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
die() { echo "错误: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --target)          [ $# -ge 2 ] || die "--target 需要一个目录"; target="$2"; shift 2 ;;
    --check)           check=1; shift ;;
    --sync-only)       sync_only=1; shift ;;
    --explorer-model)  [ $# -ge 2 ] || die "$1 需要模型 ID"; arg_model[explorer]="$2"; shift 2 ;;
    --planner-model)   [ $# -ge 2 ] || die "$1 需要模型 ID"; arg_model[planner]="$2"; shift 2 ;;
    --coder-model)     [ $# -ge 2 ] || die "$1 需要模型 ID"; arg_model[coder]="$2"; shift 2 ;;
    --reviewer-model)  [ $# -ge 2 ] || die "$1 需要模型 ID"; arg_model[reviewer]="$2"; shift 2 ;;
    -h|--help)         usage; exit 0 ;;
    *)                 die "未知参数: $1(见 --help)" ;;
  esac
done

if [ -n "$target" ]; then
  mkdir -p "$target" 2>/dev/null || true
  install_root="$(cd "$target" && pwd)/.kiro"
else
  install_root="${HOME:?HOME 未设置}/.kiro"
fi
skills_dir="$install_root/skills"
agents_dir="$install_root/agents"

hash_of() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

# JSON 校验:优先 python3/python,其次 jq,都没有就跳过并提示一次
json_warned=0
json_ok() {
  local f="$1" py
  for py in python3 python; do
    if command -v "$py" >/dev/null 2>&1 && "$py" -c 'import sys' >/dev/null 2>&1; then
      "$py" -c 'import json,sys; json.load(open(sys.argv[1],encoding="utf-8"))' "$f" >/dev/null 2>&1
      return $?
    fi
  done
  if command -v jq >/dev/null 2>&1; then jq empty "$f" >/dev/null 2>&1; return $?; fi
  if [ "$json_warned" = 0 ]; then echo "提示: 未找到 python3 或 jq,跳过 JSON 合法性校验" >&2; json_warned=1; fi
  return 0
}

# 取 JSON 顶层字符串字段(只匹配 2 空格缩进的顶层键,不会误取 _用途说明 里的同名键;null 或缺失返回空)
json_top_str() { sed -n "s/^  \"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -n1; }

# 1. 同步协议:shared/protocol.md 是唯一源,四个技能各放一份副本(技能须自包含)。--check 只报告
master="$here/shared/protocol.md"
[ -f "$master" ] || die "缺少 $master"
master_hash="$(hash_of "$master")"
for s in "${skills[@]}"; do
  dest="$here/$s/references/protocol.md"
  if [ -f "$dest" ] && [ "$(hash_of "$dest")" = "$master_hash" ]; then continue; fi
  if [ "$check" = 1 ]; then echo "警告: $s 的 protocol.md 与 shared/protocol.md 不一致,请运行 bash install.sh --sync-only" >&2; continue; fi
  mkdir -p "$(dirname "$dest")"
  cp -f "$master" "$dest"
  echo "已同步 $s/references/protocol.md"
done
[ "$sync_only" = 1 ] && exit 0

# 2. 校验源:技能 name 必须与目录名一致,agent JSON 必须可解析且 name 与文件名一致
for s in "${skills[@]}"; do
  md="$here/$s/SKILL.md"
  [ -f "$md" ] || die "缺少 $md"
  head -n 3 "$md" | tr -d '\r' | grep -Eq "^name:[[:space:]]*$s[[:space:]]*$" || die "$md 的 name 与目录名不一致(Kiro 要求相同)"
done
for r in "${roles[@]}"; do
  a="base-$r"; p="$here/agents/$a.json"
  [ -f "$p" ] || die "缺少 $p"
  json_ok "$p" || die "$p 不是合法 JSON"
  grep -Eq "^[[:space:]]*\"name\"[[:space:]]*:[[:space:]]*\"$a\"" "$p" || die "$p 的 name 必须等于文件名 $a"
done

if [ "$check" = 1 ]; then
  echo "检查目标: $install_root"
  for s in "${skills[@]}"; do
    if [ -f "$skills_dir/$s/SKILL.md" ]; then ok=OK; else ok=未安装; fi
    printf '  skill  %-14s %s\n' "$s" "$ok"
  done
  for r in "${roles[@]}"; do
    a="base-$r"; p="$agents_dir/$a.json"
    if [ -f "$p" ]; then
      m="$(json_top_str "$p" model)"
      printf '  agent  %-14s OK  model=%s\n' "$a" "${m:-(跟随会话默认)}"
    else
      printf '  agent  %-14s 未安装(可选;不装则该角色内联执行)\n' "$a"
    fi
  done
  exit 0
fi

# 3. 解析各角色模型:命令行参数 > models.json > 不指定
declare -A models=()
for r in "${roles[@]}"; do
  id="${arg_model[$r]:-}"
  if [ -z "$id" ] && [ -f "$here/models.json" ]; then id="$(json_top_str "$here/models.json" "$r" | tr -d '\r')"; fi
  if [ -n "$id" ]; then
    [[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]*$ ]] || die "角色 $r 的模型 ID 含非法字符:$id"
    models[$r]="$id"
  fi
done

# 4. 复制(同名覆盖,不删除目标里的其他内容)
mkdir -p "$skills_dir" "$agents_dir"
for s in "${skills[@]}"; do
  dest="$skills_dir/$s"
  mkdir -p "$dest"
  cp -R -f "$here/$s/." "$dest/"
  echo "已安装 skill: $dest"
done
for r in "${roles[@]}"; do
  a="base-$r"; out="$agents_dir/$a.json"
  cp -f "$here/agents/$a.json" "$out"
  if [ -n "${models[$r]:-}" ]; then
    line="  \"model\": \"${models[$r]}\","
    if grep -Eq '^[[:space:]]*"model"[[:space:]]*:' "$out"; then
      sed -i.bak -E "s|^[[:space:]]*\"model\"[[:space:]]*:.*\$|$line|" "$out"
    else
      sed -i.bak -E "0,/^[[:space:]]*\"name\"[[:space:]]*:[[:space:]]*\"[^\"]+\",[[:space:]]*\$/{s|^([[:space:]]*\"name\"[[:space:]]*:[[:space:]]*\"[^\"]+\",)[[:space:]]*\$|\\1\n$line|}" "$out"
    fi
    rm -f "$out.bak"
  fi
  json_ok "$out" || { rm -f "$out"; die "$a 写入模型后不是合法 JSON,已删除:请检查模型 ID"; }
  echo "已安装 agent: $out  model=${models[$r]:-(跟随会话默认)}"
done

echo
echo "完成。下一步:"
echo "  1. 新开一个会话(IDE 新建 Chat;CLI 重新进入),让技能和 agent 重新加载。"
echo "  2. 输入 / 能看到 base-prod、base-tech、base-code、base-review 即表示技能已被识别。"
echo "  3. 从 /base-prod 开始。子代理是否可用,流程第一次需要时会按角色自动预检,详见 README。"
