#!/usr/bin/env bash
#
# 应用上游 OpenHarmony 源码补丁（HapInstaller 的端侧适配改动）。
#
# 用法（在仓库根目录）：
#     bash tools/apply-upstream-patches.sh
#
# 前置：先把上游源码放到以下位置（版本见 README「构建前提」）：
#     entry/src/main/cpp/hapsigner/source/   ← developtools_hapsigner
#     entry/src/main/cpp/hdctools/source/    ← developtools_hdc
#
# 本脚本会先把两个源码树重置为「刚拉取的原始上游 + LF 行尾」，再依次应用三个补丁。
# 注意：重置会丢弃 source/ 下的本地改动（补丁本身会被重新应用）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAP="$ROOT/entry/src/main/cpp/hapsigner"
HDC="$ROOT/entry/src/main/cpp/hdctools"

for d in "$HAP" "$HDC"; do
  [ -d "$d/source" ] || { echo "错误：缺少 $d/source（请先拉取上游源码）" >&2; exit 1; }
done

# 上游仓库中的文件是 LF。若 core.autocrlf 把工作树变成了 CRLF，补丁会全部匹配失败。
# 这里用「rm --cached + reset --hard」强制按 core.autocrlf=false 重新写出工作树——
# 单纯 reset --hard 会因 git stat cache 跳过未改动的文件，行尾仍是旧值。
# 最后还要 clean：fix_ohos.patch 会新建两个文件（sign_thread_pool.h / trace_log.h），
# 它们是未跟踪文件，reset --hard 不会删，残留下来会让补丁误判为「已应用」而失败。
normalize_lf() {
  git -C "$1" config core.autocrlf false
  git -C "$1" rm --cached -r -q .
  git -C "$1" reset --hard -q
  git -C "$1" clean -fdq
}

apply() {
  echo "==> $(basename "$2")  →  $(basename "$1")"
  ( cd "$1" && patch -p1 --forward < "$2" )
}

echo "==> 将上游源码树重置为原始上游并归一化为 LF 行尾"
normalize_lf "$HAP/source"
normalize_lf "$HDC/source"

apply "$HAP/source" "$HAP/fix_ohos.patch"
apply "$HDC/source" "$HDC/fix_no_libusb.patch"
apply "$HDC/source" "$HDC/fix_sandbox_paths.patch"

echo "==> 三个补丁均已应用，可以执行构建（见 README「构建」）"
