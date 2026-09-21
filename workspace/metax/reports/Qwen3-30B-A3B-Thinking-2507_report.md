# metax/Qwen3-30B-A3B-Thinking-2507 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Qwen3-30B-A3B-Thinking-2507_202608012206.md
- **原始失败类型**：服务启动失败（V1–V4 全无数据）+ 3 条 Issue（crash / accuracy / perf）
- **日期**：2026-09-16

## 现象

原报告 V1–V4 全空，服务在启动阶段就崩，没有任何可用的评测数据。

同类参考：Qwen3-30B-A3B-Thinking-2507 与 Qwen3-Coder-30B-A3B-Instruct 同为 MoE + MLA 架构
（30B 总参 / A3B 激活 3B），后者已于 2026-09-14 用默认黑名单 + eager 一次起成功（GPQA 50%，达标）。
本模型为其 thinking 变体，评测必须走 thinking 模式。

本次按同策略起 v1 服务：日志无崩溃，`Application startup complete` 正常，短 prompt（decode 路径）
与长 prompt（MLA prefill 路径）冒烟均通过。

评测阶段出现工具侧异常：`fast_gpqa.py` 跑完 50 题后 `score` 字段写入 **null**。原因是 thinking 模型的
答案夹在 `<think>…</think>` 块里，`fast_gpqa` 的答案提取逻辑未针对 thinking 模式解析，分数无法计算；
但 evalscope 的 predictions 与 reviews 文件各 50 行均完整写入，耗时 100m 42.1s。

## 定位

- 服务层：MoE + MLA 架构与 Qwen3-Coder 完全相同。plugin-FL 默认黑名单
  （`mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`）已覆盖全部崩溃算子；
  `VLLM_FL_USE_FLAGGEMS_ATTN=0` 是**必需项**——不关 FlagGems attention 会在 MLA prefill 路径 OOM
  （FlagGems attention 共享内存不足）。二者叠加后服务一次起成功，无需二分排查黑名单。
- 资源层：MoE 权重文件约 60GB，TP=4 时单卡 KV cache 空间足够（沿用 Qwen3-Coder 实测配置）。
- 评测层：`fast_gpqa.py` thinking 模式解析 bug（`score=null`）是工具侧问题，不影响模型本身正确率；
  真实得分从 evalscope reviews 的 `sample_score.score.value.accuracy` 补回。

## 处置

### 环境（达标轮次）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-qwen3-30b-a3b-thinking-2507` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507` |
| TP / GPU / 端口 | TP=4，GPU 2,3,4,5，port=8000 |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |
| 权重来源 | `Qwen/Qwen3-30B-A3B-Thinking-2507`（ModelScope） |

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| v1 | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **74.0%**（37/50） | **0（达标）** | 2026-09-16；启动无崩溃一次成功；耗时 100m 42s；fast_gpqa score=null，从 evalscope reviews 手工补计分 |

服务阶段只有一轮：黑名单与算子配置**全程未改动**，`VLLM_FL_USE_FLAGGEMS_ATTN=0` 为唯一必需调整项，
无失败的黑名单尝试。

原始失败报告中的 NV 基线为 gpqa_diamond = **75**（容差 5%，即绝对分 ≤ 71.25 判不达标）。

### 启动命令（v1，最终达标配置，复现用）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=2,3,4,5
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507 \
  --served-model-name Qwen3-30B-A3B-Thinking-2507 \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```

### 冒烟验证（MLA prefill 路径必须测长 prompt）

```bash
curl -s http://localhost:8000/v1/models

curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Qwen3-30B-A3B-Thinking-2507","messages":[{"role":"user","content":"1+1=?"}],"max_tokens":16,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'

curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Qwen3-30B-A3B-Thinking-2507","messages":[{"role":"user","content":"Derive in detail the physical meaning of E=mc^2 and its application in nuclear fission, with a concrete numerical example."}],"max_tokens":512,"temperature":0}'
```

### 评测（thinking 模式）

**评测参数**（v1，`gpqa_v1.json`）：
- mode=thinking，temperature=0.6，max_tokens=20000，max_model_len=32768，batch_size=16
- 50 题，无截断（truncation_detected=false），无复读（runaway_count=0）
- 耗时：100m 42.1s（思维链模型每题约 120s）

```bash
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name Qwen3-30B-A3B-Thinking-2507 \
  --api-base http://127.0.0.1:8000/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/Qwen3-30B-A3B-Thinking-2507/gpqa_v1.json

python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/Qwen3-30B-A3B-Thinking-2507/gpqa_v1.json \
  --nv-baseline Qwen3-30B-A3B-Thinking-2507 \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/Qwen3-30B-A3B-Thinking-2507/verdict_v1.json
```

**score=null 的补计分过程**：`fast_gpqa.py` 的 thinking 模式答案提取未剥离 `<think>` 块，导致
`score` 字段写成 null。用脚本读取 evalscope reviews 文件
`/outputs/gpqa_diamond/20260916_063058/reviews/Qwen3-30B-A3B-Thinking-2507/gpqa_diamond_default.jsonl`（eval-scope 容器内），
逐条累加 `sample_score.score.value.accuracy` 得 37/50 = **74.0%**，写回修复版 result JSON 后
重跑 `accuracy_compare.py`，得到正式 verdict。

**逐题对错**：源日志只记录了 reviews 文件路径，未落逐题 `index` 明细表，故此处不列逐题清单；
50 题 predictions/reviews 均完整（无缺题、无中断）。

## 结果

- 修复后分 / NV 基线：**74.0%**（37/50） / **75.0%**
- 达标判定（accuracy_compare 退出码）：**0（容差内达标，noise_zone=false，相对退化 1.33% < 容差 5.0%）**

verdict_v1.json 原文（最终达标那一份）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Qwen3-30B-A3B-Thinking-2507",
  "metric": "gpqa_diamond",
  "nv": { "score": 75.0, "source": "NV 实测" },
  "current": { "score": 74.0, "mode": "thinking" },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T08:47:02.497407",
  "rel_drop": 0.0133,
  "rel_drop_pct": 1.33,
  "abs_diff": -1.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=74.00%, NV=75.00%, 相对退化=1.33% (容差 5.0%)"
}
```

说明：本模型 74.0% 低于 NV 基线 75.0%（差 1.0pt），属容差内的相对退化，**不是反超基线**，
也不构成严格意义的「优于基线」。

## 提炼到 KNOWLEDGE 的条目

1. Qwen3-30B-A3B-Thinking-2507 与 Qwen3-Coder-30B-A3B-Instruct 同架构，MetaX 上用同一策略
   （默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + eager，TP=4）可一次起成功；MLA 模型必须显式
   关闭 FlagGems attention，否则 MLA prefill OOM。
2. `fast_gpqa.py` 在 thinking 模式下 `score` 字段可能写入 null（答案未从 `<think>` 块提取）；
   evalscope 的 reviews 文件仍完整记录逐题对错，可从 `sample_score.score.value.accuracy` 补回得分，
   不必重跑评测。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Qwen/Qwen3-30B-A3B-Thinking-2507
# IMAGE: harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
# HARBOR_VER: V3
# GPU: MetaX C550, 4 × 64GB
# TP: 4
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 75.0
# SCORE_FLAGOS: 74.0
# CONTAINER_DEVS: --device /dev/dri:/dev/dri:rwm --device /dev/mxcd:/dev/mxcd:rwm --shm-size 64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --device /dev/dri:/dev/dri:rwm --device /dev/mxcd:/dev/mxcd:rwm \
  --shm-size 64g \
  -v /public-flash/models:/models \
  --name flagos \
  harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507 \
  --served-model-name Qwen3-30B-A3B-Thinking-2507 \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```
