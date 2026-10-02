#!/bin/bash
# ============================================================
# install_verdi.sh — Verdi（文中 1.6 节）
# 差异项：安装包目录 verdi_vV-2023.12-SP2
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/verdi_vV-${VERDI_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 1.3 节 bashrc：Verdi 段——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "VERDI" "export VERDI_HOME=\$Synopsys_DIR/verdi/$VERDI_VERSION
export PATH=\$VERDI_HOME/bin:\$PATH"

# 附加交互应答：VERDI_SUPP 的 post-install 会询问
#   "Create Symbolic Link for Verdi Supplementary Package [Yes]:" → 喂 Yes（接受符号链接）；
#   "Please specify VERDI HOME, leave empty for auto detection:" → 不喂，EOF 即自动检测
# （实测 5.9 顺序：Site ID → symlink → VERDI HOME → Accept）
INSTALLER_EXTRA_STDIN="Yes"

install_one "$PKG_DIR" "verdi" "verdi/$VERDI_VERSION/bin/verdi"
unset INSTALLER_EXTRA_STDIN

source ~/.bashrc
log "Verdi 安装完成。启动验证见文中 3.2 节（verdi 或 verdi -licdebug，由 install_all.sh 在 License 认证后统一执行）。"
