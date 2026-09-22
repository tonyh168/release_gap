# t-head/Phi-4 修复日志

- **失败报告**：本次评测未对应独立失败报告
- **原始问题类型**：GPQA 精度适配
- **评测日期**：`2026-09-20`（本文件只对应当日 `16:20:11` 开始的 50 题评测）
- **依据**：[本次适配与评测记录](../fixes/Phi-4.md)；[运行文件说明](../fixes/file_fixes/Phi-4.md)

## 现象

Phi-4 在 PPU-ZW810E 上运行 GPQA Diamond 50 题，结果 `70.0%（35/50）`；EvalScope 原始分与答案审计分均为 `70.0%`，50 题均有显式答案，解析错判 `0`、runaway `0`。

## 定位

本次推理通过 vllm-plugin-FL 注册，FlagOS 和 OOT 均对 `rms_norm,silu_and_mul` 设黑名单；`VLLM_FL_USE_FLAGGEMS_ATTN=0`。日志确认 `attention_backend`、`rotary_embedding` 选择 `default.flagos`，`rms_norm` 的 IR 优先级为 native。无证据将该轮得分归因于 Phi-4 专属源码修改或答案后处理校分。

## 处置

在推理容器 `flagrelease_thead_model_dl_20260915` 以 `bfloat16`、TP1、`max_model_len=16384`、`--enforce-eager` 启动 `/models/phi-4`（端口 `18084`）；评测容器 `flagrelease_thead_eval_20260915` 使用 EvalScope `1.5.1`、0-shot、50 题、batch 4、`temperature=0`、`top_p=1`、`max_tokens=8192` 完成真实评测并保存原始输出。

## 结果

| 项目 | 本次记录 |
|------|----------|
| GPQA Diamond | `70.0%（35/50）` |
| EvalScope 原始分 / 审计分 | `70.0%` / `70.0%` |
| NV 参考值 | `73.0%`（[项目基线](../../../flagrelease_eval_methods/nv_baseline.yaml)） |
| 相对退化 | `(73-70)/73 = 4.11%` |
| 判定 | 该次 50 题单轮精度数值满足 5% 相对容差；不代表稳定性或性能验收 |
| 答案审计 | 50/50 显式答案，parser mismatch `0`，runaway `0` |
| 截断检查 | `--skip-truncation-check`，未执行截断探测 |
| 评测耗时 | `1208.3` 秒 |
| 结果文件 | `/mnt/workspace/models/_eval_results/20260920_phi_blacklist_rms_silu_oot_50_b4_result.json` |
| 原始评测目录 | `/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260920_162011` |

`accuracy_compare.py` 的本轮退出码没有留存，此处判定来自结果文件与 NV 表的数值计算。

## 提炼到 KNOWLEDGE 的条目

单次 GPQA 结果必须与其服务命令、设备可见性、算子路由、EvalScope 的 `task_config.yaml` 和逐题输出绑定记录；`VLLM_FL_USE_FLAGGEMS_ATTN=0` 不等同于 attention 全部走 native；评测后的脚本更新不能追认为该轮的精度修复。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/phi-4
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: ok
# VERDICT_SCOPE: 2026-09-20 GPQA Diamond 50-question single run only
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 73
# SCORE_FLAGOS: 70
# HOST_PPU_SDK_ROOT_DEFAULT: /usr/local/PPU_SDK
# HOST_MODEL_ROOT_DEFAULT: /mnt/workspace/models
# CONTAINER_PPU_SDK_ROOT: /usr/local/PPU_SDK
# CONTAINER_MODEL_ROOT: /models
# CONTAINER_DEVS: --network host --ipc host --privileged --shm-size=512g -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models
```

### 二、推理容器创建（宿主机执行）

本次实际使用已存在的共享长驻容器 `flagrelease_thead_model_dl_20260915`。该容器的镜像入口为 `/opt/t-head/entrypoint.sh`，CMD 为 `sleep infinity`；以下是等价创建命令，容器已存在时不要重复执行：

```bash
set -euo pipefail

IMAGE="harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100"
CONTAINER="flagrelease_thead_model_dl_20260915"
MODEL_DIR="phi-4"
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

`HOST_PPU_SDK_ROOT` 和 `HOST_MODEL_ROOT` 是宿主机变量；其他平头哥机器目录不同时，在执行前覆盖即可。容器内 `/usr/local/PPU_SDK` 与 `/models` 保持为本项目统一接口，因此服务命令不依赖宿主机实际存储路径。

实际 `docker inspect` 结果：

```text
container: flagrelease_thead_model_dl_20260915
image_id: sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce
network: host
ipc: host
privileged: true
shm-size: 512 GiB
mounts: /dev:/dev, /usr/local/PPU_SDK:/usr/local/PPU_SDK, /mnt/workspace/models:/models
```

评测容器 `flagrelease_thead_eval_20260915` 只绑定 `/mnt/workspace/models:/models`，且 `privileged=false`、不挂载 `/dev` 和 `/usr/local/PPU_SDK`；它只访问 OpenAI API 并保存评测产物。

### 三、启动服务（按 2026-09-20 配置整理的可移植命令；不代表当前在线配置）

历史实际启动命令（包括当时未显式设置 XPU 设备号）原文保留在 [适配记录](../fixes/Phi-4.md)；以下是面向其他平头哥机器的规范化复现命令，已经加入路径检查、自动建目录、统一设备可见性。已有服务或端口占用时不要直接重放：

```bash
docker exec -d flagrelease_thead_model_dl_20260915 bash -lc '
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/models}"
MODEL_PATH="${MODEL_PATH:-${MODEL_ROOT}/phi-4}"
CACHE_ROOT="${CACHE_ROOT:-${MODEL_ROOT}/_vllm_cache/phi4-blacklist-rms-silu-oot-20260920b}"
LOG_ROOT="${LOG_ROOT:-${MODEL_ROOT}/_serve_logs}"
TARGET_DEVICES="${TARGET_DEVICES:-11}"

test -f "${MODEL_PATH}/config.json"
mkdir -p "${CACHE_ROOT}" "${LOG_ROOT}"
test -w "${CACHE_ROOT}"
test -w "${LOG_ROOT}"

unset VLLM_FL_FLAGOS_WHITELIST VLLM_FL_OOT_WHITELIST VLLM_FL_OOT_ENABLED
export XPU_VISIBLE_DEVICES="${TARGET_DEVICES}"
export CUDA_VISIBLE_DEVICES="${TARGET_DEVICES}"
export HIP_VISIBLE_DEVICES="${TARGET_DEVICES}"
export VLLM_PLUGINS=fl USE_FLAGGEMS=1 VLLM_FL_PREFER_ENABLED=true
export VLLM_FL_FLAGOS_BLACKLIST=rms_norm,silu_and_mul
export VLLM_FL_OOT_BLACKLIST=rms_norm,silu_and_mul
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_TRITON_CACHE_ROOT="${CACHE_ROOT}"
export VLLM_CACHE_ROOT="${CACHE_ROOT}"
export FLAGGEMS_DB_URL=sqlite:///:memory:
exec /usr/local/bin/vllm serve "${MODEL_PATH}" \
  --served-model-name phi-4 --host 0.0.0.0 --port 18084 \
  --dtype bfloat16 --tensor-parallel-size 1 \
  --max-model-len 16384 --gpu-memory-utilization 0.85 \
  --trust-remote-code --enforce-eager \
  > "${LOG_ROOT}/phi-4-blacklist-rms-silu-oot-20260920b.log" 2>&1
'
```

`phi4-blacklist-rms-silu-oot-20260920b` 是本轮缓存命名空间，不是平台固定目录。命令会在挂载卷内创建它；如需换目录，可通过 `CACHE_ROOT` 覆盖。历史启动未显式设置 `XPU_VISIBLE_DEVICES`，推理容器该变量为 `all`；规范化命令将三套设备变量统一固定到 `TARGET_DEVICES=11`。`VLLM_FL_OOT_ENABLED` 被 unset，插件默认启用 OOT；不要将其误写为关闭 OOT。

容器内的覆盖变量应通过 `docker exec -e CACHE_ROOT=/models/_vllm_cache/另一个运行名 -e TARGET_DEVICES=实际设备号 ...` 传入，宿主机的 `HOST_MODEL_ROOT` 不会自动透传到容器。每次并行复现应使用**不同的缓存目录、日志文件名和空闲端口**，避免与在线服务共享可写缓存；本文仍使用原始端口，仅为记录当次参数，不能直接在原机并行启动。

### 四、启动后核验

```bash
curl -fsS http://127.0.0.1:18084/health
curl -fsS http://127.0.0.1:18084/v1/models
docker exec flagrelease_thead_model_dl_20260915 \
  bash -lc "pgrep -af '^/usr/local/bin/python3.12 /usr/local/bin/vllm serve /models/phi-4'; ppu-smi"
```

### 五、评测命令与参数

以下命令用于重新评测，使用新建目录保存结果，**不会覆盖原始 70% 结果**：

```bash
docker exec -d flagrelease_thead_eval_20260915 bash -lc '
set -euo pipefail
MODEL_ROOT="${MODEL_ROOT:-/models}"
EVAL_ROOT="${EVAL_ROOT:-${MODEL_ROOT}/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods}"
RESULT_BASE="${RESULT_BASE:-${MODEL_ROOT}/_eval_results}"
test -f "${EVAL_ROOT}/fast_gpqa.py"
mkdir -p "${RESULT_BASE}"
test -w "${RESULT_BASE}"
RUN_DIR="$(mktemp -d "${RESULT_BASE}/phi4-repro-XXXXXXXX")"
cd "${EVAL_ROOT}"
python3 fast_gpqa.py \
  --api-base http://127.0.0.1:18084/v1 \
  --model-name phi-4 --config fast_gpqa_config.yaml \
  --limit 50 --eval-batch-size 4 --max-tokens 8192 \
  --skip-truncation-check \
  --output "${RUN_DIR}/phi-4_gpqa_result.json" \
  > "${RUN_DIR}/eval.log" 2>&1
'
```

原始配置快照：`/mnt/workspace/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/outputs/gpqa_diamond/20260920_162011/configs/task_config.yaml`；其中 `temperature=0.0`、`top_p=1.0`、`seed=42`、0-shot、50 题。服务日志：`/mnt/workspace/models/_serve_logs/phi-4-blacklist-rms-silu-oot-20260920b.log`。
