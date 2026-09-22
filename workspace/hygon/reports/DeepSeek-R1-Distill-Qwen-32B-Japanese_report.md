# hygon/DeepSeek-R1-Distill-Qwen-32B-Japanese 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_DeepSeek-R1-Distill-Qwen-32B-Japanese_202608071433.md
- **原始失败类型**：精度或评测路径异常
- **日期**：2026-09-18；2026-09-20 追加复测
- **依据**：[原始适配记录](../fixes/DeepSeek-R1-Distill-Qwen-32B-Japanese.md)
- **评测脚本留档**：[file_fixes 完整快照](../fixes/file_fixes/DeepSeek-R1-Distill-Qwen-32B-Japanese.md)

## 现象

普通贪心仅 38%，5/50 道题重复输出；改用模型声明的 thinking 采样 temperature=0.6、top_p=0.95、max_tokens=16384，并关闭 OOT、prefix cache、chunked prefill 和 FlagGems attention。

## 定位

以上现象和归因均按原始适配记录；不能把评测后处理、服务数值路径和随机采样波动混作同一问题。

## 处置

普通贪心仅 38%，5/50 道题重复输出；改用模型声明的 thinking 采样 temperature=0.6、top_p=0.95、max_tokens=16384，并关闭 OOT、prefix cache、chunked prefill 和 FlagGems attention。

## 结果

- GPQA Diamond 本平台 / NV：66% / 62%。
- 恢复同一已通过服务配置并仅把评测并发从 2 调到 8 后，追加 50 题结果为 **72%（36/50）** / NV **62%**；本轮耗时 **7464.34s**（约 2h 04m），相对原 batch=2 的 24982.68s 加速 **3.35×**。两轮都达到 NV 相对退化不超过 5% 的门限。
- 达标判定：本轮 GPQA 精度达标；仅记录评测墙钟时间，不将其等同于标准化性能验收或其他指标通过。
- accuracy_compare 退出码：源适配记录未明确给出数值，本报告不推断。

### 2026-09-20 独立复测证据和边界

| 服务配置 / 评测并发 | GPQA 50题 | 耗时 | 结论 |
|------|---:|---:|------|
| eager、prefix cache 关、chunked prefill 关、TP4；batch=2 | 66% | 24982.68s | 相对 NV 62% 通过 |
| 编译/CUDA Graph、prefix cache 开、chunked prefill 关、TP4、显存比例 0.75；batch=2 | 54% | 3858.66s | 不通过；多个服务变量同时变化，不能单独归因 |
| **恢复第一行服务配置，仅 batch=8** | **72%** | **7464.34s** | **通过**；相对第一行加速 3.35× |

第三轮退出码 `0`；`runaway_count=0`；显式答案 50/50，fallback、parser mismatch、invalid extract 均为 0；EvalScope 与格式校正分同为 72%。评测使用 `temperature=0.6`、`top_p=0.95`、`max_tokens=16384`，属采样解码，66% 到 72% 的差异不能直接证明增大 batch 提高精度。两轮均跳过开测前截断探测；当前并非全量 198 题、NV 同参数逐题对照或性能发布验收。

```text
宿主机结果：/public-flash/models/day0_logs/accuracy/DeepSeek-R1-Distill-Qwen-32B-Japanese-gpqa50-best-batch8-20260920-04.json
同名日志/退出码：.log / .exit
服务日志：/public-flash/models/day0_logs/DeepSeek-R1-Distill-Qwen-32B-Japanese-serve-best-restored-batch8-20260920.log
EvalScope 工作目录：outputs/gpqa_diamond/20260920_102140
```

服务在复测后仍为第一行的旧最优配置；批量大小是评测客户端参数，不属于 vLLM 启动参数。下面“发布字段”的容器创建命令是参照原运行配置整理的示例，不是新建容器的实测命令；发布评分采用本轮 72%，须连同本轮结果路径一并引用。

## 提炼到 KNOWLEDGE 的条目

推理模型先核对生成配置和 runaway，再判精度。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: cyberagent/DeepSeek-R1-Distill-Qwen-32B-Japanese
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4
# GPU: Hygon DCU BW1000, 4 × 64GB
# TP: 4
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 62
# SCORE_FLAGOS: 72
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
  --name flagos-hygon-deepseek-r1-distill-qwen-32b-japanese \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4 \
  bash -lc 'sleep infinity'
```

### 三、启动服务（容器内执行）

```bash
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/models/DeepSeek-R1-Distill-Qwen-32B-Japanese}"
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
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
export FLAGGEMS_DB_URL=sqlite:///:memory:
export VLLM_FL_FLAGOS_WHITELIST=attention_backend
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_FL_OOT_ENABLED=0
export VLLM_FL_OOT_BLACKLIST=addmm,broadcast_to,copy
/usr/local/bin/vllm serve "$MODEL_DIR" \
  --served-model-name DeepSeek-R1-Distill-Qwen-32B-Japanese \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.90 \
  --port 8005 \
  --attention-backend TRITON_ATTN \
  --no-enable-prefix-caching \
  --no-enable-chunked-prefill \
  --enforce-eager \
  --trust-remote-code
```
