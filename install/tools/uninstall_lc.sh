#!/bin/bash
# ============================================================
# uninstall_lc.sh — Library Compiler 卸载（文中 1.13 节逆操作）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "lc" "LC" "Library Compiler"
log "LC 卸载完成。"
