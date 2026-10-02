#!/bin/bash
# ============================================================
# uninstall_pt.sh — PrimeTime 卸载（文中 1.12 节逆操作）
# 注意：PT 安装目录名为 prime
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "prime" "PRIMETIME" "PrimeTime"
log "PrimeTime 卸载完成。"
