#!/bin/bash
# ============================================================
# install_fc.sh — Fusion Compiler（文中 1.10 节）
# 差异项：安装包目录 fusioncompiler_vV-2023.12
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/fusioncompiler_vV-${FC_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 1.3 节 bashrc：Fusion Compiler 段——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "FC" "export FC_HOME=\$Synopsys_DIR/fusioncompiler/$FC_VERSION
export PATH=\$FC_HOME/bin:\$PATH"

install_one "$PKG_DIR" "fusioncompiler" "fusioncompiler/$FC_VERSION/bin/fc_shell"

source ~/.bashrc
log "Fusion Compiler 安装完成。启动验证见文中 3.6 节（fc_shell -gui，由 install_all.sh 在 License 认证后统一执行）。"
