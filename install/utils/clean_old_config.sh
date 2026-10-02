#!/bin/bash
# ============================================================
# clean_old_config.sh — 清理 ~/.bashrc 中旧版/手动 Synopsys 环境配置
# 作用：备份 bashrc 后，将命中行逐行注释为 # [Synopsys-old]（可逆，可随时还原）
# 适用：2018 等旧版本残留、手工加的 lmgrd/LM_LICENSE_FILE 等，避免与新套件环境变量冲突
# 用法：bash clean_old_config.sh
# 还原：cp ~/.bashrc.synopsys.old.<时间戳> ~/.bashrc
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

bashrc_old_synopsys_clean

log "旧版 Synopsys 配置清理完成。请重新登录或执行 source ~/.bashrc 使新环境生效。"
log "如需还原：cp ~/.bashrc.synopsys.old.* ~/.bashrc（选择最新的时间戳备份）"
