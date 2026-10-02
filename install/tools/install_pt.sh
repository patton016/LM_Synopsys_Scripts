#!/bin/bash
# ============================================================
# install_pt.sh — PrimeTime（文中 1.12 节）
# 差异项：
#   ① 安装包目录 Prime_vV-2023.12-SP5-1
#   ② 安装时需按提示提供 SYNOPSYS_DGCOM_ROOT 路径：
#      $INSTALL_ROOT/scl/$SCL_VERSION/linux64（文中 1.12 节第 5 步）
#   ③ bashrc 需添加 SYNOPSYS_DGCOM_ROOT、PT_HOME 和 PATH 声明（文中 1.3 差异点 4）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/Prime_vV-${PT_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 安装时需提供 DGCOM_ROOT（文中 1.12 节）
DGCOM_ROOT="$INSTALL_ROOT/scl/$SCL_VERSION/linux64"

# 1.3 节 bashrc：PrimeTime 段（SYNOPSYS_DGCOM_ROOT=$SCL_HOME，文中 1.3 差异点 4）
# ——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "PRIMETIME" "export SYNOPSYS_DGCOM_ROOT=\$SCL_HOME
export PT_HOME=\$Synopsys_DIR/prime/$PT_VERSION
export PATH=\$PT_HOME/bin:\$PATH"

install_one "$PKG_DIR" "prime" "prime/$PT_VERSION/bin/pt_shell prime/$PT_VERSION/bin/primetime"

source ~/.bashrc
log "PrimeTime 安装完成。启动验证见文中 3.8 节（pt_shell -gui 或 primetime，由 install_all.sh 在 License 认证后统一执行）。"
