#!/bin/bash
# ============================================================
# diagnose_scl.sh — SCL 安装与 PATH 只读诊断（不改任何文件）
#
# 用法：bash diagnose_scl.sh   （普通用户直接运行）
# 输出：SCL 目录结构 / lmgrd·lmstat 真实路径与权限 / bashrc 块内容 /
#       source 后 PATH 与命令解析结果 —— 贴给维护者即可定位
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

echo "==== [1] SCL 顶层目录（版本目录名）===="
ls -ld "$INSTALL_ROOT/scl"/*/ 2>&1

echo ""
echo "==== [2] linux64 顶层内容 ===="
ls -la "$INSTALL_ROOT/scl/$SCL_VERSION/linux64/" 2>&1 | head -20

echo ""
echo "==== [3] lmgrd / lmstat 候选路径与权限（关键）===="
ls -l "$INSTALL_ROOT/scl/$SCL_VERSION/linux64/lmgrd" \
      "$INSTALL_ROOT/scl/$SCL_VERSION/linux64/bin/lmgrd" \
      "$INSTALL_ROOT/scl/$SCL_VERSION/linux64/bin/lmstat" 2>&1

echo ""
echo "==== [4] ~/.bashrc 中 SYNOPSYS:SCL 块实际内容 ===="
grep -A 12 '# >>> SYNOPSYS:SCL' "$BASHRC_FILE" 2>&1

echo ""
echo "==== [5] ~/.bashrc 中其他 Synopsys 痕迹（旧版 2018 等）===="
grep -n -i -e synopsys -e snpslmd -e 'lmgrd' -e '30000' "$BASHRC_FILE" 2>&1 | grep -v '# >>> SYNOPSYS:' | grep -v '# <<< SYNOPSYS:'

echo ""
echo "==== [6] 子 shell 中 source ~/.bashrc 后：PATH 与命令解析 ===="
bash -c '. '"$BASHRC_FILE"'; echo "PATH=$PATH"; echo "--- type ---"; type lmgrd lmstat 2>&1; echo "--- command -v ---"; command -v lmgrd lmstat 2>&1'

echo ""
echo "==== [7] 当前终端（未 source）的 PATH 与命令解析 ===="
echo "PATH=$PATH"
type lmgrd lmstat 2>&1
