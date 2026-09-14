#!/usr/bin/env bash
# 模板 01：用厂商 FlagOS 镜像启动容器
# ─────────────────────────────────────────────────────────────
# 用法：把 <...> 占位符替换成 <厂商>/ENV.md 里的真实值后执行。
# 三厂商差异（设备挂载参数）见下方 CASE 分支，取消对应注释即可。
set -euo pipefail

# ==== 需填写（见 <厂商>/ENV.md）====
VENDOR="<metax|hygon|iluvatar>"       # 厂商目录名
# FlagOS 发布镜像（xingchen4-0907 实测，以 <厂商>/ENV.md 为准）：
#   metax:    harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
#   hygon:    harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
#   iluvatar: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
IMAGE="<上面对应厂商的镜像:tag>"
CONTAINER_NAME="<模型名>_flagos"      # 与失败报告"容器"字段一致，如 Qwen2.5-7B-Instruct_flagos
MODEL_DIR_HOST="/public-flash/models" # 宿主机模型根目录，映射到容器 /models
WORKSPACE_HOST="<宿主机工作区目录>"    # 挂载评测脚本/结果，如 /data/flagos-workspace
# 宿主机（ssh 免密）：metax-57/58/59/60/108/109 · hygon-30/31/32/33 · iluvatar-117/211
# ===================================

# 设备挂载：按厂商取消对应注释
DEVICE_ARGS=""
# --- 沐曦 Metax C550 ---
# DEVICE_ARGS="--device=/dev/dri --device=/dev/mxcd --group-add video"
# --- 海光 Hygon DCU BW1000 ---
# DEVICE_ARGS="--device=/dev/kfd --device=/dev/dri --group-add video --security-opt seccomp=unconfined"
# --- 天数 Iluvatar BI-V150 ---
# DEVICE_ARGS="--device=/dev/iluvatar --device=/dev/mem"
# ⚠ 以上为常见形式，确切设备节点以厂商镜像文档为准，请在 ENV.md 记录实测值。

docker run -itd \
  --name "${CONTAINER_NAME}" \
  --network host \
  --ipc host \
  --shm-size 32g \
  ${DEVICE_ARGS} \
  -v "${MODEL_DIR_HOST}":/models \
  -v "${WORKSPACE_HOST}":/flagos-workspace \
  "${IMAGE}" \
  /bin/bash

echo "容器已启动：${CONTAINER_NAME}"
echo "进入容器：docker exec -it ${CONTAINER_NAME} bash"
echo "验证设备可见性（进容器后）："
echo "  Metax:    mx-smi"
echo "  Hygon:    hy-smi"
echo "  Iluvatar: ixsmi"
