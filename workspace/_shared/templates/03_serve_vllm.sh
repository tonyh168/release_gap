#!/usr/bin/env bash
# 模板 03：在容器内启动 vLLM（FlagOS 后端）OpenAI 兼容服务
# ─────────────────────────────────────────────────────────────
# 在 01 启动的容器内执行。FlagOS 环境的 vllm 已集成 plugin-FL / FlagGems / Flagtree，
# 通常通过环境变量启用，无需改命令行；具体开关以厂商镜像 README 为准，记录到 ENV.md。
set -euo pipefail

# ==== 需填写 ====
MODEL_PATH="/models/<模型名>"     # 02 下载的落盘路径
SERVED_NAME="<模型名>"            # 对外暴露的模型名，评测 --model-name 用它；建议与目录同名
TP="<张量并行数>"                 # tensor-parallel，一般 = 使用的卡数（见 ENV.md GPU 数）
PORT="8000"
MAX_LEN="<最大上下文长度>"         # 如 32768；长上下文模型(128k)按显存下调，OOM 是常见失败点
# ===============

# FlagOS 后端开关（如镜像需要显式开启，取消注释；否则镜像默认已启用）
# export VLLM_USE_FLAGGEMS=1
# export FLAGTREE_ENABLE=1

vllm serve "${MODEL_PATH}" \
  --served-model-name "${SERVED_NAME}" \
  --tensor-parallel-size "${TP}" \
  --port "${PORT}" \
  --dtype bfloat16 \
  --max-model-len "${MAX_LEN}" \
  --gpu-memory-utilization 0.90 \
  --trust-remote-code \
  2>&1 | tee /flagos-workspace/serve_${SERVED_NAME}.log

# ── 启动成功判据 ──
# 日志出现 "Application startup complete" / "Uvicorn running on ..." 即就绪。
# 就绪后新开终端自检：
#   curl http://localhost:8000/v1/models
#   curl http://localhost:8000/v1/chat/completions -H 'Content-Type: application/json' \
#     -d '{"model":"'"${SERVED_NAME}"'","messages":[{"role":"user","content":"1+1=?"}]}'
#
# ── 常见启动失败 → 处置（详见 _shared/KNOWLEDGE.md）──
# * 算子崩溃/core dump      → 抓栈定位算子，查 plugin-FL / FlagGems 是否缺实现
# * OOM                     → 降 --max-model-len、升 TP、降 gpu-memory-utilization
# * 卡在 loading weights     → 权重不全或 dtype 不匹配，回模板 02 校验
