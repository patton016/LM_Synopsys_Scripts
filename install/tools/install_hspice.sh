#!/bin/bash
# ============================================================
# install_hspice.sh — Hspice（文中 1.14 节）
# 差异项：安装包目录 hspice_vV-2023.12-SP2；
#         注意 HSPICE_HOME 路径结构与其他软件工具不同，
#         含二级目录 /hspice（文中 1.3 差异点 5）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/hspice_vV-${HSPICE_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 1.3 节 bashrc：Hspice 段（HSPICE_HOME 含二级 hspice 目录，与文中 1.3 差异点 5 一致）
# ——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "HSPICE" "export HSPICE_HOME=\$Synopsys_DIR/hspice/$HSPICE_VERSION/hspice
export PATH=\$HSPICE_HOME/bin:\$PATH"

install_one "$PKG_DIR" "hspice" "hspice/$HSPICE_VERSION/hspice/bin/hspice"

source ~/.bashrc
log "Hspice 安装完成。启动验证见文中 3.10 节（hspice -I，由 install_all.sh 在 License 认证后统一执行）。"
