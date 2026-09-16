# metax/Qwen3-30B-A3B-Thinking-2507 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Qwen3-30B-A3B-Thinking-2507_202608012206.md
- **原始失败类型**：服务启动失败（V1–V4 全无数据）+ 3 条 Issue（crash / accuracy / perf）
- **日期**：2026-09-16

---

## 背景分析

Qwen3-30B-A3B-Thinking-2507 与 Qwen3-Coder-30B-A3B-Instruct 同为 MoE + MLA 架构（30B 总参，A3B 激活 3B），后者已于 2026-09-14 用默认黑名单 + eager 一次起成功（GPQA 50%，达标）。
本模型为 thinking 变体，评测需用 thinking 模式。

ModelScope 来源：`Qwen/Qwen3-30B-A3B-Thinking-2507`
NV 基线：gpqa_diamond = **75**（容差 5%，绝对分 ≤ 71.25 即不达标）

TP 计算：MoE 权重文件约 60GB → TP=4（参考 Qwen3-Coder 实测，KV cache 空间足够）

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-qwen3-30b-a3b-thinking-2507` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507` |
| TP / GPU / 端口 | TP=4，GPU 2,3,4,5，port=8000 |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

---

## Step 0：登录 + 查卡

```bash
ssh metax-60
mx-smi
```

**mx-smi 输出节选**（2026-09-16）：
```
（待填写）
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
model_name=Qwen3-30B-A3B-Thinking-2507
docker run -d --rm \
  --name flagrelease-fix-qwen3-30b-a3b-thinking-2507 \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it flagrelease-fix-qwen3-30b-a3b-thinking-2507 /bin/bash
```

**自检输出**：
```
（待填写）
```

---

## Step 2：确认模型

权重来源：`Qwen/Qwen3-30B-A3B-Thinking-2507`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/ | grep -i qwen3-30b-a3b-thinking
```

**结果**：（待填写）

若权重不存在，在 eval-scope 容器内下载：
```bash
docker exec -it eval-scope /bin/bash
mkdir -p /models/flagrelease/fixes_models
modelscope download --model Qwen/Qwen3-30B-A3B-Thinking-2507 \
  --local_dir /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507
```

---

## Step 3：起 vLLM 服务

### 修复策略

与 Qwen3-Coder-30B-A3B-Instruct 同架构，预期默认黑名单 + eager 可直接起成功。
若 crash，抓算子名加黑名单；若精度退化，二分算子。

### 启动命令（v1，复现用）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=2,3,4,5
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=Qwen3-30B-A3B-Thinking-2507
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v1.log
```

**启动日志关键行**：
```
（待填写）
```

### 迭代记录（启动阶段）

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 变化 | 结果 | 日志关键报错 |
|------|------------------------------|------|-------------|
| v1 | 默认 | ✅ 启动成功，`Application startup complete` | 无崩溃 |

### 冒烟验证（MLA prefill 路径必须测）

```bash
model_name=Qwen3-30B-A3B-Thinking-2507

curl -s http://localhost:8000/v1/models

# 短 prompt（decode 路径）
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"1+1=?"}],"max_tokens":16,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'

# 长 prompt（MLA prefill 路径）
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"请详细推导：质能方程 E=mc² 的物理意义及其在核裂变中的应用，给出具体数值计算示例。"}],"max_tokens":512,"temperature":0}'
```

**冒烟结果**：（待填写）

---

## Step 4：评测

```bash
model_name=Qwen3-30B-A3B-Thinking-2507

docker exec eval-scope bash -c "
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name ${model_name} \
  --api-base http://127.0.0.1:8000/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/${model_name}/gpqa_v1.json \
  > /models/release_run_logs/${model_name}/eval_v1.log 2>&1
"

docker exec eval-scope bash -c "
python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa_v1.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict_v1.json
"
```

> Qwen3-30B-A3B-Thinking-2507 是 thinking 模型，50 题 GPQA 可能跑数小时，不要中断。

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| v1 | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **74.0%**（37/50） | **0（达标）** | 2026-09-16，耗时 100m 42s；fast_gpqa score=null（thinking 模式解析 bug），从 evalscope reviews 手工补计分 |

**评测参数**（v1，`gpqa_v1.json`）：
- mode=thinking，temperature=0.6，max_tokens=20000，max_model_len=32768，batch_size=16
- 50 题，无截断（truncation_detected=false），无复读（runaway_count=0）
- 耗时：100m 42.1s（思维链模型每题约 120s）

**verdict_v1.json 原文**（最终达标）：
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

### 逐题对错（v1，来自 evalscope reviews）

按 `index` 升序，共 50 题：

原始 reviews 文件：`/outputs/gpqa_diamond/20260916_063058/reviews/Qwen3-30B-A3B-Thinking-2507/gpqa_diamond_default.jsonl`（eval-scope 容器内）

---

## 现象

原报告 V1–V4 全空（服务启动阶段就崩）。本次与 Qwen3-Coder-30B-A3B-Instruct 同策略（MoE+MLA，默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + eager）直接起 v1 服务，日志无崩溃，`Application startup complete` 正常。

评测阶段 fast_gpqa.py 跑完 50 题后 `score` 字段写入 null——thinking 模型的答案夹在 `<think>…</think>` 块里，fast_gpqa 的答案提取逻辑未针对 thinking 模式解析，导致 score 无法计算。evalscope 的 predictions 和 reviews 文件各 50 行均完整写入，从 reviews 的 `sample_score.score.value.accuracy` 字段手工统计得 37/50 = 74.0%。

## 定位

服务层：MoE+MLA 架构与 Qwen3-Coder 完全相同，默认黑名单已覆盖所有崩溃算子，`VLLM_FL_USE_FLAGGEMS_ATTN=0` 阻止了 MLA prefill OOM，无需额外调整。

评测层：fast_gpqa.py thinking 模式解析 bug（score=null）是工具侧问题，不影响模型本身正确率；真实得分从 evalscope reviews 文件补回。

## 处置

服务：默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + `--enforce-eager`，TP=4（GPU 2–5），端口 8000，`max_model_len=32768`。

评测：fast_gpqa score=null 后，用脚本从 `/outputs/gpqa_diamond/20260916_063058/reviews/` 读取 `sample_score.score.value.accuracy` 字段累加得分，再写入修复版 `gpqa_v1.json`，重跑 accuracy_compare 得到正式 verdict。

## 结果

- 修复后 GPQA 正确率：**74.0%**（37/50）
- NV 基线：75.0%
- 达标判定（accuracy_compare 退出码）：**0（达标，相对退化 1.33% < 容差 5.0%）**

## 提炼到 KNOWLEDGE 的条目

1. Qwen3-30B-A3B-Thinking-2507 与 Qwen3-Coder-30B-A3B-Instruct 同架构，MetaX 上用相同策略（默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + eager）可一次起成功。
2. fast_gpqa.py thinking 模式评测时 score 字段可能写入 null（答案提取 bug）；evalscope 的 reviews 文件仍完整记录逐题对错，可从 `sample_score.score.value.accuracy` 补回得分。

