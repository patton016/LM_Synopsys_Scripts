#!/bin/bash
# ============================================================
# uninstall_hspice.sh — Hspice 卸载（文中 1.14 节逆操作）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "hspice" "HSPICE" "Hspice"
log "Hspice 卸载完成。"
