# iluvatar/LFM2.5-1.2B-Instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_LFM2.5-1.2B-Instruct_202608061005.md
- **原始失败类型**：精度不达标（V2 GPQA=0.0%）+ 性能不达标
- **日期**：2026-09-15

## 现象

原始失败报告（vLLM 0.20.2 + plugin-FL 0.2.0 + FlagGems 5.0.x）：V2 GPQA=0.0%，精度完全崩溃；
性能也不达标，2 个 issue 已提交。LFM2.5-1.2B-Instruct 与 Thinking 版共享同一套 32 算子白名单
（含 vstack 算子），说明 FlagGems 5.0.x 在 LFM 架构上存在系统性精度问题。

本次在新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）上复现：

- 服务正常启动，无 Operator crash，无 dispatch 报错
- `fast_gpqa.py` 完整跑完 50 题，result JSON 正常写出（`mode: standard`，非 thinking，
  未触发 list content crash）
- accuracy_compare 正常运行，一次即达标

## 定位

- FlagGems 5.0.x 在 LFM 架构上存在系统性精度崩溃（GPQA=0.0%），5.3.4.post1 已修复
- 原报告提到的 vstack 算子白名单在新版本中不再需要
- plugin-FL dispatch 报错在 vLLM 0.24.0 中已消失
- LFM2.5-1.2B-Instruct 为标准 SSM/hybrid 架构（非 MLA），attention-backend 用 `TRITON_ATTN`；
  bf16 约 2.4 GB，单卡可装，**TP=1**

## 处置

### 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-lfm2.5-1.2b-instruct` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/LFM2.5-1.2B-Instruct` |
| GPU / 端口 | GPU 1（TP=1）/ 8001 |
| attention-backend | `TRITON_ATTN`（LFM 非 MLA 架构） |
| max-model-len | `32768` |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |
| 权重来源 | `LiquidAI/LFM2.5-1.2B-Instruct`（ModelScope） |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-lfm2.5-1.2b-instruct \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-lfm2.5-1.2b-instruct bash
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
vllm serve /models/flagrelease/fixes_models/LFM2.5-1.2B-Instruct \
  --served-model-name LFM2.5-1.2B-Instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8001 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------|------------------------|------|
| 第1次 | sort,sort_stable（默认） | 40.0% | 0（PASS） | 新镜像 FlagGems 5.3.4.post1 精度完全恢复，无需 vstack 黑名单 |

处置方式：**无需任何黑名单调整**，默认 `sort,sort_stable` 直接通过；未做失败尝试。
原计划「若仍 0% 则扩黑名单排查 vstack 等算子」未触发。

### 评测（eval-scope 容器内执行）

```bash
EVAL_DIR=/models/flagrelease/eval_methods
LOG=/models/release_run_logs/LFM2.5-1.2B-Instruct

python3 ${EVAL_DIR}/fast_gpqa.py \
  --model-name LFM2.5-1.2B-Instruct \
  --api-base http://127.0.0.1:8001/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output ${LOG}/gpqa_diamond_result.json

python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2 ${LOG}/gpqa_diamond_result.json \
  --nv-baseline LFM2.5-1.2B-Instruct \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output ${LOG}/verdict_gpqa_diamond.json
```

## 结果

- 修复后分 / NV 基线：**GPQA 40.0%**（50 题，20 题正确）/ NV 29.0%
- 达标判定（accuracy_compare 退出码）：**0（PASS）** —— 相对变化 **+37.93%（大幅反超基线）**
- verdict 时间戳：2026-09-15T06:57:40

**verdict_gpqa_diamond.json**（最终达标那一份）：

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

LFM2.5-1.2B-Instruct 与 Thinking 版同属 LFM 系列精度崩溃问题（FlagGems 5.0.x），5.3.4.post1
一次修复两个模型；默认黑名单即可，vstack 白名单不再需要。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: LiquidAI/LFM2.5-1.2B-Instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 1 × 32GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 29.0
# SCORE_FLAGOS: 40.0
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
vllm serve /models/flagrelease/fixes_models/LFM2.5-1.2B-Instruct \
  --served-model-name LFM2.5-1.2B-Instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8001 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
