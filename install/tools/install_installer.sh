#!/bin/bash
# ============================================================
# install_installer.sh — Synopsys Installer 5.9（文中 1.1 节）
# 安装：解包运行 SynopsysInstaller_v5.9.run，目标位置输入
#        $INSTALL_ROOT/installer（文中示例 /mnt/asic/Software/Synopsys/installer）
# 说明：.run 自解压仅询问"安装目录"一个提问，用管道首行喂入即可，
#       与软件安装的 Site ID 喂入（common.sh install_one）同一机制，无需 expect。
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

# 幂等：Installer 已就绪时直接跳过（install_all.sh 预装后 PLAN 已剔除 installer，
# 单独运行本脚本或 --only installer 时也能秒过，避免重复解包）
[ -x "$INSTALL_ROOT/installer/installer" ] && ok "Installer 已就绪：$INSTALL_ROOT/installer/installer（跳过重装）" && exit 0

PKG_DIR="$PKG_BASE/installer_v$INSTALLER_VERSION"
RUN_FILE="SynopsysInstaller_v$INSTALLER_VERSION.run"
TARGET_INSTALLER="$INSTALL_ROOT/installer"

[ -f "$PKG_DIR/$RUN_FILE" ] || die "未找到安装包：$PKG_DIR/$RUN_FILE（请检查 PKG_BASE 与 INSTALLER_VERSION）"

# 按文中 1.2 节通用流程第（1）步：先写好 bashrc 环境变量段再运行 installer。
# Synopsys_DIR 取 install.conf 的 INSTALL_ROOT（随配置文件变化，不得硬编码）；
# PATH 追加 $Synopsys_DIR/installer，便于命令行直接使用 installer 命令。
bashrc_block_add "INSTALLER" "export Synopsys_DIR=$INSTALL_ROOT
export PATH=\$Synopsys_DIR/installer:\$PATH"

log "Installer 安装：$PKG_DIR/$RUN_FILE -> $TARGET_INSTALLER"
chmod +x "$PKG_DIR/$RUN_FILE"

# 注意：SynopsysInstaller 的 .run 是 Perl 自解压脚本，必须直接执行（已 chmod +x），
#       不能用 sh 解析（否则报 "%toc = ( / =: command not found" 语法错误）。
# .run 运行后第一个提问即 "Please specify installation directory [.]:"，
# 管道首行喂入目标目录；后续解包无交互提问（timeout 兜底防挂起，返回 124=超时）。
# 输出：统一模式下 stdout 已被顶层 tee 兜底（直接输出即可，避免双写 run.log）；
# 单独运行本脚本时自行 tee。Installer 5.9 强制生成的 installer.log 运行后自动清理。
rc=0
if [ "${UNIFIED_LOG:-no}" = "yes" ]; then
    printf '%s\n' "$TARGET_INSTALLER" | timeout 1200 "$PKG_DIR/$RUN_FILE" 2>&1
    rc=${PIPESTATUS[1]}
else
    printf '%s\n' "$TARGET_INSTALLER" | timeout 1200 "$PKG_DIR/$RUN_FILE" 2>&1 | tee -a "$LOG_PATH"
    rc=${PIPESTATUS[1]}
fi
[ "$rc" -ne 0 ] && warn "Installer 解包返回码 $rc（124=超时；其余输出见 run.log），请人工确认安装结果"

[ -x "$TARGET_INSTALLER/installer" ] || die "Installer 未安装成功：$TARGET_INSTALLER/installer 不存在"
# 清理 Installer 解包残留的 installer.log 与临时目录（snps_installer_temp_*，中断/失败时可能残留）
rm -f "$SCRIPT_DIR/installer.log" 2>/dev/null
rm -rf "$SCRIPT_DIR"/snps_installer_temp_* 2>/dev/null
rm -rf "$PWD"/snps_installer_temp_* 2>/dev/null
[ -n "${TMPDIR:-}" ] && rm -rf "$TMPDIR"/snps_installer_temp_* 2>/dev/null
find /tmp -maxdepth 1 -type d -name 'snps_installer_temp_*' -user "$(id -u)" -exec rm -rf {} + 2>/dev/null
ok "Installer 安装完成：$TARGET_INSTALLER/installer"

source ~/.bashrc
log "Installer 安装完成。启动验证见文中 3.x 节（verify_all.sh 统一执行）。"
