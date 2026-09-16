# iluvatar/LFM2.5-1.2B-Instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_LFM2.5-1.2B-Instruct_202608061005.md
- **原始失败类型**：精度不达标（V2 GPQA=0.0%）+ 性能下降
- **修复日期**：2026-09-15

---

## 背景分析

V2 GPQA=0.0%，精度完全崩溃；性能也不达标，2个 issue 已提交。
LFM2.5-1.2B-Instruct 与 Thinking 版共享同一套 32 算子白名单（含 vstack 算子），
说明 FlagGems 5.0.x 在 LFM 架构上存在系统性精度问题。

LFM2.5-1.2B-Instruct 是标准 SSM/hybrid 架构（非 MLA），1.2B 量级，bf16 约 2.4 GB，单卡可装，**TP=1**。
新镜像升至 FlagGems 5.3.4.post1，直接起服务验精度；若仍 0% 则扩黑名单排查 vstack 等算子。

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-lfm2.5-1.2b-instruct` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/LFM2.5-1.2B-Instruct` |
| GPU | `CUDA_VISIBLE_DEVICES=1`（TP=1，端口 8001） |
| attention-backend | `TRITON_ATTN`（LFM 非 MLA 架构） |
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
docker rm -f flagrelease-fix-lfm2.5-1.2b-instruct 2>/dev/null || true
docker run -itd --name flagrelease-fix-lfm2.5-1.2b-instruct \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash

## Step 2：确认模型

权重来源：`LiquidAI/LFM2.5-1.2B-Instruct`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/LFM2.5-1.2B-Instruct/
```

若需下载（eval-scope 容器里）：
```bash
docker exec -it eval-scope bash
modelscope download --model LiquidAI/LFM2.5-1.2B-Instruct \
  --local_dir /models/flagrelease/fixes_models/LFM2.5-1.2B-Instruct
```

## Step 3：起 vLLM 服务

LFM2.5-1.2B-Instruct 为 SSM/hybrid 架构（非 MLA），使用 `TRITON_ATTN`；默认黑名单 `sort,sort_stable`。

```bash
docker exec flagrelease-fix-lfm2.5-1.2b-instruct bash -c "
  export GEMS_VENDOR=iluvatar
  export VLLM_PLUGINS=fl
  export CUDA_VISIBLE_DEVICES=1
  export VLLM_WORKER_MULTIPROC_METHOD=spawn
  export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
  export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
  export VLLM_RPC_TIMEOUT=72000000
  export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
  model_name=LFM2.5-1.2B-Instruct
  mkdir -p /models/release_run_logs/\${model_name}
  nohup vllm serve /models/flagrelease/fixes_models/\${model_name} \
    --served-model-name \${model_name} \
    --dtype bfloat16 \
    --tensor-parallel-size 1 \
    --gpu-memory-utilization 0.9 \
    --max-model-len 32768 \
    --port 8001 \
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
| 第1次 | sort,sort_stable（默认） | 40.0% | 0（PASS） | 新镜像 FlagGems 5.3.4.post1 精度完全恢复，无需 vstack 黑名单 |

## Step 4：评测

```bash
# 在 eval-scope 容器内
model_name=LFM2.5-1.2B-Instruct
EVAL_DIR=/models/flagrelease/eval_methods
LOG=/models/release_run_logs/${model_name}

python3 ${EVAL_DIR}/fast_gpqa.py \
  --model-name ${model_name} \
  --api-base http://127.0.0.1:8001/v1 \
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

原始失败：V2 GPQA=0.0%，精度完全崩溃。

本次新镜像（FlagGems 5.3.4.post1）：
- 服务正常启动，无 Operator crash，无 dispatch 报错
- fast_gpqa.py 完整跑完 50 题，result JSON 正常写出（`mode: standard`，非 thinking，无 list content crash）
- accuracy_compare 正常运行，一次即达标

## 定位

FlagGems 5.0.x 在 LFM 架构上存在系统性精度崩溃（GPQA=0.0%），5.3.4.post1 已修复。
原报告提到的 vstack 算子白名单在新版本中不再需要。
plugin-FL dispatch 报错在 vLLM 0.24.0 中已消失。

## 处置

无需任何黑名单调整，默认 `sort,sort_stable` 直接通过。

## 结果

- 修复后 GPQA 正确率：**40.0%**（50题，20题正确）
- NV 基线：29.0%
- 相对变化：+37.93%（大幅反超基线）
- 达标判定：**PASS**（accuracy_compare 退出码 0）
- verdict 时间戳：2026-09-15T06:57:40

**verdict_gpqa_diamond.json**：
```json
{
  "baseline_mode": "nv_reference",
  "model": "LFM2.5-1.2B-Instruct",
  "metric": "gpqa_diamond",
  "nv": { "score": 29.0, "source": "NV 实测" },
  "current": {
    "path": "/models/release_run_logs/LFM2.5-1.2B-Instruct/gpqa_diamond_result.json",
    "model": "LFM2.5-1.2B-Instruct",
    "score": 40.0,
    "mode": "standard"
  },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T06:57:40.415981",
  "rel_drop": -0.3793,
  "rel_drop_pct": -37.93,
  "abs_diff": 11.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=40.00%, NV=29.00%, 相对退化=-37.93% (容差 5.0%)"
}
```

## 提炼到 KNOWLEDGE 的条目

LFM2.5-1.2B-Instruct 与 Thinking 版同属 LFM 系列精度崩溃问题（FlagGems 5.0.x），5.3.4.post1 一次修复两个模型；默认黑名单即可，vstack 白名单不再需要。
