#!/bin/bash
# ============================================================
# install_scl.sh — SCL 2025.03（文中 1.4 节，完整示例）
# 通用流程见 1.2 节：Installer 自动应答；差异点为安装包目录
# 环境变量段对应文中 1.3 节 "# Synopsys License Environment"
# 注意：SCL 的 PATH 声明不带 "/bin"（文中 1.3 差异点 2）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/scl_v${SCL_VERSION}${SCL_PKG_SUFFIX}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 通用流程（1.2）：(1) 先写好 bashrc 环境变量段并生效 (2) 运行 installer (3) 包目录 (4) 目标路径 (5) Site ID (6) yes
# 1.3 节 bashrc 的 License 环境变量段（$Synopsys_DIR 保留字面变量，与文中一致；
# PATH=$SCL_HOME 不带 /bin——文中 1.3 差异点 2；TERM=xterm 同文中 1.4 段）
bashrc_block_add "SCL" "export TERM=xterm
export Synopsys_DIR=$INSTALL_ROOT
export SCL_VERSION=$SCL_VERSION
export LM_LICENSE_FILE=\$Synopsys_DIR/scl/\$SCL_VERSION/admin/license/Synopsys.dat
export SNPSLMD_LICENSE_FILE=${LICENSE_PORT}@${HOSTNAME}
export SCL_HOME=\$Synopsys_DIR/scl/\$SCL_VERSION/linux64
export PATH=\$SCL_HOME:\$PATH
export FLEXLM_DIAGNOSTICS_PATH=\$Synopsys_DIR/scl/\$SCL_VERSION/admin/logs/
export FLEXLM_DIAGNOSTICS=10
alias snps-license='\$Synopsys_DIR/scl/\${SCL_VERSION}/admin/license/start_license.sh'"

install_one "$PKG_DIR" "scl" "scl/$SCL_VERSION/linux64/bin/lmgrd scl/$SCL_VERSION/linux64/bin/lmstat"

source ~/.bashrc
log "SCL 安装完成。License 认证由 install_all.sh 在 SCL 后立即部署（文中 1.4 节末建议），启动验证见文中 3.x 节（verify_all.sh 统一执行）。"
