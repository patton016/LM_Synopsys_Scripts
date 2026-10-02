#!/bin/bash
# ============================================================
# uninstall_all.sh — Synopsys 软件卸载顶层入口（install_all.sh 逆操作）
#
# 用法（普通用户直接运行，勿加 sudo；License 卸载步骤会自动 sudo 提权）：
#   bash uninstall_all.sh                  # 全部卸载（逐项确认）
#   bash uninstall_all.sh --only vcs,verdi # 只卸载指定软件（逗号分隔）
#   bash uninstall_all.sh --interactive    # 交互式逐项勾选
#   bash uninstall_all.sh --force          # 跳过逐项确认（-y）
#   bash uninstall_all.sh --skip-license   # 不卸载 License 认证
#   bash uninstall_all.sh --clean-log      # 运行前清空 run.log（默认不清空、追加保留历史）
#
# 卸载顺序（与安装相反）：Hspice → LC → PrimeTime → ICC2 → FC →
#   Formality → DC → Spyglass → Verdi → VCS → SCL → Installer；
#   License 认证在 SCL 之后卸载（License 文件删除前需单独确认）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
require_non_root "$@"

# 统一输出通道：终端显示的信息与 run.log 内容完全一致（stdout/stderr 整体 tee）
unified_log_init

TOOLS_DIR="$SCRIPT_DIR/tools"
LIC_DIR="$SCRIPT_DIR/license"

# ---------- 参数解析（提前，供 --clean-log 判定使用）----------
MODE=all          # all | only | interactive
ONLY_LIST=""
UNINSTALL_FORCE=no
SKIP_LICENSE=no
CLEAN_LOG=no
while [ $# -gt 0 ]; do
    case "$1" in
        --only)
            MODE=only; shift
            [ -n "$1" ] || die "--only 需要参数，如：--only vcs,verdi"
            ONLY_LIST="$1" ;;
        --interactive) MODE=interactive ;;
        --force|-y) UNINSTALL_FORCE=yes ;;
        --skip-license) SKIP_LICENSE=yes ;;
        --clean-log) CLEAN_LOG=yes ;;
        *) die "未知参数：$1（支持 --only a,b,c / --interactive / --force / --skip-license / --clean-log）" ;;
    esac
    shift
done
export UNINSTALL_FORCE

# --clean-log：运行前清空 run.log（只保留本次运行记录；不加此参数则追加保留历史）
[ "$CLEAN_LOG" = "yes" ] && : > "$LOG_PATH"
log_header "$@"

# 本次卸载总用时统计（从参数解析后开始计时，覆盖卸载与 License 卸载全程）
TOTAL_T0="$(date +%s)"

# 允许随时中断：Ctrl+C / 终止信号时记录日志、输出已完成项的结果汇总后退出
# wait：等待日志 tee 管道 flush 完成后再退出，避免 run.log 尾部缺失。
trap 'log "用户中断（Ctrl+C），卸载流程已中止。以下为已完成卸载的结果汇总："; SUMMARY_TOTAL="$(($(date +%s) - ${TOTAL_T0:-$(date +%s)}))"; print_summary; wait; exit 130' INT TERM

# 结果汇总数据（print_summary 用）：软件 → 安装目录名 / 用时 / 状态
declare -A SUMMARY_TAG=(
    [installer]=installer [scl]=scl [vcs]=vcs [verdi]=verdi [spyglass]=spyglass
    [dc]=syn [formality]=fm [fc]=fusioncompiler [icc2]=icc2 [pt]=prime [lc]=lc [hspice]=hspice
)
declare -A SUMMARY_TIMES SUMMARY_STATUS
SUMMARY_MODE=uninstall

# 卸载脚本映射与顺序（十款软件逆序 → SCL → Installer）
declare -A UNINSTALL=(
    [installer]=uninstall_installer.sh
    [scl]=uninstall_scl.sh
    [vcs]=uninstall_vcs.sh
    [verdi]=uninstall_verdi.sh
    [spyglass]=uninstall_spyglass.sh
    [dc]=uninstall_dc.sh
    [formality]=uninstall_formality.sh
    [fc]=uninstall_fc.sh
    [icc2]=uninstall_icc2.sh
    [pt]=uninstall_pt.sh
    [lc]=uninstall_lc.sh
    [hspice]=uninstall_hspice.sh
)
ORDER="hspice lc pt icc2 fc formality dc spyglass verdi vcs scl installer"

# ---------- 计算待卸载清单 ----------
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
                read -r -p "卸载 $sw ？[y/N] " a
                [ "$a" = "y" ] || [ "$a" = "Y" ] && result="$result $sw" ;;
        esac
    done
    echo "$result"
}

PLAN="$(pick)"
[ -n "$PLAN" ] || die "没有选择任何软件"

# ---------- 旧版 Synopsys 配置检测与清理（bashrc 中本套件块之外；自动备份+注释）----------
bashrc_old_synopsys_clean

echo "============================================================"
echo " Synopsys 软件卸载"
echo " 安装根目录 : $INSTALL_ROOT"
if [ "${UNINSTALL_FORCE}" = "yes" ]; then
    echo " 模式       : 全部跳过确认（--force）"
fi
echo " 本次计划   : $PLAN"
echo " 注意：bashrc 中对应环境变量块将一并移除；License 认证$([ "$SKIP_LICENSE" = "yes" ] && echo " 不" )在本次计划内"
echo "============================================================"

# ---------- 按顺序执行（每项记录状态与卸载用时，供结果汇总）----------
for sw in $PLAN; do
    echo ""
    echo ">>> 卸载 $sw（${UNINSTALL[$sw]}）..."
    sw_t0="$(date +%s)"
    bash "$TOOLS_DIR/${UNINSTALL[$sw]}" || warn "$sw 卸载脚本返回非零状态，继续下一项"
    SUMMARY_TIMES[$sw]="$(($(date +%s) - sw_t0))"
    if [ -d "$INSTALL_ROOT/${SUMMARY_TAG[$sw]:-$sw}" ]; then
        SUMMARY_STATUS[$sw]="卸载失败/仍存在"
    else
        SUMMARY_STATUS[$sw]="已卸载"
    fi
    log "==> $sw 卸载用时：$(fmt_dur "${SUMMARY_TIMES[$sw]}")"
done

# ---------- License 认证卸载（默认执行；--skip-license 跳过）----------
if [ "$SKIP_LICENSE" = "no" ]; then
    echo ""
    echo ">>> 卸载 License 认证（license/uninstall_license.sh，需要 root，将自动 sudo 提权，请按提示输入密码）..."
    # sudo -E：保留 UNIFIED_LOG 等环境变量，避免 uninstall_license.sh 重复重定向输出通道
    sudo -E bash "$LIC_DIR/uninstall_license.sh" || warn "License 卸载脚本返回非零状态，请人工检查"
fi

# ---------- 附加目录兜底清理（仅全量卸载时执行）----------
# Installer 随产品安装的附加包/运行日志目录，单款脚本已各清其对应项；
# 全量卸载时兜底再扫一遍，防止任何残留：
#   ufe_optional_spyglass-vcs（Spyglass 附加包）/ verdi_supp（Verdi 附加目录）/ DVEfiles（VCS DVE 运行日志）
if [ "$MODE" = "all" ]; then
    echo ""
    echo ">>> 兜底清理附加目录（ufe_optional_spyglass-vcs / verdi_supp / DVEfiles）..."
    local _x _d _l
    for _x in "ufe_optional_spyglass-vcs:Spyglass 附加包" "verdi_supp:Verdi 附加目录" "DVEfiles:VCS DVE 运行日志目录"; do
        _d="${_x%%:*}"; _l="${_x#*:}"
        [ -d "$INSTALL_ROOT/$_d" ] && uninstall_dir "$INSTALL_ROOT/$_d" "$_l"
    done
    unset _x _d _l
    # 全量卸载后 Installer 状态目录 .installer 一并清理
    # （可能残留 vcs_docs 等"状态名 ≠ 目录名"的附加产品状态，导致 .installer 无法自动清空）
    uninstall_dir "$INSTALL_ROOT/.installer" "Installer 状态目录 .installer"
fi

# ---------- 自动重新加载 bashrc（移除块后立即生效）----------
[ -f "$BASHRC_FILE" ] && . "$BASHRC_FILE" 2>/dev/null && ok "已自动重新加载 $BASHRC_FILE"

# ---------- 汇总 ----------
SUMMARY_TOTAL="$(($(date +%s) - TOTAL_T0))"
print_summary
echo " 后续建议："
echo "   1) env | grep -i synopsys   # 确认环境变量已清除（或重新登录）"
echo "   2) 如需同时清理安装包目录：rm -rf $PKG_BASE（请确认不再需要）"
echo ""
# 等待日志 tee 管道 flush 完成（避免 run.log 尾部缺失）
wait
