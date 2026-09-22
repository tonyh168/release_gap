# t-head/Ministral-8B-Instruct-2410 修复日志

- **失败报告**：flagrelease_fail_reports/T-Head/FAILED_T-Head_Ministral-8B-Instruct-2410_202609090702.md
- **原始失败类型**：按人工裁定标记为迁移失败（精度在小样本容忍范围内，主要遗留性能验收问题）
- **日期**：2026-09-16

## 现象

历史 T-Head 自动化报告（vLLM 0.24.0 / plugin-FL 0.3.0 的另一套自动化运行环境）留下的失败证据：

- V2 GPQA `26.0%`，相对 NV 参考值 `30.0%` 差 2 题，精度按小样本规则达标；
- 性能比 `91.8%`（vs 合成基线），步骤 7 禁用 OOT `silu_and_mul` 后优化到 `99.6%`，V3 沿用 V2 优化后结果；
- 整体流程仍因性能验收被标记为失败（按人工裁定标记迁移失败）。

本次在新镜像上重跑后的现象：

- 服务正常启动，健康检查 HTTP `200`，`/v1/models` 返回模型名 `Ministral-8B-Instruct-2410`，监听端口 `18081`，绑定 GPU3；
- 50 题 GPQA Diamond 完整结束（评测耗时 `1593.69` 秒），未检测到截断；
- 当前得分比 NV 记录值低 2 个百分点，即 50 题只差 1 题；
- 按单纯相对退化计算为 `6.67%`，超过 5% 阈值。

## 定位

- 本次没有发现服务崩溃、算子 crash、OOM、输出截断或答案解析错位（`parser_mismatch_count=0`）；
- 精度偏差属于 50 题小样本的随机抖动范围：绝对差 1 题，命中项目小样本噪声容忍规则，因此 verdict 里 `raw_aligned=false`、`noise_adjusted=true`、`aligned=true`；
- **本次“通过”依赖项目规定的小样本容忍规则，不是严格相对退化 ≤5% 的通过**，汇报时不能简写成“严格 5% 相对退化达标”；
- 本次未重跑完整性能验收，历史遗留的性能验收问题（V2 91.8% → 禁用 OOT `silu_and_mul` 后 99.6%）本次未复现验证。

## 处置

1. 使用统一 PPU 镜像重新启动模型，在共享目录加载权重；
2. 使用 GPU3、端口 `18081`、TP=1，保留当前 FlagOS 算子白名单（`attention_backend`、`rms_norm`、`rotary_embedding`、`silu_and_mul` 等路径由 FlagOS 接管）；
3. 使用独立评测容器，固定 GPQA Diamond 50 题；
4. 对原始分数执行答案提取审计和小样本噪声判定，同时记录 `current_score`、NV 分数、相对退化与绝对差题数；
5. 逐条保留源日志的结论限定，不把本轮 50 题结果外推为完整 V1–V3 通过。

本次实际运行配置：

| 项目 | 值 |
|------|---|
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100` |
| 镜像 ID | `sha256:a54dcb164e0d9aad003884e6b0691400f6c8db1e56d513b03dc1c65d30f830ce` |
| vLLM / PyTorch | `vllm 0.24.0+empty` / `torch 2.10.0` |
| 模型路径 | `/models/Ministral-8B-Instruct-2410` |
| GPU / 端口 / TP | `CUDA_VISIBLE_DEVICES=3` / `18081` / `1` |
| 服务参数 | `--dtype bfloat16 --max-model-len 32768 --gpu-memory-utilization 0.85 --trust-remote-code --enforce-eager` |
| 评测参数 | EvalScope `1.5.1`，50 题，`eval_batch_size=4`，`max_model_len=32768`，`max_tokens=24576` |
| 服务日志 | `/models/_serve_logs/Ministral-8B-Instruct-2410-20260915_155906.log` |
| 结果文件 | `/mnt/workspace/models/_eval_results/20260915_accuracy/formal_20260915_164849/Ministral-8B-Instruct-2410/Ministral-8B-Instruct-2410_gpqa_result.json` |

镜像未重新构建、重新打 tag 或 push；容器可写层变化仅为安装 `modelscope==1.40.0`、`modelscope-hub==0.4.2`、产生 ModelScope/pip/vLLM model-info 缓存与 FlagGems/Triton 运行时临时文件；未修改 `/workspace/vllm`、`/workspace/vllm-plugin-FL`、`/workspace/FlagGems` 中的算子实现。容器基础环境中 `XPU_VISIBLE_DEVICES=all`，本次服务通过 `CUDA_VISIBLE_DEVICES=3` 绑定实际计算设备。

## 结果

- 修复后分 / NV 基线：`28.0%`（14/50） / `30.0%`
- 达标判定（accuracy_compare 退出码）：通过，但属**小样本噪声容忍通过**——原始相对退化 `6.67%` 超过 5% 阈值（`raw_aligned=false`），因 50 题绝对差仅 1 题命中项目容忍规则（`noise_adjusted=true`）才判 `aligned=true`；源日志只给出 verdict.json，未记录 accuracy_compare 的退出码数值，退出码为 `<待补>`

verdict.json 原文：

```json
{
  "score": 28.0,
  "evalscope_score": 28.0,
  "total_questions": 50,
  "truncation_detected": false,
  "answer_extraction_audit": {
    "checked": 50,
    "format_corrected_score": 28.0,
    "parser_mismatch_count": 0,
    "invalid_evalscope_extract_count": 3
  },
  "verdict": {
    "aligned": true,
    "raw_aligned": false,
    "noise_adjusted": true,
    "nv_score": 30.0,
    "current_score": 28.0,
    "rel_drop": 0.0667,
    "diff_questions": 1.0,
    "threshold": 0.05
  }
}
```

限定说明（照抄源日志的本次处理结论）：当前 PPU 机器上的新镜像服务正常，50 题 GPQA 精度按项目小样本规则通过；性能和完整 V1–V3 对比本次未重测。本次完整性能验收未重测，不能据此宣称 V1–V3 全部通过。

## 提炼到 KNOWLEDGE 的条目

50 题 GPQA 的结果必须同时记录 `current_score`、NV 分数、相对退化和绝对差题数；Ministral 本次属于“原始相对退化超 5%，但按绝对差 1 题容忍通过”，后续汇报时不能简写成“严格 5% 相对退化达标”。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: mistralai/Ministral-8B-Instruct-2410
# IMAGE: harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100
# HARBOR_VER: V3
# GPU: PPU-ZW810E, 16 × 96GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 30.0
# SCORE_FLAGOS: 28.0
# HOST_PPU_SDK_ROOT_DEFAULT: /usr/local/PPU_SDK
# HOST_MODEL_ROOT_DEFAULT: /mnt/workspace/models
# CONTAINER_PPU_SDK_ROOT: /usr/local/PPU_SDK
# CONTAINER_MODEL_ROOT: /models
# CONTAINER_DEVS: --network host --ipc host --privileged --shm-size=512g -v /dev:/dev -v /usr/local/PPU_SDK:/usr/local/PPU_SDK -v /mnt/workspace/models:/models
```

### 二、推理容器创建（宿主机执行）

原始服务运行在共享容器 `flagrelease_thead_model_dl_20260915`。以下使用模型独占名称，避免不同报告都创建 `flagos`。执行前确认 GPU3 和端口 `18081` 空闲。

```bash
set -euo pipefail

IMAGE="harbor.baai.ac.cn/flagrelease-public/qwen3.8-27b-pp001-gems0.0-treenone-cxnone-plugin0.2.0-vllm0.24.0-cp312-pt210-hggc130-x64-1.3.2-d7f5a2:202608141100"
CONTAINER="flagrelease_thead_ministral_8b_instruct_2410_repro"
MODEL_DIR="Ministral-8B-Instruct-2410"
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
docker exec -d flagrelease_thead_ministral_8b_instruct_2410_repro bash -lc '
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/models}"
MODEL_PATH="${MODEL_PATH:-${MODEL_ROOT}/Ministral-8B-Instruct-2410}"
CACHE_ROOT="${CACHE_ROOT:-${MODEL_ROOT}/_vllm_cache/ministral-8b-instruct-2410-gpu3}"
LOG_ROOT="${LOG_ROOT:-${MODEL_ROOT}/_serve_logs}"
PPU_SDK_ROOT="${PPU_SDK_ROOT:-/usr/local/PPU_SDK}"
TARGET_DEVICES="${TARGET_DEVICES:-3}"

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
export VLLM_FL_FLAGOS_WHITELIST=lift_fresh,empty,zero_,zeros,arange_start,true_divide,pow_scalar,reciprocal,mul,unsqueeze,cos,sin,cat,to_copy,ones,narrow,fill_scalar_,mm_out,index,rand_like,linear,alias,full,argmax,lt_scalar,scalar_tensor,where_self,where_self_out,true_divide_,softmax,softmax_out,exponential_,unbind,add,copy_,sub,expand,scatter_,attention_backend,rms_norm,silu_and_mul,rotary_embedding
export VLLM_FL_OOT_BLACKLIST=silu_and_mul
export VLLM_CACHE_ROOT="${CACHE_ROOT}"
export TORCHINDUCTOR_CACHE_DIR="${CACHE_ROOT}/torchinductor"
export TRITON_CACHE_DIR="${CACHE_ROOT}/triton"
export VLLM_FL_TRITON_CACHE_ROOT="${CACHE_ROOT}/triton"
export PPU_HOME="${PPU_SDK_ROOT}"
export CUDA_HOME="${PPU_SDK_ROOT}/CUDA_SDK"
export HF_ENDPOINT=https://hf-mirror.com

exec /usr/local/bin/vllm serve "${MODEL_PATH}" \
  --served-model-name Ministral-8B-Instruct-2410 \
  --host 0.0.0.0 \
  --port 18081 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --trust-remote-code \
  --enforce-eager \
  > "${LOG_ROOT}/Ministral-8B-Instruct-2410-repro-gpu3-port18081.log" 2>&1
'
```

历史进程继承共享容器的 `XPU_VISIBLE_DEVICES=all`，以上规范化命令将 XPU/CUDA/HIP 三套变量都显式固定到 `TARGET_DEVICES`，避免新进程选到其他卡。此处显式缓存目录是可移植复现配置，**不是历史进程的原始缓存路径**；目标机无需预建，可覆盖 `CACHE_ROOT`。

容器内覆盖变量需以 `docker exec -e CACHE_ROOT=/models/_vllm_cache/新运行名 -e TARGET_DEVICES=实际设备号 ...` 传入；宿主机变量不自动透传。并行启动还需另选空闲端口和独立日志名。

### 四、启动后核验

```bash
curl -fsS http://127.0.0.1:18081/health
curl -fsS http://127.0.0.1:18081/v1/models
docker exec flagrelease_thead_ministral_8b_instruct_2410_repro \
  bash -lc "pgrep -af '^/usr/local/bin/python3.12 /usr/local/bin/vllm serve /models/Ministral-8B-Instruct-2410'; ppu-smi"
```
