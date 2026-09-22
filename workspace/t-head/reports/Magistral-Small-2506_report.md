# t-head/Magistral-Small-2506 修复日志

- **失败报告**：历史报告参考 `flagrelease_fail_reports/Nvidia/FAILED_Nvidia_Magistral-Small-2506_202607301822.md`
- **原始失败类型**：精度不达标、reasoning 配置错配、长输出/runaway
- **日期**：2026-09-20

## 现象

- T-Head 初始 GPQA 50 题 `40.00%`，全量 198 题 `47.47%`；
- 多轮 Mistral 格式与采样消融集中在 `40.00%–48.00%`；
- README 推荐 `temperature=0.7`、`top_p=0.95`，但 `generation_config.json` 未携带这些字段；
- 原评测脚本没有将 `magistral` 识别为 thinking 模型；
- 8 题小样本在 `37.50%–87.50%` 波动，不能作为正式结论。

## 定位

- 主要问题不是服务不可用，而是评测模式与模型训练口径不一致；
- 贪心解码容易使 reasoning 模型锁定错误或重复路径；
- 缺少 reasoning prompt 时不能稳定触发推理—总结结构；
- `rms_norm`、`silu_and_mul`、`rotary_embedding` 的数值差异会在长链中累积；
- 输出窗口过小限制推理，过大又放大 runaway。

## 处置

1. 在 `fast_gpqa.py` 中增加 Magistral thinking 模型识别；
2. 固定 `temperature=0.7`、`top_p=0.95`；
3. 注入 reasoning system prompt；
4. 正式评测使用 `max_tokens=16384`、`eval_batch_size=2`；
5. 关闭 prefix cache 和 chunked prefill；
6. 核心三个算子避开 FlagGems，`attention_backend` 保留 FlagOS；
7. 使用 50 题正式结果而不是 8 题消融值判定。

| 项目 | 值 |
|------|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 模型路径 | `/models/Magistral-Small-2506` |
| GPU / 端口 / TP | `12,13` / `18088` / `2` |
| 服务参数 | bf16、`max_model_len=40960`、Mistral tokenizer/config/load format、关闭 prefix/chunked |
| 评测参数 | EvalScope `1.5.1`、50 题、0.7/0.95、16384 tokens、batch=2 |
| 结果文件 | `/models/_eval_results/20260920_magistral_fix/50_readme_prompt_16384/Magistral-Small-2506_gpqa_result.json` |
| 脚本备份 | `/models/_eval_scripts/release_gap_eval_20260917/flagrelease_eval_methods/fast_gpqa.py.bak_20260920_magistral_fix` |

## 结果

- 修复后 / NV：`68.00%`（34/50） / `62.00%`
- 绝对差：`+6` 个百分点
- 相对退化：`-9.68%`，实际提升
- 判定：✅ 通过
- 原始分 / 格式校正分：`68.00%` / `68.00%`
- 答案解析错判：`0`
- runaway：`3/50`，两题撞到 `max_tokens`

```json
{
  "score": 68.0,
  "evalscope_score": 68.0,
  "total_questions": 50,
  "temperature": 0.7,
  "max_tokens": 16384,
  "eval_batch_size": 2,
  "runaway_count": 3,
  "parser_mismatch_count": 0
}
```

限定说明：本次完成精度修复与验证，未重新进行完整性能验收；精度通过，但生成稳定性仍需继续优化。

## 提炼到 KNOWLEDGE 的条目

Reasoning 模型必须显式对齐模型卡采样参数和 prompt；配置文件缺字段不等于应使用贪心解码。长链任务还应消融核心算子、prefix/chunked 路径与窗口，并以至少 50 题加答案/runaway 审计作为结论。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: mistralai/Magistral-Small-2506
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# HARBOR_VER: V3
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 62.0
# SCORE_FLAGOS: 68.0
# HOST_PPU_SDK_ROOT_DEFAULT: /usr/local/PPU_SDK
# HOST_MODEL_ROOT_DEFAULT: /mnt/workspace/models
# CONTAINER_PPU_SDK_ROOT: /usr/local/PPU_SDK
# CONTAINER_MODEL_ROOT: /models
# CONTAINER_DEVS: --network host --ipc host --privileged --shm-size=512g -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models
```

### 二、推理容器创建（宿主机执行）

正式结果原始进程位于共享容器 `flagrelease_thead_model_dl_20260915`；另有 `flagrelease_thead_magistral_mistralfmt_20260917` 承载消融服务。下面使用独立复现容器名，避免覆盖共享容器。执行前必须确认 GPU12、13 和端口 `18088` 空闲。

```bash
set -euo pipefail

IMAGE="harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100"
CONTAINER="flagrelease_thead_magistral_small_2506_repro"
MODEL_DIR="Magistral-Small-2506"
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
docker exec -d flagrelease_thead_magistral_small_2506_repro bash -lc '
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/models}"
MODEL_PATH="${MODEL_PATH:-${MODEL_ROOT}/Magistral-Small-2506}"
CACHE_ROOT="${CACHE_ROOT:-${MODEL_ROOT}/_vllm_cache/magistral-nv8-gpu12-13}"
LOG_ROOT="${LOG_ROOT:-${MODEL_ROOT}/_serve_logs}"
PPU_SDK_ROOT="${PPU_SDK_ROOT:-/usr/local/PPU_SDK}"
TARGET_DEVICES="${TARGET_DEVICES:-12,13}"

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
export VLLM_FL_FLAGOS_WHITELIST=arange_start,argmax,exponential_,lt_scalar,rand_like,randn,softmax,softmax_out,where_self,where_self_out,attention_backend
export VLLM_FL_OOT_BLACKLIST=silu_and_mul,rms_norm,rotary_embedding
export VLLM_CACHE_ROOT="${CACHE_ROOT}"
export TORCHINDUCTOR_CACHE_DIR="${CACHE_ROOT}/torchinductor"
export TRITON_CACHE_DIR="${CACHE_ROOT}/triton"
export VLLM_FL_TRITON_CACHE_ROOT="${CACHE_ROOT}/triton"
export PPU_HOME="${PPU_SDK_ROOT}"
export CUDA_HOME="${PPU_SDK_ROOT}/CUDA_SDK"
export HF_ENDPOINT=https://hf-mirror.com

exec /usr/local/bin/vllm serve "${MODEL_PATH}" \
  --served-model-name Magistral-Small-2506 \
  --host 0.0.0.0 --port 18088 \
  --dtype bfloat16 --tensor-parallel-size 2 \
  --max-model-len 40960 --gpu-memory-utilization 0.90 \
  --trust-remote-code --enforce-eager \
  --tokenizer-mode mistral --config-format mistral --load-format mistral \
  --tool-call-parser mistral --enable-auto-tool-choice \
  --no-enable-prefix-caching --no-enable-chunked-prefill \
  > "${LOG_ROOT}/Magistral-Small-2506-repro-gpu12-13-port18088.log" 2>&1
'
```

`magistral-nv8-gpu12-13` 只是默认缓存命名空间。目标机无需预建；命令会创建所需子目录，也可通过 `CACHE_ROOT`、`LOG_ROOT`、`MODEL_PATH` 覆盖。

这些是容器内变量，需以 `docker exec -e CACHE_ROOT=/models/_vllm_cache/新运行名 -e TARGET_DEVICES=实际设备号 ...` 传入；宿主机变量不会自动透传。并行启动时还需另选空闲端口和独立日志名，避免占用现有服务资源。

### 四、启动后核验

```bash
curl -fsS http://127.0.0.1:18088/health
curl -fsS http://127.0.0.1:18088/v1/models
docker exec flagrelease_thead_magistral_small_2506_repro \
  bash -lc "pgrep -af '^/usr/local/bin/python3.12 /usr/local/bin/vllm serve /models/Magistral-Small-2506'; ppu-smi"
```

### 五、评测参数

```text
model: Magistral-Small-2506
api_base: http://127.0.0.1:18088/v1
dataset: gpqa_diamond
limit: 50
temperature: 0.7
top_p: 0.95
max_tokens: 16384
eval_batch_size: 2
```
