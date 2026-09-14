#!/usr/bin/env bash
# 模板 02：从 ModelScope 拉模型权重到容器 /models，再供 vLLM 加载
# ─────────────────────────────────────────────────────────────
# ⚠ 硬性约定：本项目所有待测模型均以 ModelScope 为准。测试前必须先把权重从
#   ModelScope 拉到容器 /models 目录，vllm serve 再从本地 /models 加载。
#   若某模型在 ModelScope 上查不到 → 立即停止并报错给发起人，不要自行找别的源顶替。
set -euo pipefail

# ==== 需填写 ====
MODEL_ID="<ModelScope仓库/模型ID>"   # 发起人给的即完整 id（如 Qwen/Qwen2.5-7B-Instruct）；直接用，不猜不补
TARGET_DIR="/models/<模型名>"        # 落盘目录（对应 01 里挂载的 /models）
# ===============

pip install -q modelscope

# 1) 先探测 ModelScope 上是否存在该模型；不存在则停下报错，不静默换源
if ! modelscope download --model "${MODEL_ID}" --local_dir "${TARGET_DIR}"; then
  echo "❌ ModelScope 上未找到或拉取失败：${MODEL_ID}" >&2
  echo "   按项目约定，模型源以 ModelScope 为准。请停止本模型的测试，把该情况报告给发起人，" >&2
  echo "   确认正确的 ModelScope id 或改由发起人提供权重，再继续。" >&2
  exit 2
fi

echo "下载完成：${TARGET_DIR}"
echo "校验："
ls -lh "${TARGET_DIR}"
echo "确认存在 config.json / *.safetensors / tokenizer 文件后，vllm serve 从 ${TARGET_DIR} 本地加载"
