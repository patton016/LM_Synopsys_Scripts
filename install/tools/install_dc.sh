#!/bin/bash
# ============================================================
# install_dc.sh — Design Compiler（文中 1.8 节）
# 差异项：安装包目录 syn_vV-2023.12-SP3（包名为 syn_，对应 DC）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/syn_vV-${DC_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 1.3 节 bashrc：DC 段——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "DC" "export DC_HOME=\$Synopsys_DIR/syn/$DC_VERSION
export PATH=\$DC_HOME/bin:\$PATH"

install_one "$PKG_DIR" "syn" "syn/$DC_VERSION/bin/dc_shell syn/$DC_VERSION/bin/design_vision"

source ~/.bashrc
log "DC 安装完成。启动验证见文中 3.4 节（design_vision，由 install_all.sh 在 License 认证后统一执行）。"
