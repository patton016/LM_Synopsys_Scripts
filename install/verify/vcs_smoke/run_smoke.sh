#!/bin/bash
# www.fpga.pw
# 2026-10-01
# VCS smoke test: verifies VCS license/environment and generates an FSDB waveform.
#
# 产物目录约定：
#   work/   —— 编译过程文件（simv_smoke 可执行、simv_smoke.daidir 调试库等）
#   result/ —— 最终结果文件（nf6_mux2.fsdb 波形、smoke.log 日志）
#
# Usage:
#   cd $PATH/vcs_smoke
#   bash run_smoke.sh

set -e

# Switch to the directory where this script is located
cd "$(dirname "$0")"

# 每次重跑前清空 work/ 与 result/（二者完全由本脚本生成，保证结果目录干净）
rm -rf work result
mkdir -p work result

echo "[SMOKE] Running VCS smoke test in $(pwd)..."
echo "[SMOKE] Work dir : ./work   （编译过程文件）"
echo "[SMOKE] Result dir: ./result （最终结果：波形 + 日志）"

vcs -full64 -sverilog \
  -kdb -debug_access+all \
  -f smoke.f \
  -top tb_nf6_mux2 \
  -R \
  -o work/simv_smoke \
  -l result/smoke.log

# -R 运行时 FSDB 波形生成在当前目录，移入 result/
[ -f nf6_mux2.fsdb ] && mv -f nf6_mux2.fsdb result/

echo "[SMOKE] VCS compile and simulation completed."
echo "[SMOKE] FSDB waveform: result/nf6_mux2.fsdb"
echo "[SMOKE] View in Verdi: verdi -ssf ./result/nf6_mux2.fsdb -dbdir ./work/simv_smoke.daidir -top tb_nf6_mux2"
