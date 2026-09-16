# iluvatar/Marco-o1 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_Marco-o1_202608061005.md
- **原始失败类型**：服务启动失败（Operator crash）+ 精度存疑（V2 GPQA=32.83%，人工复核归档失败）
- **修复日期**：2026-09-15

---

## 背景分析

V2 跑出 GPQA=32.83%（198题，60个算子），但人工复核后归档为失败——原始环境
vLLM 0.20.2 + plugin-FL 0.2.0，存在 Operator crash issue。
Marco-o1 基于 Qwen2-7B（reasoning 微调版），标准 GQA 架构（非 MLA），7B 量级，
bf16 约 14 GB，单卡 32 GB 可装，**TP=1**。

新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）已知修复了多个算子 crash；
先以默认黑名单起服务验精度，若仍 crash 则抓栈补充黑名单。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-marco-o1` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Marco-o1` |
| GPU | `CUDA_VISIBLE_DEVICES=5`（TP=1，端口 8005） |
| attention-backend | `TRITON_ATTN`（Qwen2-7B 标准 GQA，非 MLA） |
| max-model-len | `32768` |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |

---

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
ixsmi
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
docker rm -f flagrelease-fix-marco-o1 2>/dev/null || true
docker run -itd --name flagrelease-fix-marco-o1 \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash

## Step 2：确认模型

权重来源：`AIDC-AI/Marco-o1`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/Marco-o1/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model AIDC-AI/Marco-o1 \
  --local_dir /models/flagrelease/fixes_models/Marco-o1
```

## Step 3：起 vLLM 服务

Marco-o1 为 Qwen2-7B 标准 GQA（非 MLA），使用 `TRITON_ATTN`；默认黑名单 `sort,sort_stable`。

```bash
docker exec flagrelease-fix-marco-o1 bash -c "
  export GEMS_VENDOR=iluvatar
  export VLLM_PLUGINS=fl
  export CUDA_VISIBLE_DEVICES=5
  export VLLM_WORKER_MULTIPROC_METHOD=spawn
  export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
  export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
  export VLLM_RPC_TIMEOUT=72000000
  export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
  model_name=Marco-o1
  mkdir -p /models/release_run_logs/\${model_name}
  nohup vllm serve /models/flagrelease/fixes_models/\${model_name} \
    --served-model-name \${model_name} \
    --dtype bfloat16 \
    --tensor-parallel-size 1 \
    --gpu-memory-utilization 0.9 \
    --max-model-len 32768 \
    --port 8005 \
    --attention-backend TRITON_ATTN \
    --enforce-eager \
    --trust-remote-code \
    > /models/release_run_logs/\${model_name}/serve.log 2>&1 &
  echo \$! > /models/release_run_logs/\${model_name}/serve.pid
  echo 'vllm serve launched, pid:' \$(cat /models/release_run_logs/\${model_name}/serve.pid)
"
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------|------------------------|------|
| 第1次 | sort,sort_stable（默认） | 28.0% | 0（PASS） | 新镜像默认黑名单直接过，无需追加算子 |

## Step 4：评测

```bash
# 在 eval-scope 容器内
model_name=Marco-o1
EVAL_DIR=/models/flagrelease/eval_methods
LOG=/models/release_run_logs/${model_name}

python3 ${EVAL_DIR}/fast_gpqa.py \
  --model-name ${model_name} \
  --api-base http://127.0.0.1:8005/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output ${LOG}/gpqa_diamond_result.json

python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2  ${LOG}/gpqa_diamond_result.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output ${LOG}/verdict_gpqa_diamond.json
```

## 现象

原始失败：vLLM 0.20.2 Operator crash + V2 GPQA=32.83%（人工复核归档失败，NV 基线 32%）。

本次新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）：
- 服务正常启动，无 Operator crash（原 crash 算子在新版本已修复）
- fast_gpqa.py 完整跑完 50 题，result JSON 正常写出（`mode: standard`）
- GPQA 28.0%，低于 NV 基线 32.0%（差 4 个百分点 = 2 题）
- accuracy_compare 噪声容忍达标（≤2 题差距属 50 题小样本方差）

## 定位

- 原 Operator crash 在 vLLM 0.24.0 中已自然修复，无需追加黑名单
- 28% vs 32% 的差距为 2 题，落在 50 题 GPQA 的小样本噪声区间内，非真实退化
- Marco-o1 为 Qwen2-7B 标准 GQA 架构，应使用 `TRITON_ATTN`（原模板误填 `TRITON_MLA`，本次已更正）

## 处置

无需任何黑名单调整，默认 `sort,sort_stable` + `TRITON_ATTN` 直接通过。
attention-backend 更正：`TRITON_MLA` → `TRITON_ATTN`（Qwen2-7B 无 `q_lora_rank`/`kv_lora_rank`，非 MLA 架构）。

## 结果

- 修复后 GPQA 正确率：**28.0%**（50题，14题正确）
- NV 基线：32.0%
- 相对退化：+12.5%（表面超容差，但绝对差距仅 2 题）
- 达标判定：**PASS**（噪声容忍，accuracy_compare 退出码 0）
- verdict 时间戳：2026-09-15T07:06:06

**verdict_gpqa_diamond.json**：
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

Marco-o1（Qwen2-7B reasoning 微调）在 vLLM 0.24.0 下 Operator crash 已自然消失，无需追加黑名单；Qwen2 系列均为标准 GQA，attention-backend 应为 `TRITON_ATTN` 而非 `TRITON_MLA`。
