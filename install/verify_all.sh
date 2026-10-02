#!/bin/bash
# ============================================================
# verify_all.sh — 统一启动验证（对应文中 3.1–3.10 节）
# 必须在 License 认证部署完成之后执行（install_all.sh --all 会自动调用本脚本；
# 也可单独运行：bash verify_all.sh）
# 逐款确认命令可用（命令已在 PATH 生效，或候选二进制存在且可执行），
# 并给出文中各节启动方式对照。
# VCS 3.1 节除命令可用性外，实跑 verify/vcs_smoke 工程（编译+仿真+FSDB 波形）。
# Formality 的 tcsh 依赖按文中 3.5 节在此前置安装（自动 sudo 提权）。
# 候选路径严格按文中 1.3 节各软件专属目录结构，不额外添加 linux64。
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
require_non_root

# 统一输出通道：终端显示的信息与 run.log 内容完全一致
unified_log_init

log_header "verify_all.sh $*"

echo "============================================================"
echo " 统一启动验证（对应文中 3.1–3.10 节，License 认证完成后执行）"
echo "============================================================"

# 文中 3.5 节：Formality 启动验证前置安装 C Shell（需要 root，自动 sudo 提权；
# 失败仅 warn 不阻断验证流程，formality 启动报错时按文中 3.5 节人工补装）
if [ -d "$INSTALL_ROOT/fm/$FM_VERSION" ]; then
    log "安装依赖 tcsh（文中 3.5 节，Formality 启动验证前置）"
    pkg_install tcsh || warn "tcsh 安装失败——Formality 启动可能报 /bin/csh 解释器错误，按文中 3.5 节补装后重试"
fi

# verify_cmd <命令> <名称(章节)> <候选相对路径...>
# 候选路径与 bashrc 设定（文中 1.3 节）一一对应：
#   SCL        scl/$SCL_VERSION/linux64/bin/{lmgrd,lmstat}
#   VCS        vcs/$VCS_VERSION/bin + amd64/bin（无 linux64）
#   Verdi      verdi/$VERDI_VERSION/bin
#   Spyglass   spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME/bin（二级 SPYGLASS_HOME 目录）
#   DC         syn/$DC_VERSION/bin
#   Formality  fm/$FM_VERSION/bin
#   FC         fusioncompiler/$FC_VERSION/bin
#   ICC2       icc2/$ICC2_VERSION/bin
#   PrimeTime  prime/$PT_VERSION/bin（另需 SYNOPSYS_DGCOM_ROOT，见 1.3 节）
#   LC         lc/$LC_VERSION/bin
#   Hspice     hspice/$HSPICE_VERSION/hspice/bin（二级 hspice 目录）
verify_cmd "installer"     "Installer(1.1)"     "installer/installer"
verify_cmd "lmgrd"         "SCL(1.4)"           "scl/$SCL_VERSION/linux64/bin/lmgrd"
verify_cmd "lmstat"        "SCL(1.4)"           "scl/$SCL_VERSION/linux64/bin/lmstat"
verify_cmd "vcs"           "VCS(3.1)"           "vcs/$VCS_VERSION/bin/vcs vcs/$VCS_VERSION/amd64/bin/vcs"
# 注：VCS V-2023.12-SP1 不再提供独立 vcs_shell 二进制（bin / amd64/bin / linux64/bin 均无），
#     3.1 节验证用例为 vcs_smoke（vcs 编译），故不校验 vcs_shell，避免误报 WARN。

# 3.1 节 VCS 启动验证：实跑 verify/vcs_smoke 工程（vcs 编译 + 仿真 + 生成 FSDB 波形）
# 本脚本约定在 License 认证部署后执行，因此 smoke 需 License 已生效；
# 失败多为 License 未起或环境问题，详细原因见 verify/vcs_smoke/smoke.log
SMOKE_DIR="$SCRIPT_DIR/verify/vcs_smoke"
if [ -f "$SMOKE_DIR/run_smoke.sh" ]; then
    [ -f "$BASHRC_FILE" ] && . "$BASHRC_FILE"
    log "运行 VCS smoke 用例（verify/vcs_smoke/run_smoke.sh：编译+仿真+FSDB，最长 10 分钟）"
    local smoke_rc=0
    ( cd "$SMOKE_DIR" && timeout 600 bash run_smoke.sh >/dev/null 2>&1 ) || smoke_rc=$?
    if [ "$smoke_rc" -eq 0 ]; then
        local fsdb_size=0
        [ -f "$SMOKE_DIR/result/nf6_mux2.fsdb" ] && fsdb_size="$(stat -c%s "$SMOKE_DIR/result/nf6_mux2.fsdb" 2>/dev/null || echo 0)"
        ok "VCS smoke 用例通过：simv_smoke 编译+仿真成功，波形 result/nf6_mux2.fsdb（$fsdb_size 字节）已生成于 verify/vcs_smoke/"
    elif [ "$smoke_rc" -eq 124 ]; then
        warn "VCS smoke 用例超时（>10 分钟）——检查 verify/vcs_smoke/result/smoke.log"
    else
        warn "VCS smoke 用例未通过（rc=$smoke_rc）——多为 License 未生效或环境问题，详见 verify/vcs_smoke/result/smoke.log"
    fi
    unset smoke_rc fsdb_size
else
    warn "未找到 verify/vcs_smoke 工程（run_smoke.sh），跳过 3.1 节 smoke 实跑，仅验证 vcs 命令可用"
fi
verify_cmd "verdi"         "Verdi(3.2)"         "verdi/$VERDI_VERSION/bin/verdi"
verify_cmd "spyglass"      "Spyglass(3.3)"      "spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME/bin/spyglass"
verify_cmd "dc_shell"      "DC(3.4)"            "syn/$DC_VERSION/bin/dc_shell"
verify_cmd "design_vision" "DC(3.4)"            "syn/$DC_VERSION/bin/design_vision"
verify_cmd "formality"     "Formality(3.5)"     "fm/$FM_VERSION/bin/formality"
verify_cmd "fc_shell"      "FC(3.6)"            "fusioncompiler/$FC_VERSION/bin/fc_shell"
verify_cmd "icc2_shell"    "ICC2(3.7)"          "icc2/$ICC2_VERSION/bin/icc2_shell"
verify_cmd "primetime"     "PrimeTime(3.8)"     "prime/$PT_VERSION/bin/primetime"
verify_cmd "pt_shell"      "PrimeTime(3.8)"     "prime/$PT_VERSION/bin/pt_shell"
verify_cmd "lc_shell"      "LC(3.9)"            "lc/$LC_VERSION/bin/lc_shell"
verify_cmd "hspice"        "Hspice(3.10)"       "hspice/$HSPICE_VERSION/hspice/bin/hspice"

echo ""
echo " 启动方式对照（文中 3.x 节）："
echo "   VCS       3.1  vcs_smoke 用例（verify/vcs_smoke/run_smoke.sh，上方已实跑）"
echo "   Verdi     3.2  verdi 或 verdi -licdebug"
echo "   Spyglass  3.3  spyglass"
echo "   DC        3.4  design_vision"
echo "   Formality 3.5  formality（依赖 tcsh，上方已自动安装）"
echo "   FC        3.6  fc_shell -gui"
echo "   ICC2      3.7  输入 icc2 即可启动 GUI"
echo "   PrimeTime 3.8  pt_shell -gui 或 primetime"
echo "   LC        3.9  lc_shell -gui"
echo "   Hspice    3.10 hspice -I"
echo ""
# 等待日志 tee 管道 flush 完成（避免 run.log 尾部缺失）
wait
