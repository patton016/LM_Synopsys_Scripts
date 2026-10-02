#!/bin/bash
# ============================================================
# install_lc.sh — Library Compiler（文中 1.13 节）
# 差异项：
#   ① 安装包目录 lib_compiler_vV-2023.12-SP3
#   ② 安装向导会询问"是否工具启动时就检查 License"，选 Yes（文中 1.13 节）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/lib_compiler_vV-${LC_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 文中 1.13 节：安装向导询问启动时检查 License → Yes
LC_CHECK_LIC=yes

# 1.3 节 bashrc：Library Compiler 段——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "LC" "export LC_HOME=\$Synopsys_DIR/lc/$LC_VERSION
export PATH=\$LC_HOME/bin:\$PATH"

install_one "$PKG_DIR" "lc" "lc/$LC_VERSION/bin/lc_shell"

source ~/.bashrc
log "Library Compiler 安装完成。启动验证见文中 3.9 节（lc_shell -gui，由 install_all.sh 在 License 认证后统一执行）。"
