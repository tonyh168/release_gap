#!/usr/bin/env bash
# 模板 02：下载模型权重（容器内或宿主机均可，落到挂载目录）
# ─────────────────────────────────────────────────────────────
# 优先 ModelScope（国内快、评测脚本默认也用 modelscope hub）；HuggingFace 作备选。
set -euo pipefail

# ==== 需填写 ====
MODEL_ID="<仓库/模型ID>"          # ModelScope: 如 Qwen/Qwen2.5-7B-Instruct
TARGET_DIR="/models/<模型名>"     # 落盘目录（对应 01 里挂载的 /models）
HUB="<modelscope|huggingface>"    # 默认 modelscope
# ===============

mkdir -p "${TARGET_DIR}"

if [ "${HUB}" = "modelscope" ]; then
  pip install -q modelscope
  modelscope download --model "${MODEL_ID}" --local_dir "${TARGET_DIR}"
else
  pip install -q "huggingface_hub[cli]"
  # 国内可设镜像：export HF_ENDPOINT=https://hf-mirror.com
  huggingface-cli download "${MODEL_ID}" --local-dir "${TARGET_DIR}" --local-dir-use-symlinks False
fi

echo "下载完成：${TARGET_DIR}"
echo "校验："
ls -lh "${TARGET_DIR}"
echo "确认存在 config.json / *.safetensors / tokenizer 文件"
