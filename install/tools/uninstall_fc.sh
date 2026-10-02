#!/bin/bash
# ============================================================
# uninstall_fc.sh — Fusion Compiler 卸载（文中 1.10 节逆操作）
# 注意：FC 安装目录名为 fusioncompiler
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "fusioncompiler" "FC" "Fusion Compiler"
log "FC 卸载完成。"
