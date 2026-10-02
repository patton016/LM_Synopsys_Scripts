#!/bin/bash
# ============================================================
# uninstall_verdi.sh — Verdi 卸载（文中 1.6 节逆操作）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "verdi" "VERDI" "Verdi"
# Installer 随 Verdi 安装的附加支持目录（verdi_supp）
uninstall_dir "$INSTALL_ROOT/verdi_supp" "Verdi 附加目录 verdi_supp"
log "Verdi 卸载完成。"
