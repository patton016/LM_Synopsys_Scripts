#!/bin/bash
# ============================================================
# install_icc2.sh — ICC2（文中 1.11 节）
# 差异项：
#   ① 先确认并自动补充安装环境依赖库（文中 1.11 节）：
#      libnsl libXScrnSaver libXtst libXrender fontconfig expat
#   ② TERM=xterm 设定（AlmaLinux 8.10 与 xterm-256color 不兼容，避免 CLE-10 警告）
#   ③ alias icc2='icc2_shell -gui'（一步启动 GUI）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

# 文中 1.11 节依赖库（需要 root，自动 sudo 提权；Ubuntu 包名自动映射）
# libnsl 仅 RHEL8+（AlmaLinux 8/9 等）需要——RHEL8 移除了 libnsl.so.1；
# CentOS 7 / RHEL7 自带 libnsl，无需补装；其余 X 库（libXScrnSaver/libXtst/libXrender）
# 与 fontconfig/expat 在最小化安装下可能缺失，两个发行版都建议补齐。
ICC2_DEPS="libXScrnSaver libXtst libXrender fontconfig expat"
case "$(rhel_major)" in
    8|9) ICC2_DEPS="libnsl $ICC2_DEPS" ;;
esac
log "安装 ICC2 环境依赖库（文中 1.11 节）：$ICC2_DEPS"
echo "（需要 root 权限，将自动 sudo 提权；如遇 sudo 等待密码超时，请先执行 sudo -v 输入一次密码）"
# 依赖库安装失败不阻断：继续尝试安装 ICC2，看 Installer/启动时实际报什么错
# （缺 .so 时按文中 1.11 节手动补齐即可）
# 注意：pkg_install 内部已自动 sudo 提权，这里不能再套 sudo（函数在 sudo 子进程里不存在）
pkg_install $ICC2_DEPS \
    || warn "依赖库安装失败（$ICC2_DEPS 未全部装上）。继续尝试安装 ICC2；如启动报缺 .so 请按文中 1.11 节手动补齐"

PKG_DIR="$PKG_BASE/icc2_vV-${ICC2_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 1.3 节 bashrc：ICC2 段（含 TERM 与 alias，与文中 1.11 节一致）——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "ICC2" "export ICC2_HOME=\$Synopsys_DIR/icc2/$ICC2_VERSION
export PATH=\$ICC2_HOME/bin:\$PATH
export TERM=xterm
alias icc2='icc2_shell -gui'"

install_one "$PKG_DIR" "icc2" "icc2/$ICC2_VERSION/bin/icc2_shell"

source ~/.bashrc
log "ICC2 安装完成。启动验证见文中 3.7 节（输入 icc2 即可启动 GUI，由 install_all.sh 在 License 认证后统一执行）。"
