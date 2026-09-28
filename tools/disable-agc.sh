#!/usr/bin/env bash
# 恢复入库的 AgcService stub（撤销 tools/enable-agc.sh 的覆盖）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="$ROOT/entry/src/main/ets/common/AgcService.ets"

git -C "$ROOT" checkout -- "entry/src/main/ets/common/AgcService.ets"
echo "已恢复 AgcService stub：$DST"
