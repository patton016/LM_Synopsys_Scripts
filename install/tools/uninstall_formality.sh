#!/bin/bash
# ============================================================
# uninstall_formality.sh — Formality 卸载（文中 1.9 节逆操作）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "fm" "FORMALITY" "Formality"
log "Formality 卸载完成。"
