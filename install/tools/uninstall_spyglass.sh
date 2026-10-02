#!/bin/bash
# ============================================================
# uninstall_spyglass.sh — Spyglass 卸载（文中 1.7 节逆操作）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "spyglass" "SPYGLASS" "Spyglass"
# Installer 随 Spyglass 自动安装的附加包目录（文中 1.7 节提及的两个目录之一）
uninstall_dir "$INSTALL_ROOT/ufe_optional_spyglass-vcs" "Spyglass 附加包 ufe_optional_spyglass-vcs"
log "Spyglass 卸载完成。"
