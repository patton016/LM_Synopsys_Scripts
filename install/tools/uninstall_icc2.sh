#!/bin/bash
# ============================================================
# uninstall_icc2.sh — ICC2 卸载（文中 1.11 节逆操作）
# 注意：bashrc 中的 TERM=xterm 与 alias icc2 随 ICC2 块一并移除
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "icc2" "ICC2" "ICC2"
log "ICC2 卸载完成。"
