#!/bin/bash
# ============================================================
# install_spyglass.sh — Spyglass（文中 1.7 节）
# 差异项：安装包目录 spyglass_vV-2023.12-SP1；
#         离线文档《spyglass_vV-2023.12-SP1_docs.tar.gz》位于包目录内时自动安装：
#         docs 目录路径通过 INSTALLER_EXTRA_STDIN 喂给 Installer 交互提示（官方 post_install
#         流程安装）；Installer 未正确接收时由脚本兜底解压（un tarFile 等价动作）。
# 预期良性警告（Installer 输出，不影响安装）：
#   "doesn't contain any valid EST file for platform linux64" —— Spyglass 2023.12 包
#   只有 common 平台（无 linux64.spf），-platform linux64 时 Installer 报此提示但照常安装。
# 注意：SPYGLASS_HOME 含二级目录 /SPYGLASS_HOME（文中 1.3 差异点 3）
# ============================================================
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
require_non_root

PKG_DIR="$PKG_BASE/spyglass_vV-${SPYGLASS_VERSION#V-}"
INSTALLER_BIN="$INSTALL_ROOT/installer/installer"

# 清理历史版本脚本残留的 docs 软链（旧逻辑产物；仅删除链接本身，不影响包目录原始 tar）
for _l in "$SCRIPT_DIR"/spyglass_vV-*_docs.tar.gz; do
    [ -L "$_l" ] && rm -f "$_l" 2>/dev/null
done

# 1.3 节 bashrc：Spyglass 段（二级 SPYGLASS_HOME 目录，与文中一致）——先写好 bashrc 再安装（文章 1.3（1）→（2）顺序）
bashrc_block_add "SPYGLASS" "export SPYGLASS_HOME=\$Synopsys_DIR/spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME
export PATH=\$SPYGLASS_HOME/bin:\$PATH"

# 把 docs 目录路径喂给 Installer 的交互提示（"please enter the full path ... Spyglass Docs ::"
# 对 spyglass 与 ufe_optional_spyglass-vcs 两个产品各询问一次，按实测顺序喂两行路径），
# 使 post_install.sh 收到正确的 -docSourcePath，离线文档由 Installer 官方流程安装（不再报 WARNING）。
# 下方仍保留手动解压作兜底：若 Installer 未正确接收，检测到 doc 缺失时自动补齐。
INSTALLER_EXTRA_STDIN="$PKG_DIR
$PKG_DIR"

install_one "$PKG_DIR" "spyglass" "spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME/bin/spyglass"
unset INSTALLER_EXTRA_STDIN

# Spyglass 离线文档兜底（文中 1.7 节）：Installer 5.9 命令行模式对 docs 的处理依赖 stdin
# 应答（已在上方通过 INSTALLER_EXTRA_STDIN 喂入 docs 目录路径）；若个别版本未正确接收
# （日志仍出现 "not available under"），这里执行与官方 untarFile 等价的动作补齐：
# cd $SPYGLASS_HOME/.. && gtar zxvf $docs_tar（docs tar 顶层为 SPYGLASS_HOME/doc/...，
# 解压后并入现有 SPYGLASS_HOME，无交互、无 License 依赖）。doc 已存在（Installer 已装）时跳过。
_docs_tar="$(ls "$PKG_DIR/"*"_docs.tar.gz" 2>/dev/null | head -1)"
if [ -n "$_docs_tar" ] && [ -d "$INSTALL_ROOT/spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME" ]; then
    if [ -d "$INSTALL_ROOT/spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME/doc" ]; then
        ok "Spyglass 离线文档已由 Installer 安装：$INSTALL_ROOT/spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME/doc"
    elif ( cd "$INSTALL_ROOT/spyglass/$SPYGLASS_VERSION" && tar zxf "$_docs_tar" 2>/dev/null ) && \
       [ -d "$INSTALL_ROOT/spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME/doc" ]; then
        ok "Spyglass 离线文档已安装（脚本兜底解压）：$INSTALL_ROOT/spyglass/$SPYGLASS_VERSION/SPYGLASS_HOME/doc"
    else
        warn "Spyglass 离线文档解压失败（可选，不影响 Spyglass 主程序功能；可手动解压 $_docs_tar 到 $INSTALL_ROOT/spyglass/$SPYGLASS_VERSION/）"
    fi
elif [ -z "$_docs_tar" ]; then
    warn "未在 $PKG_DIR 下找到 *_docs.tar.gz（可选离线文档，不影响 Spyglass 主程序功能）"
else
    warn "SPYGLASS_HOME 目录未就绪，跳过 Spyglass 离线文档安装（可选）"
fi

source ~/.bashrc
log "Spyglass 安装完成。安装后 $INSTALL_ROOT 下会出现 spyglass 与 ufe_optional_spyglass-vcs 两个目录（文中 1.7 节）。启动验证见文中 3.3 节（spyglass，由 install_all.sh 在 License 认证后统一执行）。"
