# hygon/Phi-3-mini-128k-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Hygon/FAILED_Hygon_Phi-3-mini-128k-instruct_202607150538.md（文件确实存在，但**该报告自身结论为「发布镜像上传正常：✅ 合格」「流程自动化结论：✅ 流程已达标」**，只有标题带 ❌，疑为误列；`workspace/hygon/ENV.md` 亦将其标注为「✅ 合格（异常，需复核是否误列）」）
- **原始失败类型**：无历史失败（源日志记为「历史失败报告：暂无 / 无历史失败报告」，本轮视其为无历史失败的复核对象，而非「精度不达标」）
- **日期**：2026-09-17

## 现象

- 本轮为 `10.232.2.21` 上 6 个模型的批量部署与 50 题精度补测之一，使用统一 Hygon 新镜像 + `TRITON_ATTN` + BF16 路径。
- 与同批模型一致，服务启动需要显式指定 DTK 26.04 AILLVM clang，否则 FlagGems/Triton 编译路径可能触发 `HSACOError`；修复后单卡服务正常：端口 `8004` 返回 HTTP `200`，`/v1/models` 返回服务名 `Phi-3-mini-128k-instruct`、`max_model_len=131072`。
- GPQA Diamond 50 题得分 `30.00%`，相对 NV `33.00%` 下降 `9.09%`；本轮未检测到 runaway，评测耗时 `1092.18s`（约 18m 12.2s）。
- 与主要失败的 `gemma-1.1-7b-it` / `sarvam-m` / `SuperNova-Medius` 三个模型不同，本模型分数落在小样本容忍区间内。

## 定位

- **部署侧根因同批一致**：容器内默认 clang 路径不匹配会触发 Triton/FlagGems 编译问题，显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18` 后服务稳定；只用 `HIP_VISIBLE_DEVICES` 控卡，不设置 `ROCR_VISIBLE_DEVICES`（后者会让 `torch.cuda.is_available()` 变 `False`）。
- **精度侧是统计口径问题，不是严格等价**：GPQA 50 题每题占 2 个百分点，低 1～2 题就会放大成很大的相对退化百分比。本轮相对退化 `9.09%`（`-3.00` 个百分点 = `1.50` 题），超过 5% 门限但落进 `accuracy_compare.py` 的 `<=2` 题小样本容忍区间，因此判达标。
- **生成窗口偏大**：`max_model_len=131072` 使标准评测自动得到 `max_tokens=32768`。本轮虽无 runaway，但该窗口对 MCQ 任务仍偏大，后续自动化应统一记录并审查。

## 处置

宿主机 `bm-srwl-nj-zone3-d-bw1000-64g-2-21`（`10.232.2.21`），推理容器 `flagrelease-phi3-mini-128k`，评测容器 `flagrelease-model-download-20260917`，端口 `8004`，`HIP_VISIBLE_DEVICES=6`，TP=1，bf16。模型 `/public-flash/models/flagrelease/fixes_models/Phi-3-mini-128k-instruct` → 容器内 `/models/flagrelease/fixes_models/Phi-3-mini-128k-instruct`。本轮未重新构建/推送镜像，也未修改 vLLM、`vllm-plugin-FL`、FlagGems 源码。

容器运行配置（长驻容器 + `docker exec` 起服务）：

```text
cmd:      ["bash", "-lc", "sleep infinity"]
network:  host
ipc:      host
shm-size: 64 GiB
```

设备与权限：`/dev/kfd`、`/dev/dri`、`seccomp=unconfined`、`group-add=video`、`group-add=render`；挂载 `/public-flash/models -> /models`（读写）、`/opt/hyhal -> /opt/hyhal`（只读）。

处置步骤：

1. 使用统一 Hygon 新镜像；
2. 使用 `HIP_VISIBLE_DEVICES=6`，不设置 `ROCR_VISIBLE_DEVICES`；
3. 固定 `TRITON_ATTN`、BF16、TP=1 和 eager 模式；
4. 显式设置 `TRITON_HIP_CLANG_PATH=/opt/dtk/aillvm/bin/clang-18`（失败尝试：不设置时同批服务触发 Triton/FlagGems 编译问题）；
5. 沿用 Triton 默认缓存目录；
6. 使用 EvalScope `1.5.1`、固定并发 4，执行 GPQA Diamond 50 题；
7. 使用 `accuracy_compare.py` 与 NV 记录值比较，并按 50 题小样本噪声规则判定。

关键日志：

```text
/public-flash/models/release_run_logs/Phi-3-mini-128k-instruct/serve_retry-clang18-20260917.log
```

评测配置与命令：

| 项目 | 值 |
|------|---|
| 数据集 | GPQA Diamond |
| EvalScope | `1.5.1` |
| 题数 | 50 |
| `eval_batch_size` | 4 |
| `temperature` | 0 |
| `max_model_len` | 131072 |
| `max_tokens` | 32768 |
| 截断检测 | `--skip-truncation-check` 显式跳过 |
| 评测耗时 | `1092.18s` |

```bash
python3 fast_gpqa.py \
  --model-name Phi-3-mini-128k-instruct \
  --api-base http://127.0.0.1:8004/v1 \
  --dataset gpqa_diamond \
  --limit 50 \
  --eval-batch-size 4 \
  --skip-truncation-check \
  --dataset-dir /models/day0_eval/cache/datasets \
  --output /models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/phi3-mini-128k/gpqa50.json
```

结果摘要（逐题审计部分）：

```json
{
  "score": 30.0,
  "evalscope_score": 30.0,
  "total_questions": 50,
  "eval_batch_size": 4,
  "temperature": 0.0,
  "max_tokens": 32768,
  "max_model_len": 131072,
  "truncation_check_skipped": true,
  "runaway_detection": {
    "checked": 50,
    "runaway_count": 0
  },
  "answer_extraction_audit": {
    "checked": 50,
    "explicit_answer_found": 45,
    "fallback_to_evalscope": 0,
    "format_corrected_score": 30.0,
    "parser_mismatch_count": 2,
    "invalid_evalscope_extract_count": 7
  }
}
```

- 结果文件：`/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/phi3-mini-128k/gpqa50.json`
- 判定文件：`/public-flash/models/release_run_logs/accuracy/gpqa50_nv_20260917_1310/phi3-mini-128k/verdict.json`

## 结果

- 修复后分 / NV 基线：`30.00%` / NV `33.00%`
- 达标判定（accuracy_compare 退出码）：`aligned=true`（源日志只记录 verdict 的 `aligned` 字段，未记录退出码数值；按 SOP 约定 0=达标）—— **相对退化 `9.09%` 超过 5% 门限，但绝对差 `-3.00` 个百分点 = `1.50` 题，落入 50 题小样本噪声容忍区间（≤2 题），按噪声容忍规则通过**；不是严格 5% 相对退化通过
- 该轮判定文件（verdict.json）原文：

```json
{
  "aligned": true,
  "noise_zone": true,
  "rel_drop_pct": 9.09,
  "abs_diff": -3.0,
  "message": "精度达标(小样本噪声容忍): 当前=30.00%, NV=33.00%, 相对退化=9.09% 虽超容差 5.0%，但 绝对差异 3.00% = 1.50 题 (每题 2.00%, 共 50 题), ≤ 2 题噪声阈值，属小样本评测方差，判定达标"
}
```

- 计数对照：Hygon `30.00%`（15/50）vs NV `33.00%`，绝对差 `-3.00` 个百分点，折算 `1.50` 题，相对退化 `9.09%`。
- **NV 基线来源**：仓库 `nv_baseline.yaml` 中 `Phi-3-mini-128k-instruct.metrics.gpqa_diamond: 33`，即本次判定实际采用值（不存在被推翻的口径）。
- **可比性判读**：`nv_baseline.yaml` 只记录 NV 分数，缺少 NV 原始题目 ID、样本量、prompt、EvalScope 版本与逐题预测，只能确认**相对仓库 NV 记录值在小样本容忍规则下达标**，不能宣称与 NV 逐题同源。
- 环境备注：`ENV.md` 记录本模型历史失败报告显示 ✅ 合格（疑为误列），本轮按新增部署复核；本次 50 题结果只能作为快速验收样本，不能外推到全量。
- 答案解析：parser mismatch `2`、`invalid_evalscope_extract_count=7`，格式校正分仍为 `30.00%`，即本轮低分不是解析器误扣造成。
- **性能验收：本次未重测**。

## 提炼到 KNOWLEDGE 的条目

1. 50 题 GPQA 只能作快速验收样本：判定时必须同时给出相对退化和折算题数，相对退化超 5% 但差异 ≤2 题时应写“小样本噪声容忍通过”，不能写成严格精度等价。
2. 小样本容忍的前提是答案抽取审计干净——必须先确认格式校正分与 EvalScope 原始分一致，否则容忍判定的对象可能是评测器误差而非模型方差。
3. 长上下文模型的 `max_model_len` 会自动放大 `max_tokens`（131072 → 32768），MCQ 任务应显式收窄生成窗口并记录截断检测状态。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/Phi-3-mini-128k-instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist
# HARBOR_VER: V3
# GPU: Hygon DCU BW1000, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 33
# SCORE_FLAGOS: 30.0
# CONTAINER_DEVS: --device=/dev/kfd --device=/dev/dri --security-opt seccomp=unconfined --group-add video --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
set -euo pipefail

MODEL_ROOT="${MODEL_ROOT:-/public-flash/models}"
HYHAL_ROOT="${HYHAL_ROOT:-/opt/hyhal}"
[[ -d "$MODEL_ROOT" ]] || { echo "ERROR: model root not found: $MODEL_ROOT" >&2; exit 1; }
[[ -d "$HYHAL_ROOT/lib" ]] || { echo "ERROR: Hygon driver library not found: $HYHAL_ROOT/lib" >&2; exit 1; }
[[ -d "$HYHAL_ROOT/lib/cmake/rocm_smi" ]] || echo "WARNING: rocm_smi CMake directory not found under $HYHAL_ROOT; verify the host driver version" >&2

docker run --init -d --net=host --ipc=host \
  --security-opt seccomp=unconfined --security-opt label=disable --group-add video \
  --device=/dev/kfd --device=/dev/dri --shm-size=64g \
  --mount type=bind,src="$MODEL_ROOT",dst=/models \
  --mount type=bind,src="$HYHAL_ROOT",dst=/opt/hyhal,readonly \
  --name flagrelease-phi3-mini-128k \
  harbor.baai.ac.cn/flagrelease-public/flagtree-hcu-py310-torch2.10.0-dtk26.04-ubuntu22.04:202608-3.6-vllm0.24.0-xingcgen4-blacklist \
  bash -lc 'sleep infinity'
```

### 三、启动服务（容器内执行）

```bash
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/models/flagrelease/fixes_models/Phi-3-mini-128k-instruct}"
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
vllm serve "$MODEL_DIR" \
  --served-model-name Phi-3-mini-128k-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 131072 \
  --gpu-memory-utilization 0.90 \
  --port 8004 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
