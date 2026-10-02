#!/bin/bash
# ============================================================
# start_license.sh — Synopsys License Server 启停脚本
# 对应文中 2.2.1 节（start/stop/restart/status）
# 本文件为模板：路径由 license/setup_license.sh 按 install.conf 渲染后
# 安装到 $INSTALL_ROOT/scl/$SCL_VERSION/admin/license/start_license.sh
# 也支持用环境变量直接覆盖（如手工部署时）：
#   SCL_BIN / LICENSE_FILE / LOG_FILE
# ============================================================
# Synopsys License Server Startup Script

SCL_BIN="${SCL_BIN:-__SCL_BIN__}"
LICENSE_FILE="${LICENSE_FILE:-__LICENSE_FILE__}"
LOG_FILE="${LOG_FILE:-__LOG_FILE__}"

mkdir -p "$(dirname "${LOG_FILE}")"

start() {
    echo "Starting Synopsys License Server..."
    echo "License file: ${LICENSE_FILE}"
    echo "Log file: ${LOG_FILE}"
    ${SCL_BIN}/lmgrd -c ${LICENSE_FILE} -l ${LOG_FILE}
    sleep 2
    ${SCL_BIN}/lmstat -a -c ${LICENSE_FILE}
}

stop() {
    echo "Stopping Synopsys License Server..."
    ${SCL_BIN}/lmdown -c ${LICENSE_FILE} -q
    echo "License server stopped."
}

status() {
    ${SCL_BIN}/lmstat -a -c ${LICENSE_FILE}
}

restart() {
    stop
    sleep 2
    start
}

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    status) status ;;
    *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac
