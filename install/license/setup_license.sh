#!/bin/bash
# ============================================================
# setup_license.sh — License 认证部署（对应文中 2.1 节 + 2.2 节）
# 步骤：
#   1) hostname 一致性检查（文中 2.1：命名 hostname 并确认）
#   2) 安装 LSB 兼容层（文中 2.1：避免 lmgrd 报"没有那个文件或目录"）
#   3) 部署 Synopsys.dat 到 admin/license 目录
#   4) 渲染并安装 start_license.sh（文中 2.2.1）
#   5) 创建 systemd 服务 snps-license.service 并启用（文中 2.2.2）
#   6) SELinux 上下文处理（文中 2.2.3）
#   7) 启动并校验
# 用法：sudo bash setup_license.sh
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_root
# 统一输出通道：终端显示的信息与 run.log 内容完全一致
# （被 install_all.sh 以 sudo -E 调用时继承 UNIFIED_LOG=yes，不会重复重定向）
unified_log_init
log_header "$@"

SCL_DIR="$INSTALL_ROOT/scl/$SCL_VERSION"
LICENSE_DIR="$SCL_DIR/admin/license"
LOG_DIR="$SCL_DIR/admin/logs"
SCL_BIN="$SCL_DIR/linux64/bin"

# ---------- 1) hostname 检查（文中 2.1 节）----------
echo "== [1/7] hostname 一致性检查 =="
CUR_HOST="$(hostname)"
if [ "$CUR_HOST" != "$HOSTNAME" ]; then
    warn "当前 hostname（$CUR_HOST）与配置（$HOSTNAME）不一致"
    warn "License 文件中登记的 SERVER 主机名、SNPSLMD_LICENSE_FILE 的 ${LICENSE_PORT}@主机名 必须与本机 hostname 一致"
    read -r -p "是否执行 sudo hostnamectl set-hostname $HOSTNAME 并继续？[y/N] " ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ] || die "已取消。请先统一主机名（或修改 install.conf 的 HOSTNAME）"
    hostnamectl set-hostname "$HOSTNAME" || die "hostnamectl 执行失败"
    warn "主机名已修改，部分场景需重新登录/重启后完全生效"
else
    ok "hostname = $HOSTNAME，一致"
fi

# ---------- 2) LSB 兼容层（文中 2.1 节）----------
echo "== [2/7] 安装 LSB 兼容层（redhat-lsb-core / lsb-release）=="
pkg_install redhat-lsb-core \
    || warn "LSB 兼容层安装失败（若 lmgrd 可正常运行可忽略；文中用于避免 lmgrd 报错）"

# ---------- 3) 部署 License 文件（文中 2.1 节）----------
echo "== [3/7] 部署 License 文件 =="
[ -f "$LICENSE_DAT_SOURCE" ] || die "未找到 License 文件：$LICENSE_DAT_SOURCE（请将 Synopsys.dat 放入脚本目录下的 license 文件夹后重试）"
mkdir -p "$LICENSE_DIR" "$LOG_DIR"
install -m 0644 "$LICENSE_DAT_SOURCE" "$LICENSE_FILE"
ok "已部署 License 文件：$LICENSE_FILE（请通过官方正规渠道或公司授权获得）"

# ---------- 4) 渲染并安装 start_license.sh（文中 2.2.1 节）----------
echo "== [4/7] 部署 start_license.sh =="
sed -e "s|__SCL_BIN__|$SCL_BIN|g" \
    -e "s|__LICENSE_FILE__|$LICENSE_FILE|g" \
    -e "s|__LOG_FILE__|$LOG_FILE|g" \
    "$SCRIPT_DIR/license/start_license.sh" > "$LICENSE_DIR/start_license.sh"
chmod +x "$LICENSE_DIR/start_license.sh"
ok "已生成：$LICENSE_DIR/start_license.sh"

# ---------- 5) systemd 服务（文中 2.2.2 节）----------
echo "== [5/7] 创建 systemd 服务 snps-license.service =="
SERVICE_FILE="/etc/systemd/system/snps-license.service"
sed -e "s|__LICENSE_DIR__|$LICENSE_DIR|g" \
    -e "s|__RUN_USER__|$RUN_USER|g" \
    -e "s|__RUN_GROUP__|$(id -gn "$RUN_USER" 2>/dev/null || echo "$RUN_USER")|g" \
    "$SCRIPT_DIR/license/snps-license.service" > "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable snps-license.service >/dev/null 2>&1
ok "已创建并启用：$SERVICE_FILE（开机 10 秒网络延时、30 秒重启延时，见文中 2.2.2 节可自行修订）"

# ---------- 6) SELinux（文中 2.2.3 节）----------
echo "== [6/7] SELinux 上下文处理 =="
ENFORCE="$(getenforce 2>/dev/null || echo Disabled)"
if [ "$ENFORCE" = "Enforcing" ]; then
    ok "SELinux 处于 Enforcing，按文中 2.2.3 节添加 usr_t / bin_t 规则"
    semanage fcontext -a -t usr_t "$SCL_DIR(/.*)?" 2>/dev/null \
        || semanage fcontext -m -t usr_t "$SCL_DIR(/.*)?" 2>/dev/null
    semanage fcontext -a -t bin_t "$SCL_DIR/linux64/bin/(.*)?" 2>/dev/null \
        || semanage fcontext -m -t bin_t "$SCL_DIR/linux64/bin/(.*)?" 2>/dev/null
    semanage fcontext -a -t bin_t "$LICENSE_DIR/start_license.sh" 2>/dev/null \
        || semanage fcontext -m -t bin_t "$LICENSE_DIR/start_license.sh" 2>/dev/null
    restorecon -Rv "$SCL_DIR/" >/dev/null 2>&1
    echo "  检查 lmgrd 上下文（应显示 bin_t）："
    ls -lZ "$SCL_BIN/lmgrd"
else
    warn "SELinux 状态：$ENFORCE（非 Enforcing，跳过规则配置；若系统默认启用 SELinux 建议按文中 2.2.3 处理）"
fi

# ---------- 7) 启动并校验 ----------
echo "== [7/7] 启动 License 服务并校验 =="
systemctl restart snps-license.service
sleep 3
systemctl status snps-license.service --no-pager | head -8
"$SCRIPT_DIR/license/check_license.sh" || warn "License 校验有失败项，请查看 $LOG_FILE"

echo ""
ok "License 认证部署完成。命令对照（文中 2.2 节）："
echo "  systemctl status snps-license.service    # 查看服务状态"
echo "  sudo systemctl restart snps-license      # 重启服务"
echo "  start_license.sh {start|stop|restart|status}  # 或直接使用脚本（alias snps-license）"
