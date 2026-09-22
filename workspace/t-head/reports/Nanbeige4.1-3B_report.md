# t-head/Nanbeige4.1-3B 修复日志

- **失败报告**：flagrelease_fail_reports/T-Head/FAILED_T-Head_Nanbeige4.1-3B_202608221700.md
- **原始失败类型**：精度或评测路径异常
- **日期**：2026-09-18
- **依据**：[原始适配记录](../fixes/Nanbeige4.1-3B.md)

## 现象

旧两轮仅 76%；修复行级结论抽取并避免从推理正文猜字母后，重新生成 50 题，校正分 80%、原始分 74%。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

旧两轮仅 76%；修复行级结论抽取并避免从推理正文猜字母后，重新生成 50 题，校正分 80%、原始分 74%。

## 结果

- GPQA Diamond 本平台 / NV：80% / 81%。
- 达标判定：本轮 GPQA 精度达标；性能或其他指标未由该记录证明。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。

## 提炼到 KNOWLEDGE 的条目

答案抽取修复后必须重新生成预测并保留逐题审计。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: nanbeige/Nanbeige4.1-3B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 81
# SCORE_FLAGOS: 80
# HOST_PPU_SDK_ROOT_DEFAULT: /usr/local/PPU_SDK
# HOST_MODEL_ROOT_DEFAULT: /mnt/workspace/models
# CONTAINER_PPU_SDK_ROOT: /usr/local/PPU_SDK
# CONTAINER_MODEL_ROOT: /models
# CONTAINER_DEVS: --network host --ipc host --privileged --shm-size=512g -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models
```

### 二、推理容器创建（宿主机执行）

原始服务容器为 `flagrelease_thead_nanbeige4p1_3b_20260917`。以下使用独立复现名称；执行前确认 GPU14 和端口 `18087` 空闲。

```bash
set -euo pipefail

IMAGE="harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100"
CONTAINER="flagrelease_thead_nanbeige4p1_3b_repro"
MODEL_DIR="Nanbeige4.1-3B"
HOST_PPU_SDK_ROOT="${HOST_PPU_SDK_ROOT:-/usr/local/PPU_SDK}"
HOST_MODEL_ROOT="${HOST_MODEL_ROOT:-/mnt/workspace/models}"

test -d /dev
test -d "$HOST_PPU_SDK_ROOT"
test -d "$HOST_MODEL_ROOT/$MODEL_DIR"
test -f "$HOST_MODEL_ROOT/$MODEL_DIR/config.json"
mkdir -p "$HOST_MODEL_ROOT/_vllm_cache" "$HOST_MODEL_ROOT/_serve_logs"
test -w "$HOST_MODEL_ROOT/_vllm_cache"
test -w "$HOST_MODEL_ROOT/_serve_logs"

docker run -d \
  --name "$CONTAINER" \
  --network host \
  --ipc host \
  --privileged \
  --shm-size=512g \
  -v /dev:/dev \
  -v "$HOST_PPU_SDK_ROOT:/usr/local/PPU_SDK" \
  -v "$HOST_MODEL_ROOT:/models" \
  "$IMAGE" \
  sleep infinity
```

宿主机路径可通过 `HOST_PPU_SDK_ROOT`、`HOST_MODEL_ROOT` 覆盖；容器内统一使用 `/usr/local/PPU_SDK`、`/models`。

### 三、启动服务（宿主机执行）

```bash
docker exec -d flagrelease_thead_nanbeige4p1_3b_repro bash -lc '
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/models}"
MODEL_PATH="${MODEL_PATH:-${MODEL_ROOT}/Nanbeige4.1-3B}"
CACHE_ROOT="${CACHE_ROOT:-${MODEL_ROOT}/_vllm_cache/nanbeige4p1-3b-min4-gpu14}"
LOG_ROOT="${LOG_ROOT:-${MODEL_ROOT}/_serve_logs}"
PPU_SDK_ROOT="${PPU_SDK_ROOT:-/usr/local/PPU_SDK}"
TARGET_DEVICES="${TARGET_DEVICES:-14}"

test -f "${MODEL_PATH}/config.json"
test -d "${PPU_SDK_ROOT}/CUDA_SDK"
mkdir -p "${CACHE_ROOT}/torchinductor" "${CACHE_ROOT}/triton" "${LOG_ROOT}"
test -w "${CACHE_ROOT}"
test -w "${LOG_ROOT}"

export XPU_VISIBLE_DEVICES="${TARGET_DEVICES}"
export CUDA_VISIBLE_DEVICES="${TARGET_DEVICES}"
export HIP_VISIBLE_DEVICES="${TARGET_DEVICES}"
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_PREFER_ENABLED=true
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=attention_backend,rms_norm,silu_and_mul,rotary_embedding
export VLLM_CACHE_ROOT="${CACHE_ROOT}"
export TORCHINDUCTOR_CACHE_DIR="${CACHE_ROOT}/torchinductor"
export TRITON_CACHE_DIR="${CACHE_ROOT}/triton"
export VLLM_FL_TRITON_CACHE_ROOT="${CACHE_ROOT}/triton"
export PPU_HOME="${PPU_SDK_ROOT}"
export CUDA_HOME="${PPU_SDK_ROOT}/CUDA_SDK"
export HF_ENDPOINT=https://hf-mirror.com

exec /usr/local/bin/vllm serve "${MODEL_PATH}" \
  --served-model-name Nanbeige4.1-3B \
  --host 0.0.0.0 \
  --port 18087 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager \
  > "${LOG_ROOT}/Nanbeige4.1-3B-repro-min4-gpu14-port18087.log" 2>&1
'
```

`nanbeige4p1-3b-min4-gpu14` 是默认缓存命名空间，不要求目标机预先存在；命令会创建它，也允许通过 `CACHE_ROOT` 覆盖。

容器内覆盖变量需以 `docker exec -e CACHE_ROOT=/models/_vllm_cache/新运行名 -e TARGET_DEVICES=实际设备号 ...` 传入；宿主机变量不自动透传。并行启动还需另选空闲端口和独立日志名。

### 四、启动后核验

```bash
curl -fsS http://127.0.0.1:18087/health
curl -fsS http://127.0.0.1:18087/v1/models
docker exec flagrelease_thead_nanbeige4p1_3b_repro \
  bash -lc "pgrep -af '^/usr/local/bin/python3.12 /usr/local/bin/vllm serve /models/Nanbeige4.1-3B'; ppu-smi"
```
