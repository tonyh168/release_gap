# iluvatar/Marco-o1 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_Marco-o1_202608061005.md
- **原始失败类型**：服务启动失败（Operator crash）+ 精度存疑（V2 GPQA=32.83%，人工复核改判：未纳入成功清单，归档失败）
- **日期**：2026-09-15

## 现象

原始失败报告（vLLM 0.20.2 + plugin-FL 0.2.0）：V2 跑出 GPQA=32.83%（198 题，60 个算子），
但人工复核后归档为失败 —— 原始环境存在 Operator crash issue（1 个 issue 已提交）。

本次在新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）上复现：

- 服务正常启动，**无 Operator crash**（原 crash 算子在新版本已修复）
- `fast_gpqa.py` 完整跑完 50 题，result JSON 正常写出（`mode: standard`）
- GPQA **28.0%**，低于 NV 基线 32.0%（差 4 个百分点 = 2 题）
- accuracy_compare 判定为**小样本噪声容忍达标**（`noise_zone=true`）

## 定位

- 原 Operator crash 在 vLLM 0.24.0 中已自然修复，无需追加黑名单
- 28% vs 32% 的差距为 **2 题**，落在 50 题 GPQA 的小样本噪声区间内，**非真实退化**
  （`noise_detail`：绝对差异 4.00% = 2.00 题，每题 2.00%，≤ 2 题噪声阈值）
- Marco-o1 基于 Qwen2-7B（reasoning 微调版），标准 GQA 架构（非 MLA），
  attention-backend 应为 `TRITON_ATTN`（原报告误填 `TRITON_MLA`，本次已更正）；
  Qwen2-7B 无 `q_lora_rank`/`kv_lora_rank`，不具备 MLA 结构
- bf16 约 14 GB，单卡 32 GB 可装，**TP=1**

## 处置

### 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-marco-o1` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Marco-o1` |
| GPU / 端口 | GPU 5（TP=1）/ 8005 |
| attention-backend | `TRITON_ATTN`（Qwen2-7B 标准 GQA，非 MLA） |
| max-model-len | `32768` |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |
| 权重来源 | `AIDC-AI/Marco-o1`（ModelScope） |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-marco-o1 \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-marco-o1 bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

### 起 vLLM 服务（容器内执行，最终达标配置）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Marco-o1 \
  --served-model-name Marco-o1 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8005 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------|------------------------|------|
| 第1次 | sort,sort_stable（默认） | 28.0% | 0（PASS，噪声容忍） | 新镜像默认黑名单直接过，无需追加算子 |

**处置方式**：无需任何黑名单调整，默认 `sort,sort_stable` + `TRITON_ATTN` 直接通过；
未做失败尝试。另做了一处配置更正：attention-backend `TRITON_MLA` → `TRITON_ATTN`。

### 评测（eval-scope 容器内执行）

```bash
EVAL_DIR=/models/flagrelease/eval_methods
LOG=/models/release_run_logs/Marco-o1

python3 ${EVAL_DIR}/fast_gpqa.py \
  --model-name Marco-o1 \
  --api-base http://127.0.0.1:8005/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output ${LOG}/gpqa_diamond_result.json

python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2 ${LOG}/gpqa_diamond_result.json \
  --nv-baseline Marco-o1 \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output ${LOG}/verdict_gpqa_diamond.json
```

### 残留口径备注（源日志记录，未做处理）

TinyR1-32B-Preview 的 `detect_thinking()` 专项调查中发现：Marco-o1 自带
`generation_config.json` 写的是 `temperature: 0.7`，但实际评测日志记录的是
`temperature=0.0`（standard 分支），即与其自带配置不对等。源日志注明该项**未复核、未重跑**；
本次达标判定的依据是 `accuracy_compare` 的**小样本噪声容忍**结论，而非严格口径下的达标。

## 结果

- 修复后分 / NV 基线：**GPQA 28.0%**（50 题，14 题正确）/ NV 32.0%
- 达标判定（accuracy_compare 退出码）：**0（PASS，小样本噪声容忍）** ——
  表面相对退化 +12.5% 超出 5% 容差，但绝对差距仅 **2 题**（=4.0%），落在 50 题小样本方差内，
  `noise_zone=true` / `noise_adjusted=true`
- verdict 时间戳：2026-09-15T07:06:06

**verdict_gpqa_diamond.json**（最终达标那一份）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Marco-o1",
  "metric": "gpqa_diamond",
  "nv": { "score": 32.0, "source": "NV 实测" },
  "current": {
    "path": "/models/release_run_logs/Marco-o1/gpqa_diamond_result.json",
    "model": "Marco-o1",
    "score": 28.0,
    "mode": "standard"
  },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T07:06:06.279127",
  "rel_drop": 0.125,
  "rel_drop_pct": 12.5,
  "abs_diff": -4.0,
  "aligned": true,
  "noise_zone": true,
  "noise_detail": "绝对差异 4.00% = 2.00 题 (每题 2.00%, 共 50 题), ≤ 2 题噪声阈值，属小样本评测方差",
  "diff_questions": 2.0,
  "total_questions": 50,
  "noise_adjusted": true,
  "message": "精度达标(小样本噪声容忍): 当前=28.00%, NV=32.00%, 相对退化=12.50% 虽超容差 5.0%，但 绝对差异 4.00% = 2.00 题 (每题 2.00%, 共 50 题), ≤ 2 题噪声阈值，属小样本评测方差，判定达标"
}
```

## 提炼到 KNOWLEDGE 的条目

Marco-o1（Qwen2-7B reasoning 微调）在 vLLM 0.24.0 下 Operator crash 已自然消失，无需追加黑名单；
Qwen2 系列均为标准 GQA，attention-backend 应为 `TRITON_ATTN` 而非 `TRITON_MLA`。
本模型的「达标」属**小样本噪声容忍**（差 2 题），非严格达标，必要时可扩样本复核。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: AIDC-AI/Marco-o1
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 1 × 32GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 32.0
# SCORE_FLAGOS: 28.0
# CONTAINER_DEVS: --device=/dev/iluvatar --ipc=host --network=host --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --device=/dev/iluvatar \
  --shm-size 64g \
  -v /mnt/share/models:/models \
  --name flagos \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Marco-o1 \
  --served-model-name Marco-o1 \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8005 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
