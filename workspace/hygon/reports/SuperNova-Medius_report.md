# hygon/SuperNova-Medius 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_SuperNova-Medius_202607261152.md
- **原始失败类型**：精度或评测路径异常
- **日期**：2026-09-16
- **依据**：[原始适配记录](../fixes/SuperNova-Medius.md)

## 现象

旧 27 算子白名单导致重复输出；改 native TRITON_ATTN 并关闭 OOT，guarded evaluator 上限 4096 token，局部重试异常索引。198 题两轮分数不一致，缺同口径 NV 198 题基线。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

旧 27 算子白名单导致重复输出；改 native TRITON_ATTN 并关闭 OOT，guarded evaluator 上限 4096 token，局部重试异常索引。198 题两轮分数不一致，缺同口径 NV 198 题基线。

## 结果

- GPQA Diamond 本平台 / NV：41.92 / 43.43% / 同口径全量基线缺失。
- 达标判定：精度尚未完成稳定验收，不得以本轮分数发布。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。
- 限定：198 题两轮波动且 NV 198 题基线缺失。

## 提炼到 KNOWLEDGE 的条目

评测 runaway 只重试异常索引，先备份并检查全量索引完整性。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: arcee-ai/SuperNova-Medius
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
# GPU: Hygon DCU BW1000, 2 × 64GB
# TP: 2
# VERDICT: pending
# METRIC: gpqa_diamond
# SCORE_ORIGIN: -
# SCORE_FLAGOS: -
# CONTAINER_DEVS: --security-opt seccomp=unconfined --device=/dev/kfd --device=/dev/dri --shm-size=64g --mount type=bind,src=/public-flash/models,dst=/models --mount type=bind,src=/opt/hyhal,dst=/opt/hyhal,readonly
```

### 二、容器创建（宿主机执行）

```bash
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/public-flash/models}"
HYHAL_ROOT="${HYHAL_ROOT:-/opt/hyhal}"
[[ -d "$MODEL_ROOT" ]] || { echo "ERROR: model root not found: $MODEL_ROOT" >&2; exit 1; }
[[ -d "$HYHAL_ROOT/lib" ]] || { echo "ERROR: Hygon driver library not found: $HYHAL_ROOT/lib" >&2; exit 1; }
[[ -d "$HYHAL_ROOT/lib/cmake/rocm_smi" ]] || echo "WARNING: rocm_smi CMake directory not found under $HYHAL_ROOT; verify the host driver version" >&2

docker run --init -d --net=host --ipc=host --security-opt seccomp=unconfined --security-opt label=disable --group-add video --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  --mount type=bind,src="$MODEL_ROOT",dst=/models \
  --mount type=bind,src="$HYHAL_ROOT",dst=/opt/hyhal,readonly \
  --name flagos-hygon-supernova-medius \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4 \
  bash -lc 'sleep infinity'
```

### 三、启动服务（容器内执行）

```bash
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/models/SuperNova-Medius}"
DTK_ENV="${DTK_ENV:-/opt/dtk/env.sh}"
if [[ ! -r "$DTK_ENV" ]]; then
  DTK_ENV="$(find /opt -maxdepth 4 -type f -path '*/dtk*/env.sh' -print -quit 2>/dev/null || true)"
fi
[[ -r "$DTK_ENV" ]] || { echo "ERROR: DTK env.sh not found; check the selected image" >&2; exit 1; }
source "$DTK_ENV"

if [[ -z "${TRITON_HIP_CLANG_PATH:-}" ]]; then
  if [[ -x /opt/dtk/aillvm/bin/clang-18 ]]; then
    TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18
  else
    TRITON_HIP_CLANG_PATH="$(find /opt -maxdepth 6 -type f -path '*/aillvm/bin/clang-18' -perm -111 -print -quit 2>/dev/null || true)"
  fi
fi
[[ -x "${TRITON_HIP_CLANG_PATH:-}" ]] || { echo "ERROR: clang-18 not found in the container" >&2; exit 1; }
export TRITON_HIP_CLANG_PATH
[[ -d "$MODEL_DIR" ]] || { echo "ERROR: model directory not found: $MODEL_DIR" >&2; exit 1; }
export GEMS_VENDOR=hygon
export VLLM_PLUGINS=fl
export USE_FLAGGEMS=1
export VLLM_FL_OOT_ENABLED=0
export VLLM_FL_FLAGOS_WHITELIST=attention_backend
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export VLLM_NO_USAGE_STATS=1
vllm serve "$MODEL_DIR" \
  --served-model-name SuperNova-Medius \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 80000 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --attention-backend TRITON_ATTN \
  --no-enable-chunked-prefill \
  --enable-prefix-caching \
  --enforce-eager \
  --trust-remote-code
```
