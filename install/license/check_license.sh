#!/bin/bash
# ============================================================
# check_license.sh — Synopsys License 校验脚本
# 对应文中 2.1 节（lmstat 检查）与 3.5 节（特性缺失排查方法）
# 用法：bash check_license.sh            # 默认按 install.conf 配置校验
#       bash check_license.sh vcs,verdi   # 只校验指定软件特性
# 无需 root；依赖：lmgrd 进程、lmstat、ss
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

[ -f "$LICENSE_FILE" ] || die "License 文件不存在：$LICENSE_FILE"

# lmstat 定位：优先直查 SCL 候选路径（脚本进程可能未加载 ~/.bashrc 的 PATH），
# 其次回退 PATH 查找；两处都找不到才判定 SCL 未安装
SCL_BIN="${INSTALL_ROOT}/scl/${SCL_VERSION}/linux64/bin"
LMSTAT=""
if [ -x "$SCL_BIN/lmstat" ]; then
    LMSTAT="$SCL_BIN/lmstat"
elif command -v lmstat >/dev/null 2>&1; then
    LMSTAT="$(command -v lmstat)"
else
    die "未找到 lmstat（SCL 未安装，或候选目录不存在：$SCL_BIN）"
fi

WANT="$*"
PASS=0; FAIL=0

echo "============================================================"
echo " [1/4] License 服务进程检查"
echo "============================================================"
if pgrep -x lmgrd >/dev/null 2>&1; then
    echo "  ✓ lmgrd 进程运行中（PID: $(pgrep -x lmgrd | tr '\n' ' ')）"
    PASS=$((PASS+1))
else
    echo "  ✗ 未发现 lmgrd 进程 —— License 服务未启动，请执行 start_license.sh start 或 systemctl start snps-license"
    FAIL=$((FAIL+1))
fi

echo "============================================================"
echo " [2/4] 端口监听检查（${LICENSE_PORT}）"
echo "============================================================"
if have ss; then
    # lmgrd + vendor daemon 启动需要时间（systemd ExecStartPre 已有 10s 延时），
    # 轮询等待端口就绪（最多 30 秒），避免服务刚启动即误报
    PORT_OK=no
    for i in $(seq 1 15); do
        if ss -lnt | grep -q ":${LICENSE_PORT} "; then
            PORT_OK=yes
            break
        fi
        sleep 2
    done
    if [ "$PORT_OK" = "yes" ]; then
        echo "  ✓ 端口 ${LICENSE_PORT} 正在监听"
        PASS=$((PASS+1))
    else
        echo "  ✗ 端口 ${LICENSE_PORT} 未监听（lmgrd 未正常启动或端口被占用，请查看 $LOG_FILE）"
        FAIL=$((FAIL+1))
    fi
else
    echo "  - 未找到 ss 命令，跳过端口检查"
fi

echo "============================================================"
echo " [3/4] lmstat 服务状态检查（文中 2.1 节）"
echo "============================================================"
LMSTAT_OUT="$("$LMSTAT" -a -c "$LICENSE_FILE" 2>&1)"
echo "$LMSTAT_OUT" | grep -iE "license server status|license server.*up|server.*running" | head -5
# 判断 vendor daemon 状态：仅出现 status 行不代表服务可用（DOWN 也会输出），须确认 UP
if echo "$LMSTAT_OUT" | grep -qiE "license server.*up|server.*running"; then
    echo "  ✓ lmstat 输出正常（License Server UP）"
    PASS=$((PASS+1))
else
    echo "  ✗ lmstat 未确认 License Server UP（请查看 $LOG_FILE 排查）"
    FAIL=$((FAIL+1))
fi

echo "============================================================"
echo " [4/4] 软件特性核对（文中 3.5 节：grep License 文件排查缺失特性）"
echo "      说明：特性缺失仅影响对应新工艺/附加功能，工具主体仍可运行；"
echo "      例：Formality-NewTech2 缺失不影响 Formality 主体启动（见文中 3.5 节）"
echo "============================================================"
# 解析 CHECK_FEATURES：逐行 "软件:特性1 特性2 ..."
parse_feature() {
    echo "$CHECK_FEATURES" | sed -n 's/^[[:space:]]*\([^:]*\):\(.*\)$/\1 \2/p'
}
if [ -n "$WANT" ]; then
    # 只校验命令行指定的软件（逗号分隔）
    IFS=',' read -ra want_list <<< "$WANT"
    while read -r sw feats; do
        for w in "${want_list[@]}"; do
            [ "$sw" = "$w" ] || continue
            for f in $feats; do
                if grep -qiE "^[[:space:]]*(FEATURE|INCREMENT)[[:space:]]+$f([[:space:]]|$)" "$LICENSE_FILE"; then
                    echo "  ✓ $sw: 特性 $f 存在于 License 文件"
                else
                    echo "  ✗ $sw: 特性 $f 缺失"
                    MISSING=1
                fi
            done
        done
    done < <(parse_feature)
else
    while read -r sw feats; do
        for f in $feats; do
            if grep -qiE "^[[:space:]]*(FEATURE|INCREMENT)[[:space:]]+$f([[:space:]]|$)" "$LICENSE_FILE"; then
                echo "  ✓ $sw: 特性 $f 存在"
            else
                echo "  ✗ $sw: 特性 $f 缺失"
                MISSING=1
            fi
        done
    done < <(parse_feature)
fi

echo "============================================================"
echo " 校验完成：PASS=$PASS FAIL=$FAIL"
echo " 日志文件：$LOG_FILE（可打开检查确认，见文中 2.1 节）"
echo "============================================================"
[ "$FAIL" -eq 0 ] && [ -z "${MISSING:-}" ]
