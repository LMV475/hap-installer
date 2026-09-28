#!/usr/bin/env bash
# 用本地真实实现覆盖入库的 stub，启用 AGC 证书 / Profile / 设备管理功能。
#
# 仓库中跟踪的 entry/src/main/ets/common/AgcService.ets 是不含实现的空壳；
# 真实实现（逆向华为 DevEco / AGC 内部接口）保存在同目录的 AgcService.local.ets，且被 .gitignore 排除。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT/entry/src/main/ets/common"
SRC="$COMMON/AgcService.local.ets"
DST="$COMMON/AgcService.ets"

if [ ! -f "$SRC" ]; then
  echo "错误：找不到本地真实实现 $SRC" >&2
  echo "      请先把你的 AgcService 实现放到该路径。" >&2
  exit 1
fi

cp "$SRC" "$DST"
echo "已启用本地 AgcService 实现（覆盖入库 stub）。"
echo ""
echo "注意：$DST 在仓库中是 stub，覆盖后 git status 会显示为 modified。"
echo "      请勿使用 'git commit -a' / 'git add .'，以免把逆向代码提交进仓库。"
echo "      需要恢复 stub 时执行： git checkout -- entry/src/main/ets/common/AgcService.ets"
