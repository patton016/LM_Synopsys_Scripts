#!/bin/bash
# ============================================================
# uninstall_installer.sh — Synopsys Installer 卸载（文中 1.1 节逆操作）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
# 用 uninstall_sw：先移除 SYNOPSYS:INSTALLER bashrc 块（含 Synopsys_DIR/PATH），再删目录与 .installer 状态
uninstall_sw installer INSTALLER Installer
log "Installer 卸载完成。"
