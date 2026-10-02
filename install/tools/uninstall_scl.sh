#!/bin/bash
# ============================================================
# uninstall_scl.sh — SCL 卸载（文中 1.4 节逆操作）
# 注意：先停用 License 服务、再删 SCL 目录（也可先执行
#       license/uninstall_license.sh）。bashrc 中的
#       Synopsys_DIR / SNPSLMD_LICENSE_FILE / PATH 一并移除。
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

# 若 License 服务仍在运行，先停止，避免占用 SCL 目录文件
if systemctl is-active --quiet snps-license.service 2>/dev/null; then
    systemctl stop snps-license.service 2>/dev/null
    warn "已停止 snps-license.service（如需完整卸载 License 请执行 license/uninstall_license.sh）"
fi

bashrc_block_remove "SCL"
uninstall_dir "$INSTALL_ROOT/scl" "SCL"
log "SCL 卸载完成。"
