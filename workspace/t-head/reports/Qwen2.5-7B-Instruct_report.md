# t-head/Qwen2.5-7B-Instruct 修复日志

- **失败报告**：flagrelease_fail_reports/T-Head/FAILED_T-Head_Qwen2.5-7B-Instruct_202609090059.md
- **原始失败类型**：精度不达标
- **日期**：2026-09-17

## 现象

历史自动化流程（V1=none 分支，V2/V3 为同一镜像双 tag 发布）留下的失败证据：

- V2/V3 GPQA 精度 `34.0%`，NV 参考基线 `39.0%`，`rel_drop = 12.82%`，超过 5% 阈值；
- 历史报告明确记录：全量禁用 flaggems 仍为 `34.0%`，即该轮的平台天花板就是 `34.0%`；
- 同一轮性能比 `130.7%`（vs 合成基线）达标；
- 历史结论：仅私有发布（V2/V3 双 tag 已 push Harbor），未对外发布 ModelScope/HuggingFace，流程自动化结论为迁移失败。

本次在 PPU 机器上换统一 PPU 新镜像重跑后的现象：

- 服务健康检查 HTTP `200`，`/v1/models` 返回模型名 `Qwen2.5-7B-Instruct`，监听端口 `18083`，绑定 GPU1；
- 50 题 GPQA Diamond 完整跑完（评测耗时 `1513.43` 秒），未检测到截断；
- 结果 `38.0%`，NV 参考值 `39.0%`，相对退化 `2.56%`。

## 定位

- 本次重跑没有出现服务启动失败、算子 crash、OOM 或 plugin-FL 报错，`aligned=true`、`raw_aligned=true`、`noise_adjusted=false`；
- 源日志明确说明：本文件仅记录本次 50 题结果，不展开根因分析；本次未做算子级二分定位，也没有出现退化算子名；
- 历史失败属于精度不达标（而非服务/性能问题）：性能比 `130.7%` 达标，精度 `34.0%` 也不随 flaggems 开关变化，指向当时镜像/框架组合层面的平台天花板，而非单个替换算子。

## 处置

1. 换用统一 PPU 新镜像，在共享目录加载模型权重，不再复用历史自动化流程的旧镜像组合；
2. 长驻推理容器（PID 1 保持容器存活）内通过 `docker exec` 单卡启动 vLLM 服务；
3. 保留当前 FlagOS 算子白名单（含 `attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul`）；
4. 使用独立评测容器访问 OpenAI API 接口，固定 GPQA Diamond 50 题口径；
5. 结果同时落原始 EvalScope 分、答案提取审计、截断检测和 NV 对齐判定。

本次实际运行配置：

| 项目 | 值 |
|------|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| 模型路径 | `/models/Qwen2.5-7B-Instruct` |
| GPU / 端口 / TP | `CUDA_VISIBLE_DEVICES=1` / `18083` / `1` |
| 服务参数 | `--dtype bfloat16 --max-model-len 32768 --gpu-memory-utilization 0.85 --trust-remote-code --enforce-eager` |
| 评测参数 | EvalScope `1.5.1`，50 题，`eval_batch_size=4`，`max_model_len=32768`，`max_tokens=24576` |
| 服务日志 | `/models/_serve_logs/Qwen2.5-7B-Instruct-20260916-gpu1.log` |
| 结果文件 | `/mnt/workspace/models/_eval_results/20260916_new_models/50/Qwen2.5-7B-Instruct/Qwen2.5-7B-Instruct_gpqa_result.json` |

镜像未重新构建、重新打 tag 或 push；容器可写层变化仅为安装 `modelscope==1.40.0`、`modelscope-hub==0.4.2` 及 ModelScope/pip/vLLM model-info 缓存、FlagGems/Triton 运行时临时文件；未修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL`、`/workspace/FlagGems` 的源码和算子实现。

## 结果

- 修复后分 / NV 基线：`38.0%`（19/50） / `39.0%`
- 达标判定（accuracy_compare 退出码）：通过（`aligned=true`）；源日志只给出 verdict.json，未记录 accuracy_compare 的退出码数值，退出码为 `<待补>`

verdict.json 原文：

```json
{
  "score": 38.0,
  "evalscope_score": 38.0,
  "total_questions": 50,
  "truncation_detected": false,
  "answer_extraction_audit": {
    "checked": 50,
    "format_corrected_score": 38.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 1
  },
  "verdict": {
    "aligned": true,
    "raw_aligned": true,
    "noise_adjusted": false,
    "nv_score": 39.0,
    "current_score": 38.0,
    "rel_drop": 0.0256,
    "threshold": 0.05
  }
}
```

限定说明（照抄源日志的本次处理结论）：当前 PPU 机器上的新镜像服务正常，50 题 GPQA 精度通过；本文件仅记录本次 50 题结果，不展开根因分析。本次性能验收未重测，完整 V1–V3 流程对比本次未覆盖，因此不能据此宣称 V1–V3 全部通过。

## 提炼到 KNOWLEDGE 的条目

50 题 GPQA 记录必须同时保存原始 EvalScope 分数、答案提取审计结果、截断检测结果和 NV 对齐判定；模型服务若使用独立 GPU 与独立缓存目录（`VLLM_CACHE_ROOT` / TorchInductor / Triton），必须在记录中固定写清，便于复现实验环境。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Qwen/Qwen2.5-7B-Instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# HARBOR_VER: V3
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 39.0
# SCORE_FLAGOS: 38.0
# HOST_PPU_SDK_ROOT_DEFAULT: /usr/local/PPU_SDK
# HOST_MODEL_ROOT_DEFAULT: /mnt/workspace/models
# CONTAINER_PPU_SDK_ROOT: /usr/local/PPU_SDK
# CONTAINER_MODEL_ROOT: /models
# CONTAINER_DEVS: --network host --ipc host --privileged --shm-size=512g -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models
```

### 二、推理容器创建（宿主机执行）

原始服务运行在共享容器 `flagrelease_thead_model_dl_20260915`。以下使用独立复现容器名；执行前确认 GPU1 和端口 `18083` 空闲。

```bash
set -euo pipefail

IMAGE="harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100"
CONTAINER="flagrelease_thead_qwen25_7b_instruct_repro"
MODEL_DIR="Qwen2.5-7B-Instruct"
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
docker exec -d flagrelease_thead_qwen25_7b_instruct_repro bash -lc '
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/models}"
MODEL_PATH="${MODEL_PATH:-${MODEL_ROOT}/Qwen2.5-7B-Instruct}"
CACHE_ROOT="${CACHE_ROOT:-${MODEL_ROOT}/_vllm_cache/qwen2.5-7b-gpu1}"
LOG_ROOT="${LOG_ROOT:-${MODEL_ROOT}/_serve_logs}"
PPU_SDK_ROOT="${PPU_SDK_ROOT:-/usr/local/PPU_SDK}"
TARGET_DEVICES="${TARGET_DEVICES:-1}"

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

export VLLM_FL_FLAGOS_WHITELIST=lift_fresh,empty,zero_,zeros,arange_start,true_divide,pow_scalar,reciprocal,mul,unsqueeze,cos,sin,cat,to_copy,ones,fill_scalar_,narrow,copy_,randn,addmm_out,broadcast_to,mm_out,index,rand_like,linear,alias,full,argmax,lt_scalar,scalar_tensor,where_self,where_self_out,true_divide_,softmax,softmax_out,exponential_,unbind,add,sub,expand,eq_scalar,masked_fill_,ones_like,scatter_add_0,gt_scalar,repeat,bitwise_or_tensor,mul_,sub_,sort,sort_stable,cumsum,rsub_scalar,gather,lt,cumsum_out,le,scatter_,attention_backend,rms_norm,silu_and_mul,rotary_embedding

export VLLM_CACHE_ROOT="${CACHE_ROOT}"
export TORCHINDUCTOR_CACHE_DIR="${CACHE_ROOT}/torchinductor"
export TRITON_CACHE_DIR="${CACHE_ROOT}/triton"
export VLLM_FL_TRITON_CACHE_ROOT="${CACHE_ROOT}/triton"

export PPU_HOME="${PPU_SDK_ROOT}"
export CUDA_HOME="${PPU_SDK_ROOT}/CUDA_SDK"
export HF_ENDPOINT=https://hf-mirror.com

exec /usr/local/bin/vllm serve "${MODEL_PATH}" \
  --served-model-name Qwen2.5-7B-Instruct \
  --host 0.0.0.0 \
  --port 18083 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager \
  > "${LOG_ROOT}/Qwen2.5-7B-Instruct-repro-gpu1-port18083.log" 2>&1
'
```

`qwen2.5-7b-gpu1` 只是默认缓存命名空间；命令会创建它，换卡或换机器时可覆盖 `CACHE_ROOT` 与 `TARGET_DEVICES`。

容器内覆盖变量需以 `docker exec -e CACHE_ROOT=/models/_vllm_cache/新运行名 -e TARGET_DEVICES=实际设备号 ...` 传入；宿主机变量不自动透传。并行启动还需另选空闲端口和独立日志名。

### 四、启动后核验

```bash
curl -fsS http://127.0.0.1:18083/health
curl -fsS http://127.0.0.1:18083/v1/models
docker exec flagrelease_thead_qwen25_7b_instruct_repro \
  bash -lc "pgrep -af '^/usr/local/bin/python3.12 /usr/local/bin/vllm serve /models/Qwen2.5-7B-Instruct'; ppu-smi"
```
