#!/bin/bash
# ============================================================
# uninstall_license.sh — License 认证卸载（setup_license.sh 逆操作）
# 步骤：
#   1) 停止并禁用 systemd 服务 snps-license.service（文中 2.2.2 逆）
#   2) 删除 start_license.sh（文中 2.2.1 逆）
#   3) 删除 License 文件 Synopsys.dat（删除前确认，建议先备份）
#   4) 清理 SELinux 自定义规则（文中 2.2.3 逆，仅 Enforcing 时）
#   5) 检查 lmgrd 残留进程
# 用法：sudo bash uninstall_license.sh   （确认开关：UNINSTALL_FORCE=yes 跳过）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_root

SCL_DIR="$INSTALL_ROOT/scl/$SCL_VERSION"
LICENSE_DIR="$SCL_DIR/admin/license"
SERVICE_FILE="/etc/systemd/system/snps-license.service"

echo "== [1/5] 停止并禁用 systemd 服务 =="
systemctl stop snps-license.service 2>/dev/null
systemctl disable snps-license.service >/dev/null 2>&1
rm -f "$SERVICE_FILE"
systemctl daemon-reload
ok "已停止并移除 $SERVICE_FILE"

echo "== [2/5] 删除 start_license.sh =="
rm -f "$LICENSE_DIR/start_license.sh" && ok "已删除 $LICENSE_DIR/start_license.sh"

echo "== [3/5] 删除 License 文件（Synopsys.dat）=="
if [ -f "$LICENSE_FILE" ]; then
    echo "  License 文件：$LICENSE_FILE（官方渠道获得，请确认无需再使用）"
    do_del=no
    if [ "${UNINSTALL_FORCE:-no}" != "yes" ]; then
        read -r -p "  确认删除？[y/N] " ans
        [ "$ans" = "y" ] || [ "$ans" = "Y" ] && do_del=yes
    else
        do_del=yes
    fi
    if [ "$do_del" = "yes" ]; then
        rm -f "$LICENSE_FILE" && ok "已删除 License 文件：$LICENSE_FILE"
    else
        warn "已保留 License 文件：$LICENSE_FILE（后续 SELinux 清理仍继续）"
    fi
else
    warn "License 文件不存在：$LICENSE_FILE，跳过"
fi

echo "== [4/5] 清理 SELinux 自定义规则（仅 Enforcing 时）=="
ENFORCE="$(getenforce 2>/dev/null || echo Disabled)"
if [ "$ENFORCE" = "Enforcing" ]; then
    semanage fcontext -d -t usr_t "$SCL_DIR(/.*)?" 2>/dev/null
    semanage fcontext -d -t bin_t "$SCL_DIR/linux64/bin/(.*)?" 2>/dev/null
    semanage fcontext -d -t bin_t "$LICENSE_DIR/start_license.sh" 2>/dev/null
    restorecon -Rv "$SCL_DIR/" >/dev/null 2>&1
    ok "已移除 SELinux 自定义规则（usr_t / bin_t）"
else
    warn "SELinux 状态：$ENFORCE（非 Enforcing，跳过规则清理）"
fi

echo "== [5/5] 检查 lmgrd 残留进程 =="
if pgrep -x lmgrd >/dev/null 2>&1; then
    warn "检测到 lmgrd 进程仍在运行，如需强制结束：pkill -x lmgrd"
else
    ok "无 lmgrd 进程残留"
fi

log "License 认证已卸载。bashrc 中 SNPSLMD_LICENSE_FILE / Synopsys_DIR 随 SCL 块移除（见 uninstall_scl.sh）。"
