#!/usr/bin/env bash
# 模板 04：对已运行的 vLLM 服务做精度评测 + 达标判定
# ─────────────────────────────────────────────────────────────
# 直接调用 release_评测标准/ 里的官方脚本（fast_gpqa.py + accuracy_compare.py）。
# 判据：相对 NV 基线退化 ≤ 5%（或与自测基线对比 ≤ 5%）。
set -euo pipefail

# ==== 需填写 ====
EVAL_DIR="<release_评测标准 的绝对路径>"   # 如 /flagos-workspace/release_评测标准
SERVED_NAME="<模型名>"                     # 与 03 的 --served-model-name 一致；可留空由脚本自动探测
API_BASE="http://localhost:8000/v1"
OUT_DIR="/flagos-workspace/eval_out/${SERVED_NAME}"
NV_MODEL="<NV基线表中的模型名>"            # 查 nv_baseline.yaml；查不到则用两轮对比模式
# ===============

pip install -q requests pyyaml 'evalscope==1.5.1'   # 版本锁定 1.5.1
mkdir -p "${OUT_DIR}"
cd "${EVAL_DIR}"

# ── 1. 跑 GPQA Diamond（默认 50 题主判据）──
python3 fast_gpqa.py \
  --model-name "${SERVED_NAME}" \
  --api-base "${API_BASE}" \
  --output "${OUT_DIR}/gpqa.json"
# 全量 198 题加 --limit 0；thinking 模型(qwq/deepseek-r1)脚本自动识别，单轮可能数小时，勿中断。

# ── 2. 达标判定 ──
# 方式 A：对比 NV 参考基线（首选）
python3 accuracy_compare.py \
  --v2 "${OUT_DIR}/gpqa.json" \
  --nv-baseline "${NV_MODEL}" \
  --nv-baseline-file "${EVAL_DIR}/nv_baseline.yaml" \
  --output "${OUT_DIR}/verdict.json" --json
RC=$?
echo "判定退出码: ${RC}  (0=达标 1=不达标 2=参数错 3=缺NV基线)"

# 方式 B：若退出码 3（NV 表无此模型），改用两轮对比 —— 先在 NV/参考环境跑一份 baseline.json，再：
#   python3 accuracy_compare.py --v1 baseline.json --v2 "${OUT_DIR}/gpqa.json" --output "${OUT_DIR}/verdict.json"

# ── 结果解读 ──
# gpqa.json 里：score=正确率%；truncation_detected=true → 被 max_tokens 截断，分偏低；
# runaway_detection.runaway_count>0 → 复读死循环污染，需排查服务。
# ⚠ 评测期间不要同时跑性能测试，抢 GPU 会污染结果。
echo "结果目录：${OUT_DIR}"
