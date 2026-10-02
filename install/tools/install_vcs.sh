#!/bin/bash
# ============================================================
# install_vcs.sh — VCS（文中 1.5 节）
# 只提示差异项：安装包目录 vcs_vV-2023.12-SP1
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/vcs_vV-${VCS_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 1.3 节 bashrc：VCS 段（注意含 amd64 子目录，与文中一致）——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "VCS" "export VCS_HOME=\$Synopsys_DIR/vcs/$VCS_VERSION
export PATH=\$VCS_HOME/bin:\$VCS_HOME/amd64/bin:\$PATH"

install_one "$PKG_DIR" "vcs" "vcs/$VCS_VERSION/bin/vcs vcs/$VCS_VERSION/amd64/bin/vcs"

source ~/.bashrc
log "VCS 安装完成。启动验证见文中 3.1 节（verify/vcs_smoke 工程用例，由 verify_all.sh 在 License 认证后实跑）。"
