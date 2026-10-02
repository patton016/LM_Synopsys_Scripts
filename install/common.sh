#!/bin/bash
# ============================================================
# common.sh — 公共函数库
# 对应文中：1.2 通用安装流程 / 1.3 bashrc 设定 / 3.x 启动验证
# 用法：被 install_all.sh 及各 tools/install_*.sh 脚本 source
# ============================================================

# ---------- 基础环境 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/install.conf" ] && . "$SCRIPT_DIR/install.conf"

# 实际登录用户 HOME（sudo 执行时取发起人，避免环境变量误写入 /root/.bashrc）
RUN_USER_HOME="$(getent passwd "$RUN_USER" 2>/dev/null | cut -d: -f6)"
[ -n "$RUN_USER_HOME" ] && [ -d "$RUN_USER_HOME" ] || RUN_USER_HOME="$HOME"
# bashrc 目标文件（默认写入实际用户而非 root；可用环境变量 BASHRC_FILE 覆盖）
BASHRC_FILE="${BASHRC_FILE:-$RUN_USER_HOME/.bashrc}"

# 日志：统一保存到脚本目录下的 run.log（可用环境变量 LOG_PATH 覆盖；追加写入，不清空历史）
# 统一输出机制：顶层入口（install_all.sh / uninstall_all.sh / setup_license.sh）调用
# unified_log_init 后，stdout/stderr 整体 tee 到 run.log —— 交互界面看到的信息与
# run.log 完全一致（纯文本，无 ANSI 颜色码）。子脚本/单独运行（UNIFIED_LOG=no）时
# 由 emit 自行 tee，行为不变。日志内容均带时间戳。
LOG_PATH="${LOG_PATH:-$SCRIPT_DIR/run.log}"
# 写出：UNIFIED_LOG=yes 时 stdout 已被顶层 tee 兜底（只 echo，避免重复写文件）；
# 否则自行 tee（终端 + run.log 双写）
emit() { if [ "${UNIFIED_LOG:-no}" = "yes" ]; then echo "$*"; else echo "$*" | tee -a "$LOG_PATH"; fi; }
log()  { emit "[INFO ] $(date '+%F %T') $*"; }
warn() { emit "[WARN ] $(date '+%F %T') $*"; }
die()  { emit "[ERROR] $(date '+%F %T') $*"; exit 1; }
ok()   { emit "[ OK  ] $(date '+%F %T') $*"; }

# 统一输出通道初始化：顶层入口在产生任何输出之前调用。
# 之后所有 stdout/stderr（含子脚本 echo、Installer 输出、结果汇总等）同时进入
# 终端与 run.log，二者内容一致；UNIFIED_LOG 防止嵌套 exec（子进程不再重复重定向）。
unified_log_init() {
    [ "${UNIFIED_LOG:-no}" = "yes" ] && return 0
    # export：必须传给子进程（bash install_*.sh），否则子进程会再次 exec tee 造成 run.log 双写
    export UNIFIED_LOG=yes
    exec 3>&1
    exec 1> >(tee -a "$LOG_PATH")
    exec 2>&1
}

# 会话分隔头：顶层入口脚本开头调用，在 run.log 中标记本次运行的开始
# （统一模式下同时显示到终端，与 run.log 一致）
log_header() {
    if [ "${UNIFIED_LOG:-no}" = "yes" ]; then
        echo ""
        echo "============================================================"
        echo "[SESSION] $(date '+%F %T') 命令：$0 $*"
        echo "============================================================"
    else
        { echo ""; echo "============================================================"
          echo "[SESSION] $(date '+%F %T') 命令：$0 $*"
          echo "============================================================"; } >> "$LOG_PATH"
    fi
}

# 确保以 root 运行（License 部署需要：systemd / SELinux / hostnamectl）
require_root() {
    [ "$(id -u)" -eq 0 ] || die "请以 root 运行：sudo bash $0 $*"
}

# 确保以普通用户运行（Synopsys Installer 明确拒绝 root 账户，见其
#  "The Installer must not be run from a root user account" 警告；软件安装到
#  用户目录无需 root）。顶层安装/卸载入口与各 tools/*.sh 使用；License 部署
#  步骤由顶层脚本自动 sudo 提权执行。
require_non_root() {
    [ "$(id -u)" -ne 0 ] || die "请勿以 root/sudo 运行本脚本：Synopsys Installer 拒绝 root 账户。请用普通用户直接运行：bash $0 $*"
}

# 检查命令是否存在
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- 跨发行版软件包安装（AlmaLinux 8 / CentOS 7 / Ubuntu 18.04+）----------
# 自动探测包管理器：apt-get > dnf > yum
detect_pkgmgr() {
    if have apt-get; then echo "apt-get"
    elif have dnf; then echo "dnf"
    elif have yum; then echo "yum"
    else echo ""; fi
}
# RHEL 系主版本号（7/8/9；非 RHEL 系如 Ubuntu 返回 0）
# 用于区分依赖差异：如 libnsl.so.1 在 RHEL8+ 被移除需补装，RHEL7/CentOS7 自带
rhel_major() {
    local v
    v="$(grep -E '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2)"
    v="${v//\"/}"
    if [ "$v" = "7" ] || [ "$v" = "8" ] || [ "$v" = "9" ]; then
        echo "$v"
    else
        echo "0"
    fi
}
# 包名映射（主要针对 Ubuntu 的包名差异；RHEL 系包名原样使用）
pkg_map() {
    local pm="$1"; shift
    local p out=""
    for p in "$@"; do
        case "$pm:$p" in
            apt-get:redhat-lsb-core) out="$out lsb-release" ;;
            apt-get:libnsl)         out="$out libnsl1" ;;
            apt-get:libXScrnSaver)  out="$out libxss1" ;;
            apt-get:libXtst)        out="$out libxtst6" ;;
            apt-get:libXrender)     out="$out libxrender1" ;;
            apt-get:expat)          out="$out libexpat1" ;;
            *)                      out="$out $p" ;;
        esac
    done
    echo "$out"
}
# 统一安装：pkg_install tcsh libnsl ...
# 返回 0/1；失败时第二次重试并显示安装输出，便于诊断
pkg_install() {
    local pm pkgs sudocmd=""
    # 包管理命令需要 root：非 root 时在函数内部自动 sudo 提权。
    # 注意：pkg_install 是 bash 函数，不能在 sudo 子进程里调用
    # （install_icc2.sh 曾用 "sudo pkg_install" 导致 sudo: pkg_install: command not found），
    # 调用方一律直接调 pkg_install，不得再套 sudo。
    [ "$(id -u)" -ne 0 ] && sudocmd="sudo"
    pm="$(detect_pkgmgr)"
    [ -n "$pm" ] || die "未检测到包管理器（apt-get/dnf/yum），请手动安装：$*"
    pkgs="$(pkg_map "$pm" "$@")"
    log "安装依赖（$pm）：$pkgs"
    # RHEL 系（yum/dnf）：先 rpm -q 检查，全部已装则直接返回（无需 sudo、无需联网），
    # 只对缺失的包执行安装——避免"已装仍报失败"误报，以及长安装后 sudo 凭据过期导致的卡顿/误判
    if [ "$pm" != "apt-get" ]; then
        local missing="" p
        for p in $pkgs; do
            rpm -q "$p" >/dev/null 2>&1 || missing="$missing $p"
        done
        if [ -z "$missing" ]; then
            log "依赖已全部安装（$pkgs），跳过安装"
            return 0
        fi
        pkgs="$missing"
        log "仅安装缺失依赖（$pm）：$pkgs"
    fi
    if [ "$pm" = "apt-get" ]; then
        $sudocmd apt-get update -qq >/dev/null 2>&1
        $sudocmd apt-get install -y $pkgs >/dev/null 2>&1 || $sudocmd apt-get install -y $pkgs
    else
        $sudocmd $pm install -y $pkgs >/dev/null 2>&1 || $sudocmd $pm install -y $pkgs
    fi
}

# ---------- bashrc 环境变量注入（文中 1.3 节）----------
# 幂等：带 # >>> SYNOPSYS:<标记> / # <<< SYNOPSYS:<标记> 包裹块。
# 已存在同名块时不再跳过，而是备份 bashrc 后覆盖更新（保证用最新设定覆盖旧设定）。
bashrc_block_add() {
    local marker="$1" block="$2"
    local bashrc="${BASHRC_FILE:-$HOME/.bashrc}"
    [ -f "$bashrc" ] || touch "$bashrc"
    if grep -q "# >>> SYNOPSYS:$marker" "$bashrc"; then
        # 幂等：已有同名块且内容与目标完全一致时静默跳过（不备份、不警告、不重复写入，
        # 避免每次重跑都生成 .synopsys.bak 备份并刷 WARN）
        local existing want
        existing="$(sed -n "/^# >>> SYNOPSYS:$marker/,/^# <<< SYNOPSYS:$marker$/p" "$bashrc")"
        want="# >>> SYNOPSYS:$marker
$(printf '%s\n' "$block")
# <<< SYNOPSYS:$marker"
        [ "$existing" = "$want" ] && return 0
        local bak="$bashrc.synopsys.bak.$(date '+%Y%m%d%H%M%S')"
        cp -p "$bashrc" "$bak"
        sed -i "/^# >>> SYNOPSYS:$marker/,/^# <<< SYNOPSYS:$marker$/d" "$bashrc"
        warn "bashrc 已存在 SYNOPSYS:$marker 块（内容有更新），已备份原文件到 $bak 并覆盖更新"
    fi
    # 压缩连续空行为单个空行（避免多次重装/卸载在 bashrc 中积累大段空行）
    sed -i '/^$/N;/^\n$/D' "$bashrc"
    {
        # 块前至多一个空行分隔：文件末尾已空行则不再补，否则补一个
        [ -s "$bashrc" ] && [ -n "$(tail -n1 "$bashrc")" ] && echo ""
        echo "# >>> SYNOPSYS:$marker"
        printf '%s\n' "$block"
        echo "# <<< SYNOPSYS:$marker"
    } >> "$bashrc"
    ok "已向 $bashrc 写入 SYNOPSYS:$marker 环境变量块"
}

# ---------- 旧版 Synopsys 配置检测与清理（bashrc 中本套件块之外）----------
# 检测到旧版/手动 Synopsys 环境变量（2018 等旧版本残留）时：先备份 bashrc，再将这些行注释掉。
# 新套件的 SYNOPSYS: 块已提供完整环境变量（Synopsys_DIR / PATH / LM_LICENSE_FILE 等），
# 旧行注释后不再干扰；备份文件可随时回滚。幂等：已注释的命中行不再重复处理，全部清理后不再触发。
bashrc_old_synopsys_clean() {
    local bashrc="${BASHRC_FILE:-$HOME/.bashrc}"
    [ -f "$bashrc" ] || return 0
    local tmp hits ln content bak modified=0
    tmp="$(mktemp)"
    # 先剔除本套件管理的 SYNOPSYS: 块（结束行格式为 # <<< SYNOPSYS:<marker>，只匹配前缀即可），
    # 再在剩余行中查找旧版 Synopsys 痕迹（只找未注释行）。
    # -i 忽略大小写（旧配置常用 Synopsys_Dir / Synopsys_DIR 等大写）；
    # 变量名模式（scl_home/vcs_home/…）覆盖只引用 $SCL_HOME 之类变量、不含 synopsys 字样的旧 PATH 行。
    # 注意：不能用 -n（静默模式）——-n 与 d 组合会什么都不输出，导致检测永远为空。
    sed '/^# >>> SYNOPSYS:/,/^# <<< SYNOPSYS:/d' "$bashrc" > "$tmp"
    hits="$(grep -inE 'synopsys|snpslmd|snpslmd_license|lmgrd|lmstat|scl_home|vcs_home|verdi_home|syn_home|primetime_home|formality_home|starrc_home|lc_home|icc_home' "$tmp" | grep -vE ':[[:space:]]*#' | head -50)"
    rm -f "$tmp"
    [ -n "$hits" ] || return 0
    bak="$bashrc.synopsys.old.$(date '+%Y%m%d%H%M%S')"
    cp -p "$bashrc" "$bak"
    warn "检测到 $bashrc 中存在旧版/手动 Synopsys 环境配置（2018 等旧版本残留），原文件已备份：$bak"
    warn "现将命中行注释掉（新套件的 SYNOPSYS: 块会接管相应环境变量）："
    # here-string 重定向的循环体在当前 shell 执行（非管道子 shell），modified 在循环后仍有效
    while IFS= read -r l; do
        ln="${l%%:*}"
        content="${l#*:}"
        if [ "${content#\#}" != "$content" ]; then continue; fi
        sed -i "${ln}s/^/# [Synopsys-old] /" "$bashrc"
        modified=1
        warn "    行 $ln 已注释：$(printf '%s' "$content" | sed 's/^[[:space:]]*//' | cut -c1-90)"
    done <<< "$hits"
    if [ "$modified" = "1" ]; then
        ok "已注释 $modified 处旧版 Synopsys 配置（如需恢复：cp $bak $bashrc）"
    fi
}

# ---------- bashrc 块移除（卸载用，幂等）----------
# 删除 # >>> SYNOPSYS:<marker> 到 # <<< SYNOPSYS:<marker> 之间的全部行
bashrc_block_remove() {
    local marker="$1"
    local bashrc="${BASHRC_FILE:-$HOME/.bashrc}"
    [ -f "$bashrc" ] || { warn "bashrc 不存在：$bashrc，跳过"; return 0; }
    if grep -q "# >>> SYNOPSYS:$marker" "$bashrc"; then
        sed -i "/^# >>> SYNOPSYS:$marker/,/^# <<< SYNOPSYS:$marker$/d" "$bashrc"
        # 压缩删除块后残留的连续空行
        sed -i '/^$/N;/^\n$/D' "$bashrc"
        ok "已从 $bashrc 移除 SYNOPSYS:$marker 块"
    else
        warn "bashrc 中未找到 SYNOPSYS:$marker 块，跳过"
    fi
}

# ---------- 删除安装目录（卸载用，带占用提示与确认）----------
# $1 = 目录；$2 = 名称；确认开关 UNINSTALL_FORCE=yes 跳过交互
# 删除成功后顺带清理 Installer 的"已安装"状态记录 $INSTALL_ROOT/.installer/<tag>
# （tag 从目录名推导），否则 Installer 会误判该产品已安装而跳过重装。
uninstall_dir() {
    local dir="$1" label="$2" size="" tag=""
    [ -d "$dir" ] || { warn "$label 未安装（目录不存在：$dir），跳过"; return 0; }
    size="$(du -sh "$dir" 2>/dev/null | cut -f1)"
    echo "  将删除 $label：$dir（占用 $size）"
    if [ "${UNINSTALL_FORCE:-no}" != "yes" ]; then
        read -r -p "  确认删除？[y/N] " ans
        [ "$ans" = "y" ] || [ "$ans" = "Y" ] || { warn "已跳过 $label"; return 0; }
    fi
    rm -rf "$dir" 2>/dev/null
    # 普通 rm 可能因 root 属主文件删除不干净（Installer 可能以 root 创建部分文件），
    # 用 sudo 兜底并验证目录确已删除，避免残留空壳导致 Installer 误判"已安装"
    if [ -d "$dir" ]; then
        sudo rm -rf "$dir" 2>/dev/null
    fi
    if [ ! -d "$dir" ]; then
        ok "已删除 $label：$dir"
        # 清理 Installer 安装状态记录（.installer/<tag>；Installer 判"已安装"的依据）
        tag="$(basename "$dir")"
        if [ -n "$tag" ] && [ -d "$INSTALL_ROOT/.installer/$tag" ]; then
            rm -rf "$INSTALL_ROOT/.installer/$tag" 2>/dev/null
            [ -d "$INSTALL_ROOT/.installer/$tag" ] && sudo rm -rf "$INSTALL_ROOT/.installer/$tag" 2>/dev/null
            if [ ! -d "$INSTALL_ROOT/.installer/$tag" ]; then
                ok "已清理 Installer 安装状态：$INSTALL_ROOT/.installer/$tag"
            else
                warn "Installer 安装状态清理失败：$INSTALL_ROOT/.installer/$tag（可手动 sudo rm -rf）"
            fi
        fi
        # .installer 已无任何产品记录时整体删除，避免残留空目录
        if [ -d "$INSTALL_ROOT/.installer" ]; then
            local left
            left="$(find "$INSTALL_ROOT/.installer" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)"
            if [ "$left" -eq 0 ]; then
                rm -rf "$INSTALL_ROOT/.installer" 2>/dev/null
                [ -d "$INSTALL_ROOT/.installer" ] && sudo rm -rf "$INSTALL_ROOT/.installer" 2>/dev/null
                [ ! -d "$INSTALL_ROOT/.installer" ] && ok "已清理空 Installer 状态目录：$INSTALL_ROOT/.installer"
            fi
        fi
    else
        warn "删除 $label 失败，目录仍存在：$dir（请人工检查权限后 sudo rm -rf \"$dir\"）"
    fi
}

# 卸载单个软件：先删 bashrc 块，再删安装目录（$1=目录 tag，$2=marker，$3=名称）
# 安装目录删除与 Installer 状态清理（.installer/<tag>）统一由 uninstall_dir 完成
uninstall_sw() {
    local tag="$1" marker="$2" label="${3:-$1}"
    if [ -n "$marker" ]; then
        bashrc_block_remove "$marker"
    fi
    uninstall_dir "$INSTALL_ROOT/$tag" "$label"
}

# 关键文件验证辅助：$1=空格分隔的相对路径候选（相对 $INSTALL_ROOT），任一存在且可执行返回 0
# （用 -x 而非 -e：区分"真正安装完成"与"残留的不完整/不可执行空壳"，
#  否则文件存在但权限异常（如 root 属主 644）会被误判为已安装，而 command -v 仍找不到命令）
verify_files_any() {
    local p
    for p in $1; do
        [ -x "$INSTALL_ROOT/$p" ] && return 0
    done
    return 1
}

# 用时格式化：$1=秒数 → "Xm Ys"（不足 1 分钟显示 "Xs"）
fmt_dur() {
    local s="$1"
    if [ "${s:-0}" -ge 60 ]; then printf '%dm %02ds' $((s/60)) $((s%60))
    else printf '%ds' "${s:-0}"; fi
}

# 空间占用格式化：$1=KB → "X.YG / X.YM / XK"（0 → "0"）
fmt_size() {
    local kb="${1:-0}"
    if [ "$kb" -le 0 ]; then printf '0'
    elif [ "$kb" -ge 1048576 ]; then awk -v k="$kb" 'BEGIN{printf "%.1fG", k/1048576}'
    elif [ "$kb" -ge 1024 ]; then awk -v k="$kb" 'BEGIN{printf "%.1fM", k/1024}'
    else printf '%dK' "$kb"
    fi
}

# ---------- 结果汇总列表（安装完成 / 卸载完成 / 中断退出时调用）----------
# 依赖全局变量（由 install_all.sh / uninstall_all.sh 在顶层维护）：
#   ORDER         ：遍历顺序（各顶层脚本自己的顺序）
#   SUMMARY_TAG    ：软件名 → 安装目录名（如 dc → syn）
#   SUMMARY_TIMES  ：软件名 → 用时秒（未执行则无）
#   SUMMARY_STATUS ：软件名 → 状态文本（已安装/未安装/已卸载/卸载失败…）
#   SUMMARY_TOTAL  ：总用时秒
#   SUMMARY_MODE   ：install | uninstall（仅影响标题）
print_summary() {
    local mode="${SUMMARY_MODE:-install}" total="${SUMMARY_TOTAL:-0}"
    local sw tag status dur size size_kb total_kb=0
    echo ""
    echo "============================================================"
    if [ "$mode" = "uninstall" ]; then
        echo " 结果汇总（卸载）"
    elif [ "${SKIP_LICENSE:-no}" = "yes" ]; then
        echo " 结果汇总（已安装未认证）"
    else
        echo " 结果汇总（安装）"
    fi
    echo "============================================================"
    printf "  %-12s %-14s %-12s %-10s\n" "软件" "状态" "空间占用" "用时"
    echo "  ----------------------------------------------------------"
    for sw in $ORDER; do
        tag="${SUMMARY_TAG[$sw]:-$sw}"
        status="${SUMMARY_STATUS[$sw]:-未处理}"
        dur="${SUMMARY_TIMES[$sw]:-}"
        if [ -n "$dur" ]; then dur="$(fmt_dur "$dur")"; else dur="-"; fi
        if [ -d "$INSTALL_ROOT/$tag" ]; then
            size="$(du -sh "$INSTALL_ROOT/$tag" 2>/dev/null | cut -f1)"
            [ -n "$size" ] || size="-"
            # 按 KB 累加，供末尾"总空间占用"统计（仅统计实际存在的安装目录）
            size_kb="$(du -sk "$INSTALL_ROOT/$tag" 2>/dev/null | cut -f1)"
            [ -n "$size_kb" ] && total_kb=$((total_kb + size_kb))
        else
            size="-"
        fi
        printf "  %-12s %-14s %-12s %-10s\n" "$sw" "$status" "$size" "$dur"
    done
    echo "  ----------------------------------------------------------"
    if [ "$mode" = "uninstall" ]; then
        echo "  总空间占用（卸载后残留）: $(fmt_size "$total_kb")"
    else
        echo "  总空间占用 : $(fmt_size "$total_kb")"
    fi
    echo "  总用时     : $(fmt_dur "$total")"
    echo ""
}

# ---------- 通过 Installer 5.9 命令行模式安装（文中 1.2 节通用流程）----------
# $1 = 安装包目录（文中通用流程第 3 步：输入各软件安装包所在目录地址）
# $2 = 目标目录 tag（相对 $INSTALL_ROOT，如 scl / vcs / syn）
# $3 = 关键文件候选（空格分隔的相对路径，任一存在即认为真正安装完成；可空=仅目录判断）
# Installer 5.9 支持命令行模式（不带 -legacy 时 -source/-target 直接生效）：
#   installer -source <包目录> -target <安装根目录>
# 产品默认全部、Site ID 用默认值（000），无交互问答，因此不依赖 expect 自动应答。
# 附加项（Spyglass Docs / PrimeTime DGCOM / LC 启动时检查 License）在命令行模式下
# 由各软件脚本通过 bashrc 环境变量声明（见 install_*.sh 的 bashrc 块）。
install_one() {
    local src_dir="$1" tag="${2:-}" verify="${3:-}"
    [ -d "$src_dir" ] || die "安装包目录不存在：$src_dir （请检查 install.conf 的 PKG_BASE 及包名）"
    [ -x "$INSTALLER_BIN" ] || die "Installer 未就绪：$INSTALLER_BIN （请先安装 Installer）"

    # 已装跳过：目标目录存在且关键文件验证通过 → 视为已真正安装，默认跳过重装
    # （FORCE_INSTALL=yes 时强制重装；重跑脚本即可从中断处继续，已装软件秒过）
    if [ -n "$tag" ] && [ -n "$verify" ] && [ -d "$INSTALL_ROOT/$tag" ] && verify_files_any "$verify" && [ "${FORCE_INSTALL:-no}" != "yes" ]; then
        ok "已安装且验证通过：$INSTALL_ROOT/$tag（跳过重装；如需强制重装请用 install_all.sh --force）"
        return 0
    fi

    # 安装前预检：目标目录已存在但关键文件缺失 → 疑似上次残留的不完整安装，
    # 提示先卸载（否则 Installer 会误判"已安装"而跳过重装）
    if [ -n "$tag" ] && [ -n "$verify" ] && [ -d "$INSTALL_ROOT/$tag" ] && ! verify_files_any "$verify"; then
        warn "检测到 $INSTALL_ROOT/$tag 目录但缺少关键文件（$verify）——疑似残留的不完整安装，Installer 可能跳过重装；建议先执行：bash uninstall_all.sh --only $tag --force"
    fi

    log "开始安装 $tag：源目录 $src_dir"
    local t0
    t0="$(date +%s)"

    # Installer 5.9 命令行模式：-source/-target 直传；-platform linux64 只装 64 位平台
    # （默认会尝试安装全部平台，包含 aarch64 / linux(32位) 等，易因平台包解包失败而整体返回 1，
    #  例如 verdi 含 aarch64 平台、spyglass 含 ufe 附加包）；Site ID 通过 stdin 首行喂入
    # （命令行模式下第一个输入提示即 "Site ID number [000]:"，喂 install.conf 的 SITE_ID）。
    # 附加交互应答：各软件可在调用前设 INSTALLER_EXTRA_STDIN（普通变量，非 export），
    # 提供 Installer 后续交互提示（如 Spyglass 的 docs 目录路径、Verdi 的符号链接确认）的应答行，
    # 按提示顺序逐行消费（实测 5.9：Spyglass=Site ID→docs×2→Accept；Verdi=Site ID→symlink→VERDI HOME→Accept）。
    # 输出：统一模式下 stdout 已被顶层 tee 兜底（直接输出即可，避免双写 run.log）；
    # 单独运行本脚本时自行 tee。timeout 兜底防挂起（返回 124=超时）。
    # Installer 5.9 强制在当前工作目录生成 installer.log，内容与 run.log 重复，运行后自动清理。
    local rc
    if [ "${UNIFIED_LOG:-no}" = "yes" ]; then
        { printf '%s\n%s' "$SITE_ID" "${INSTALLER_EXTRA_STDIN:-}"; } | timeout 5400 "$INSTALLER_BIN" -source "$src_dir" -target "$INSTALL_ROOT" -platform linux64 2>&1
        rc=${PIPESTATUS[1]}
    else
        { printf '%s\n%s' "$SITE_ID" "${INSTALLER_EXTRA_STDIN:-}"; } | timeout 5400 "$INSTALLER_BIN" -source "$src_dir" -target "$INSTALL_ROOT" -platform linux64 2>&1 | tee -a "$LOG_PATH"
        rc=${PIPESTATUS[1]}
    fi
    # 清理 Installer 5.9 强制生成的 installer.log（与 run.log 重复）与临时解包目录
    # （snps_installer_temp_*：正常完成会自动删除，但被中断/超时/失败时可能残留）
    rm -f "$SCRIPT_DIR/installer.log" 2>/dev/null
    rm -rf "$SCRIPT_DIR"/snps_installer_temp_* 2>/dev/null
    rm -rf "$PWD"/snps_installer_temp_* 2>/dev/null
    [ -n "${TMPDIR:-}" ] && rm -rf "$TMPDIR"/snps_installer_temp_* 2>/dev/null
    find /tmp -maxdepth 1 -type d -name 'snps_installer_temp_*' -user "$(id -u)" -exec rm -rf {} + 2>/dev/null
    [ "$rc" -ne 0 ] && warn "Installer 命令行安装返回码 $rc（124=超时；其余输出见 run.log），请人工确认安装结果"

    # 确认安装结果：目录 + 关键文件（任一候选存在才算真正安装完成；未提供候选时仅看目录）
    local dur
    dur="$(($(date +%s) - t0))"
    if [ -n "$tag" ] && [ -d "$INSTALL_ROOT/$tag" ]; then
        if [ -n "$verify" ] && ! verify_files_any "$verify"; then
            warn "检测到 $INSTALL_ROOT/$tag 目录但缺少关键文件（$verify）——$tag 未真正安装成功（残留/不完整），请先卸载后重装：bash uninstall_all.sh --only $tag --force（用时 $(fmt_dur "$dur")）"
        else
            ok "安装完成：$INSTALL_ROOT/$tag（用时 $(fmt_dur "$dur")）"
        fi
    else
        warn "未在 $INSTALL_ROOT 下检测到 $tag 目录，请人工确认安装结果（Installation Failed 时检查包目录与提示语）（用时 $(fmt_dur "$dur")）"
    fi
}

# ---------- 生效校验（文中 3.x：输入 which xxx 可确认生效）----------
# $3 可选：空格分隔的相对 $INSTALL_ROOT 候选路径（与 install_one 的 verify 列表一致）。
# 判定原则：候选文件存在且可执行 = 安装成功（bashrc 环境变量块已写入并自动加载，
# 命令可直接使用）。command -v 未命中属于脚本子进程的
# shell 会话问题，不代表未安装；License 是否有效由 setup_license.sh / check_license.sh
# 单独校验，与安装成功与否无关（两条独立链路）。
verify_cmd() {
    local cmd="$1" tag="${2:-$1}" cand="${3:-}"
    # 自动加载用户 bashrc，使刚注入的环境变量与 PATH 立即生效（无需手动 source ~/.bashrc）
    [ -f "$BASHRC_FILE" ] && . "$BASHRC_FILE"
    # 用内联 command -v 而非 have 函数：用户 .bashrc 可能调用了未定义的 have（如 bash-completion
    # 模板），直接内联可避免该环境下 "have: command not found" 报错干扰判定
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "已生效：$(command -v "$cmd")"
        return 0
    fi
    # command -v 未命中：查候选路径（存在且可执行 → 安装成功，仅当前子 shell 未命中）
    local p
    for p in $cand; do
        if [ -x "$INSTALL_ROOT/$p" ]; then
            ok "$cmd 已安装：$INSTALL_ROOT/$p（bashrc 已写入 SYNOPSYS:$tag 环境变量块并已自动加载，可直接使用）"
            return 0
        fi
    done
    # 真失败（候选均不存在）：分级诊断，区分 PATH 问题与关键文件缺失
    local syn_path st
    syn_path="$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -i -e synopsys -e linux64 2>/dev/null | head -5 | tr '\n' ' ')"
    for p in $cand; do
        if [ -e "$INSTALL_ROOT/$p" ]; then
            st="存在但不可执行（权限异常）"
        else
            st="不存在"
        fi
        warn "  $cmd 候选：$INSTALL_ROOT/$p → $st"
    done
    warn "未找到命令 $cmd 且候选关键文件均缺失 —— $tag 安装可能未成功：PATH 中 Synopsys 相关段 [$syn_path]"
    return 1
}

# 列出文中 3.x 各软件启动命令（供 README / 汇总使用）
launch_hint() {
    cat <<'EOF'
【启动验证命令对照（文中 3.x 节）】
  VCS        : cd vcs_smoke 用例目录 && bash run_smoke.sh
  Verdi      : verdi -nologo -dbdir ./simv_smoke.daidir -fsdb nf6_mux2.fsdb -top tb_nf6_mux2 &
  Spyglass   : spyglass
  DC         : design_vision
  Formality  : formality
  FC         : fc_shell -gui
  ICC2       : icc2（= icc2_shell -gui）
  PrimeTime  : pt_shell -gui 或 primetime
  LC         : lc_shell -gui
  Hspice     : hspice -I
EOF
}
