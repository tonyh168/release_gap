# iluvatar/OpenThinker-7B 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_OpenThinker-7B_202609081330.md
- **原始失败类型**：评测中断（mmlu 145/1140，workflow_complete=false）+ 性能不达标
- **日期**：2026-09-15

## 现象

原始失败报告（vLLM 0.24.0 + plugin-FL 0.3.0 + FlagGems 5.3.4，65 个算子，TP=1）：
服务本身已能成功启动，但评测在 mmlu 第 145 题（共 1140 题，仅完成 12.7%）中断，
`workflow_complete=false`，2 个 issue 已提交。原因是评测框架在长时运行中超时，而非服务崩溃。

本次在新镜像（vLLM 0.24.0 + FlagGems 5.3.4.post1）上复现：

- 服务正常启动（65 算子，TP=1），无 Operator crash，无 dispatch 报错
- mmlu 完整跑完 1140 题，result JSON 正常写出
- math_500 完整跑完 500 题，result JSON 正常写出
- accuracy_compare 两项均一次达标

## 定位

- 原始中断原因为**评测框架超时**（非服务崩溃）；新镜像延长超时参数
  （`VLLM_ENGINE_ITERATION_TIMEOUT_S=72000`）后评测全程稳定
- FlagGems 5.3.4.post1 精度与原报告中 5.3.4 相当，算子层面无退化
- OpenThinker-7B 基于 `open-thoughts/OpenThinker-7B`（Qwen2.5-7B 推理微调版），
  标准 GQA 架构（非 MLA），attention-backend 应为 `TRITON_ATTN`
  （原报告模板误填 `TRITON_MLA`，本次已更正）
- bf16 约 14 GB，单卡 32 GB 可装，**TP=1**

## 处置

### 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-openthinker-7b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/OpenThinker-7B` |
| GPU / 端口 | GPU 3（TP=1）/ 8003 |
| attention-backend | `TRITON_ATTN`（Qwen2.5-7B 标准 GQA，非 MLA） |
| max-model-len | `32768` |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |
| 权重来源 | `open-thoughts/OpenThinker-7B`（ModelScope） |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-openthinker-7b \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-openthinker-7b bash
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
vllm serve /models/flagrelease/fixes_models/OpenThinker-7B \
  --served-model-name OpenThinker-7B \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8003 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | mmlu | math_500 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|:----:|:--------:|------------------------|------|
| 第1次 | sort,sort_stable（默认） | 75.0% | 86.5% | 0（PASS） | 两项均达标，无需调整黑名单 |

处置方式：**无需任何黑名单调整**，默认 `sort,sort_stable` + `TRITON_ATTN` 直接通过；
未做失败尝试（原报告的中断由超时参数延长后消失）。

### 评测（eval-scope 容器内执行）

```bash
EVAL_DIR=/models/flagrelease/eval_methods
LOG=/models/release_run_logs/OpenThinker-7B

python3 ${EVAL_DIR}/fast_gpqa.py \
  --model-name OpenThinker-7B \
  --api-base http://127.0.0.1:8003/v1 \
  --dataset mmlu \
  --dataset-dir /models/evalscope-datasets \
  --output ${LOG}/mmlu_result.json

python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2 ${LOG}/mmlu_result.json \
  --nv-baseline OpenThinker-7B \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric mmlu --json \
  --output ${LOG}/verdict_mmlu.json

python3 ${EVAL_DIR}/fast_gpqa.py \
  --model-name OpenThinker-7B \
  --api-base http://127.0.0.1:8003/v1 \
  --dataset math_500 \
  --dataset-dir /models/evalscope-datasets \
  --output ${LOG}/math_500_result.json

python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2 ${LOG}/math_500_result.json \
  --nv-baseline OpenThinker-7B \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric math_500 --json \
  --output ${LOG}/verdict_math_500.json
```

### 残留口径备注（源日志记录，未做处理）

TinyR1-32B-Preview 的 `detect_thinking()` 专项调查中发现：OpenThinker-7B 自带
`generation_config.json` 写的是 `temperature: 0.7`，但 `fast_gpqa.resolve_gen_params()` 的
`_resolve_model_dir()` 在本环境两条路径都不通，实际评测按 standard 分支的
`temperature=0.0`（贪心）执行，与其自带配置不对等。源日志注明该覆盖机制失效影响范围不止
TinyR1，此项**未复核、未重跑**，本次达标判定以 `accuracy_compare` 结果为准。

## 结果

- 修复后分 / NV 基线：**mmlu 75.0%（1140 题）/ NV 77.0%**；**math_500 86.5%（500 题）/ NV 88.0%**
- 达标判定（accuracy_compare 退出码）：**mmlu 0（PASS，相对退化 2.6%）/ math_500 0（PASS，相对退化 1.7%）**
- verdict 时间戳：2026-09-15T14:19:37（两份 verdict 同一批次）

**verdict_mmlu.json**（最终达标那一份）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "OpenThinker-7B",
  "metric": "mmlu",
  "nv": { "score": 77.0, "source": "NV 实测" },
  "current": {
    "path": "/models/release_run_logs/OpenThinker-7B/mmlu_result.json",
    "model": "OpenThinker-7B",
    "score": 75.0,
    "mode": "standard"
  },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T14:19:37.222509",
  "rel_drop": 0.026,
  "rel_drop_pct": 2.6,
  "abs_diff": -2.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=75.00%, NV=77.00%, 相对退化=2.60% (容差 5.0%)"
}
```

**verdict_math_500.json**（最终达标那一份）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "OpenThinker-7B",
  "metric": "math_500",
  "nv": { "score": 88.0, "source": "NV 实测" },
  "current": {
    "path": "/models/release_run_logs/OpenThinker-7B/math_500_result.json",
    "model": "OpenThinker-7B",
    "score": 86.5,
    "mode": "standard"
  },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T14:19:37.692400",
  "rel_drop": 0.017,
  "rel_drop_pct": 1.7,
  "abs_diff": -1.5,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=86.50%, NV=88.00%, 相对退化=1.70% (容差 5.0%)"
}
```

## 提炼到 KNOWLEDGE 的条目

OpenThinker-7B（Qwen2.5-7B 推理微调）原始失败为评测框架超时而非服务崩溃；新镜像延长超时后
全量 mmlu+math_500 稳定跑完。Qwen2.5 系列为标准 GQA 架构，attention-backend 应为
`TRITON_ATTN`，默认黑名单 `sort,sort_stable` 即可通过。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: open-thoughts/OpenThinker-7B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 1 × 32GB
# TP: 1
# VERDICT: ok
# METRIC: mmlu / math_500
# SCORE_ORIGIN: mmlu 77.0 / math_500 88.0
# SCORE_FLAGOS: mmlu 75.0 / math_500 86.5
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
vllm serve /models/flagrelease/fixes_models/OpenThinker-7B \
  --served-model-name OpenThinker-7B \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768 \
  --port 8003 \
  --attention-backend TRITON_ATTN \
  --enforce-eager \
  --trust-remote-code
```
