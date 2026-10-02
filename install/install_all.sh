#!/bin/bash
# ============================================================
# install_all.sh — Synopsys 软件自动化安装顶层入口
# 依据《【老刘炼芯】十款Synopsys芯片设计软件的部署（AlmaLinux）》
#
# 用法（普通用户直接运行，勿加 sudo —— Synopsys Installer 拒绝 root 账户）：
#   bash install_all.sh                 # 按 install.conf 开关安装
#   bash install_all.sh --all           # 全部安装（含 License 部署，该步会自动 sudo 提权）
#   bash install_all.sh --only vcs,verdi# 只装指定软件（逗号分隔）
#   bash install_all.sh --interactive   # 交互式勾选
#   bash install_all.sh --skip-license  # 跳过 License 认证部署
#   bash install_all.sh --clean-log     # 运行前清空 run.log（默认不清空、追加保留历史）
#   bash install_all.sh --force         # 强制重装（默认已装且验证通过的软件会跳过）
#
# 可随时 Ctrl+C 中断：已安装完成的软件不会重复安装，直接重跑本脚本即可从中断处继续。
#
# 安装顺序（与文中建议一致）：Installer → SCL → License 认证 →
#   VCS → Verdi → Spyglass → DC → Formality → FC → ICC2 → PrimeTime → LC → Hspice
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
require_non_root "$@"

# 统一输出通道：终端显示的信息与 run.log 内容完全一致（stdout/stderr 整体 tee）
unified_log_init

TOOLS_DIR="$SCRIPT_DIR/tools"
LIC_DIR="$SCRIPT_DIR/license"
# Installer 可执行文件路径（install_all.sh 预装判定/状态汇总使用；install_installer.sh 与
# 各 install_*.sh 内部各自定义同名变量——本文件必须自备一份，否则 $INSTALLER_BIN 为空，
# "未就绪"判断恒真、汇总状态恒为"安装失败"）
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# ---------- 参数解析（提前，供 --clean-log 判定使用）----------
MODE=conf        # conf | all | only | interactive
ONLY_LIST=""
SKIP_LICENSE=no
CLEAN_LOG=no
FORCE_INSTALL=no
while [ $# -gt 0 ]; do
    case "$1" in
        --all) MODE=all ;;
        --only)
            MODE=only; shift
            [ -n "$1" ] || die "--only 需要参数，如：--only vcs,verdi"
            ONLY_LIST="$1" ;;
        --interactive) MODE=interactive ;;
        --skip-license) SKIP_LICENSE=yes ;;
        --clean-log) CLEAN_LOG=yes ;;
        --force) FORCE_INSTALL=yes ;;
        *) die "未知参数：$1（支持 --all / --only a,b,c / --interactive / --skip-license / --clean-log / --force）" ;;
    esac
    shift
done

# 允许随时中断并恢复：Ctrl+C / 终止信号时记录日志、输出已完成项的结果汇总后退出；
# 已安装完成的软件不会重复安装（install_one 的"已装跳过"），重跑即可继续未完成部分。
# wait：等待日志 tee 管道 flush 完成后再退出，避免 run.log 尾部缺失。
trap 'log "用户中断（Ctrl+C），安装流程已中止。以下为已完成安装的结果汇总："; rm -rf "$SCRIPT_DIR"/snps_installer_temp_* "$SCRIPT_DIR"/verdiLog "$SCRIPT_DIR"/flex*.log "$SCRIPT_DIR"/installer.log "$SCRIPT_DIR"/spyglass.out 2>/dev/null; SUMMARY_TOTAL="$(($(date +%s) - ${TOTAL_T0:-$(date +%s)}))"; print_summary; wait; exit 130' INT TERM

# --clean-log：运行前清空 run.log（只保留本次运行记录；不加此参数则追加保留历史）
[ "$CLEAN_LOG" = "yes" ] && : > "$LOG_PATH"
log_header "$@"

# 本次安装总用时统计（从参数解析后开始计时，覆盖安装与 License 部署全程）
TOTAL_T0="$(date +%s)"

# 结果汇总数据（print_summary 用）：软件 → 安装目录名 / 用时 / 状态
declare -A SUMMARY_TAG=(
    [installer]=installer [scl]=scl [vcs]=vcs [verdi]=verdi [spyglass]=spyglass
    [dc]=syn [formality]=fm [fc]=fusioncompiler [icc2]=icc2 [pt]=prime [lc]=lc [hspice]=hspice
)
declare -A SUMMARY_TIMES SUMMARY_STATUS
SUMMARY_MODE=install

# 开关映射：软件名 -> install.conf 开关变量名 / 工具脚本
declare -A TOOL=(
    [installer]=install_installer.sh
    [scl]=install_scl.sh
    [vcs]=install_vcs.sh
    [verdi]=install_verdi.sh
    [spyglass]=install_spyglass.sh
    [dc]=install_dc.sh
    [formality]=install_formality.sh
    [fc]=install_fc.sh
    [icc2]=install_icc2.sh
    [pt]=install_pt.sh
    [lc]=install_lc.sh
    [hspice]=install_hspice.sh
)
declare -A SWITCH=(
    [installer]=INSTALL_INSTALLER
    [scl]=INSTALL_SCL
    [vcs]=INSTALL_VCS
    [verdi]=INSTALL_VERDI
    [spyglass]=INSTALL_SPYGLASS
    [dc]=INSTALL_DC
    [formality]=INSTALL_FORMALITY
    [fc]=INSTALL_FC
    [icc2]=INSTALL_ICC2
    [pt]=INSTALL_PT
    [lc]=INSTALL_LC
    [hspice]=INSTALL_HSPICE
)
# 安装顺序（文中建议顺序）
ORDER="installer scl vcs verdi spyglass dc formality fc icc2 pt lc hspice"

# ---------- 计算待安装清单 ----------
pick() {
    local sw; local result=""
    for sw in $ORDER; do
        case "$MODE" in
            all)
                result="$result $sw" ;;
            only)
                for w in ${ONLY_LIST//,/ }; do
                    [ "$sw" = "$w" ] && result="$result $sw"
                done ;;
            interactive)
                read -r -p "安装 $sw ？[y/N] " a
                [ "$a" = "y" ] || [ "$a" = "Y" ] && result="$result $sw" ;;
            conf)
                [ "${!SWITCH[$sw]}" = "yes" ] && result="$result $sw" ;;
        esac
    done
    echo "$result"
}

PLAN="$(pick)"
[ -n "$PLAN" ] || die "没有选择任何软件（请检查 install.conf 开关或使用 --only/--all）"

echo "============================================================"
echo " Synopsys 软件自动化安装"
echo " 安装根目录 : $INSTALL_ROOT"
echo " 安装包目录 : $PKG_BASE"
echo " 本次计划   : $PLAN"
echo " 提示       : License 部署与依赖库步骤需要 root 权限（自动 sudo）。"
echo "              如遇 sudo 等待密码超时，请先执行 sudo -v 输入一次密码（默认 15 分钟内有效）。"
echo "============================================================"

# ---------- 旧版 Synopsys 配置检测与清理（bashrc 中本套件块之外；自动备份+注释）----------
bashrc_old_synopsys_clean

# ---------- 可选：VIP 环境变量注入（文中 1.3 节 VIP 段）----------
# 本篇不安装 VIP 软件包，仅按 ENABLE_VIP_ENV=yes 注入 DESIGNWARE_HOME 与 PATH
if [ "${ENABLE_VIP_ENV:-no}" = "yes" ]; then
    bashrc_block_add "VIP" "export DESIGNWARE_HOME=\$Synopsys_DIR/vip/$VIP_VERSION
export PATH=\$DESIGNWARE_HOME/bin:\$PATH"
    log "已按 ENABLE_VIP_ENV=yes 写入 # >>> SYNOPSYS:VIP 环境变量块（DESIGNWARE_HOME=$INSTALL_ROOT/vip/$VIP_VERSION）"
fi

# ---------- 确保 Installer 就绪 ----------
# 所有软件安装都依赖 Installer（--only 单独选软件时不会包含它，这里统一兜底自动先装）
# 记录 installer 状态供结果汇总：它由预装阶段处理、不进 for 循环（避免双装），
# 若不显式赋值，print_summary 会显示默认的"未处理"（误导——实际是已预装/已就绪）。
if [ ! -x "$INSTALLER_BIN" ]; then
    echo ""
    echo ">>> Installer 未就绪，先自动安装（install_installer.sh）..."
    _it0="$(date +%s)"
    bash "$TOOLS_DIR/install_installer.sh" || warn "Installer 安装失败，后续软件可能无法安装"
    SUMMARY_TIMES[installer]="$(($(date +%s) - _it0))"
    if [ -x "$INSTALLER_BIN" ]; then
        SUMMARY_STATUS[installer]="已预装"
    else
        SUMMARY_STATUS[installer]="安装失败"
    fi
    unset _it0
else
    SUMMARY_STATUS[installer]="已就绪（无需重装）"
fi
# Installer 已就绪（上面预装或此前已装）：从 PLAN 剔除 installer，
# 避免 for 循环再跑一遍 install_installer.sh（历史日志出现过双装）；
# 仅选 installer 时已满足，直接输出汇总结束
PLAN="$(echo " $PLAN " | sed 's/ installer / /g')"
if [ -z "$PLAN" ]; then
    echo ""
    echo " 仅 Installer 需要处理，且已就绪：$INSTALLER_BIN（无需其他安装）"
    SUMMARY_TOTAL=0
    print_summary
    wait
    exit 0
fi

# ---------- 按顺序执行（每项记录状态与安装用时，供结果汇总）----------
for sw in $PLAN; do
    echo ""
    echo ">>> 安装 $sw（${TOOL[$sw]}）..."
    sw_t0="$(date +%s)"
    bash "$TOOLS_DIR/${TOOL[$sw]}" || warn "$sw 安装脚本返回非零状态，继续下一项"
    SUMMARY_TIMES[$sw]="$(($(date +%s) - sw_t0))"
    if [ -d "$INSTALL_ROOT/${SUMMARY_TAG[$sw]:-$sw}" ]; then
        SUMMARY_STATUS[$sw]="已安装"
    else
        SUMMARY_STATUS[$sw]="未安装/失败"
    fi
    log "==> $sw 安装用时：$(fmt_dur "${SUMMARY_TIMES[$sw]}")"

    # License 认证（文中 1.4 节末建议）：SCL 安装完成后立即部署，再继续装其他软件
    if [ "$sw" = "scl" ] && [ "$SKIP_LICENSE" = "no" ] && { [ "$MODE" = "all" ] || [ "$SETUP_LICENSE_AFTER_SCL" = "yes" ]; }; then
        echo ""
        echo ">>> 部署 License 认证（license/setup_license.sh，需要 root，将自动 sudo 提权，请按提示输入密码）..."
        lic_t0="$(date +%s)"
        # sudo -E：保留 UNIFIED_LOG 等环境变量，避免 setup_license.sh 重复重定向输出通道
        sudo -E bash "$LIC_DIR/setup_license.sh" || warn "License 部署脚本返回非零状态，请人工检查"
        log "==> License 部署用时：$(fmt_dur "$(($(date +%s) - lic_t0))")"
    fi
done

# ---------- 自动加载 bashrc（无需手动 source）----------
[ -f "$BASHRC_FILE" ] && . "$BASHRC_FILE" && ok "已自动加载 $BASHRC_FILE（当前会话立即生效，新开终端亦生效）"

# ---------- 统一启动验证（文中 3.x 节，License 认证完成之后执行）----------
if [ "$SKIP_LICENSE" = "no" ]; then
    echo ""
    echo ">>> 统一启动验证（verify_all.sh，对应文中 3.1–3.10 节）..."
    bash "$SCRIPT_DIR/verify_all.sh" || warn "启动验证脚本返回非零状态，请人工检查"
else
    echo ""
    echo ">>> 已使用 --skip-license，跳过 License 部署与统一启动验证（如需验证，请先部署 License 后运行 bash verify_all.sh）"
fi

# ---------- 汇总 ----------
SUMMARY_TOTAL="$(($(date +%s) - TOTAL_T0))"
print_summary
# 清理 Installer/工具运行期间在脚本目录产生的噪音文件（verdiLog / flex*.log / installer.log / spyglass.out）
rm -rf "$SCRIPT_DIR"/verdiLog "$SCRIPT_DIR"/flex*.log "$SCRIPT_DIR"/installer.log "$SCRIPT_DIR"/spyglass.out 2>/dev/null
echo " 下一步："
echo "   1) bash license/check_license.sh           # License 校验"
echo ""
# 等待日志 tee 管道 flush 完成（避免 run.log 尾部缺失）
wait
