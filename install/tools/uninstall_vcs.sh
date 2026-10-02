#!/bin/bash
# ============================================================
# uninstall_vcs.sh — VCS 卸载（文中 1.5 节逆操作）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root
uninstall_sw "vcs" "VCS" "VCS"
# VCS DVE GUI 调试器的运行日志目录（非安装目录，运行时生成，一并清理）
uninstall_dir "$INSTALL_ROOT/DVEfiles" "VCS DVE 运行日志目录 DVEfiles"
# Installer 状态记录 .installer/vcs_docs：vcs_docs 是 VCS 的附加产品（状态名 ≠ 目录名 vcs，
# 主目录清理覆盖不到），残留会导致 .installer 无法整体清空
uninstall_dir "$INSTALL_ROOT/.installer/vcs_docs" "VCS Docs 安装状态记录"
log "VCS 卸载完成。"
