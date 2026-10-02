#!/bin/bash
# ============================================================
# install_formality.sh — Formality（文中 1.9 节）
# 差异项：安装包目录 fm_vV-2023.12-SP3
# 依赖：C Shell（tcsh）按文中 3.5 节安排在 License 认证后的统一启动验证阶段
#       （verify_all.sh 中 formality 验证前安装），不提前到安装阶段。
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/fm_vV-${FM_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 1.3 节 bashrc：Formality 段——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "FORMALITY" "export FM_HOME=\$Synopsys_DIR/fm/$FM_VERSION
export PATH=\$FM_HOME/bin:\$PATH"

install_one "$PKG_DIR" "fm" "fm/$FM_VERSION/bin/formality"

source ~/.bashrc
log "Formality 安装完成。启动验证见文中 3.5 节（formality，tcsh 依赖与验证由 install_all.sh 在 License 认证后统一执行）。"
