#!/bin/bash
# ============================================================
# uninstall_dc.sh — Design Compiler 卸载（文中 1.8 节逆操作）
# 注意：DC 安装目录名为 syn（对应 install_dc.sh 的 install_one "syn"）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "syn" "DC" "Design Compiler"
log "DC 卸载完成。"
