# metax/EXAONE-4.0-32B 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_EXAONE-4.0-32B_202608070744.md
- **原始失败类型**：服务启动失败（Operator crash）
- **日期**：2026-09-14

---

## 背景分析

原报告中 V1–V4 所有评测数据均为空，说明服务在 V1 阶段（裸 vLLM）就起不来，连基线都没有。
Issue 标题：`Operator crash on 沐曦(Metax) (LGAI-EXAONE/EXAONE-4.0-32B)`。

EXAONE-4.0-32B 是一个 MoE 架构模型（32B参数，非稠密），attention 实现可能用了 MLA 变体，
需要特别注意 `--attention-backend` 和 `VLLM_FL_USE_FLAGGEMS_ATTN` 的设置。

TP 计算：32B bf16 实际活跃参数更少，但权重文件仍约 64GB → TP=2 起步，若 OOM 升至 TP=4。
单卡 63.6GB，2 卡 127.2GB，预留 30% → 可用 89GB，能装下 64GB 权重。建议先用 **TP=4** 留
足 KV cache 空间（EXAONE 类模型实测 TP=2 KV cache OOM，见 SOP 说明）。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `EXAONE-4.0-32B_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/EXAONE-4.0-32B` |
| TP / 端口 | TP=4，port=8000（默认） |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

---

## Step 0：登录 + 查卡

```bash
ssh metax-57
mx-smi   # 确认至少4张卡空闲
```

**mx-smi 输出节选**：
```
（上机后粘贴，确认空闲卡号）
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
docker run -d --rm \
  --name EXAONE-4.0-32B_flagos \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it EXAONE-4.0-32B_flagos /bin/bash

mx-smi
python -c "import vllm; print(vllm.__version__)"
```

**自检输出**：
```
vllm 版本：
```

---

## Step 2：确认模型

权重来源：`LGAI-EXAONE/EXAONE-4.0-32B`（ModelScope）

```bash
ls /models/ | grep -i exaone
ls /models/EXAONE-4.0-32B/
```

**结果**：☐ 共享盘已有 / ☐ 需下载

若需下载：
```bash
pip install -q modelscope
modelscope download --model LGAI-EXAONE/EXAONE-4.0-32B \
  --local_dir /models/EXAONE-4.0-32B
```

---

## Step 3：起 vLLM 服务

### 修复策略

原始失败是 Operator crash，修复路径：
1. 先用 eager + 默认黑名单起服务，看崩溃日志定位算子名
2. 把崩溃算子加入黑名单，重试
3. 服务起来后做长 prompt 冒烟（不能只测 `1+1`，EXAONE 是 thinking 类模型）

### 环境变量（每次迭代更新）

**第1次尝试**（SOP 默认黑名单，TP=4）：
```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
```

```bash
model_name=EXAONE-4.0-32B
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/EXAONE-4.0-32B \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

**崩溃日志关键行**：
```
无崩溃，第1次（默认黑名单）直接启动成功。
INFO:     Application startup complete.
```

### 实际启动命令（v2 达标迭代，复现用）

容器内实际执行（来源：serve_v2.log `api_utils.py:273` non-default args）：

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=EXAONE-4.0-32B
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/EXAONE-4.0-32B \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v2.log
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 补充项 | 结果 | 备注 |
|------|---------------------------------|------|------|
| 第1次 | （无，使用默认） | 崩溃/成功 | |
| 第2次 | | | |

**启动成功的日志行**：
```
（贴 "Application startup complete"）
```

### 冒烟验证（EXAONE 是 thinking 模型，必须用长 prompt）

```bash
model_name=EXAONE-4.0-32B
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？请详细介绍该城市的历史沿革、人口规模和主要政治职能。"}],"max_tokens":512,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'
```

**冒烟输出节选**：
```
（贴 content 字段前100字）
```

---

## Step 4：评测

```bash
# 宿主机
docker cp /path/to/release_评测标准 EXAONE-4.0-32B_flagos:/workspace/release_评测标准

# 容器内
docker exec -it EXAONE-4.0-32B_flagos /bin/bash
cd /workspace/release_评测标准
pip install -q 'evalscope==1.5.1' requests pyyaml

model_name=EXAONE-4.0-32B
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> ⚠ EXAONE 是 thinking 模型，50 题 GPQA 可能跑数小时，不要中断。
> 若 `truncation_detected: true` → 加大 `--max-model-len` 后重跑。

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| v1（裸 vLLM） | N/A | — | — | serve.log，未另跑评测 |
| v2（plugin-FL 默认黑名单，50 题） | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **58%** (29/50) | **0（达标，noise_zone=true）** | 2026-09-15T03:05:29；小样本噪声容忍（2.0 题差 ≤ 阈值） |
| v_198（plugin-FL 默认黑名单，198 题全量） | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **63.13%** (125/198) | **0（达标，干净通过）** | 2026-09-16T09:40:08；耗时 125m 7.8s；fast_gpqa score=null，从 evalscope reviews 补计分 |

**评测参数**（v2，`gpqa_v2.json`，50 题）：
- mode=standard，temperature=0.0，max_tokens=24576，max_model_len=32768，batch_size=8
- 50 题，无截断（truncation_detected=false），无复读（runaway_count=0）
- 耗时：探测 61s + 评测 2262s = 约 39 分钟

**评测参数**（v_198，`gpqa_v_198.json`，198 题全量，metax-58）：
- mode=standard，temperature=0.0，max_model_len=32768
- 198 题全量，耗时 125m 7.8s；fast_gpqa score=null（同一解析 bug），从 `/outputs/gpqa_diamond/20260916_071142/reviews/EXAONE-4.0-32B/gpqa_diamond_default.jsonl` 补回
- 机器：metax-58 / `EXAONE-4.0-32B_flagos` / port 8000 / GPU 0-3 / TP=4

**verdict_v2.json 原文**（50 题，noise_zone 达标）：
```json
{
  "baseline_mode": "nv_reference",
  "model": "EXAONE-4.0-32B",
  "metric": "gpqa_diamond",
  "nv": { "score": 62.0, "source": "NV 实测" },
  "current": { "score": 58.0, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T03:12:12.418559",
  "rel_drop": 0.0645,
  "rel_drop_pct": 6.45,
  "abs_diff": -4.0,
  "aligned": true,
  "noise_zone": true,
  "noise_detail": "绝对差异 4.00% = 2.00 题 (每题 2.00%, 共 50 题), ≤ 2 题噪声阈值，属小样本评测方差",
  "diff_questions": 2.0,
  "noise_adjusted": true,
  "message": "精度达标(小样本噪声容忍): 当前=58.00%, NV=62.00%, 相对退化=6.45% 虽超容差 5.0%，但绝对差异 2.00 题 ≤ 2 题噪声阈值，判定达标"
}
```

**verdict_v_198.json 原文**（198 题全量，干净达标）：
```json
{
  "baseline_mode": "nv_reference",
  "model": "EXAONE-4.0-32B",
  "metric": "gpqa_diamond",
  "nv": { "score": 62.0, "source": "NV 实测" },
  "current": { "score": 63.13, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T09:40:08.306760",
  "rel_drop": -0.0182,
  "rel_drop_pct": -1.82,
  "abs_diff": 1.13,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=63.13%, NV=62.00%, 相对退化=-1.82% (容差 5.0%)"
}
```

### 逐题对错（v2，doc_id 来自 evalscope predictions）

按 `doc_id` 升序，共 50 题：

| 状态 | 题数 | doc_id 列表 |
|------|------|------------|
| ✓ 正确 | 29 | 0 1 2 4 5 6 7 9 13 14 15 16 18 19 20 25 26 27 29 35 37 38 40 41 42 44 46 47 49 |
| ✗ 错误 | 21 | 3 8 10 11 12 17 21 22 23 24 28 30 31 32 33 34 36 39 43 45 48 |

> 注：EXAONE 部分题目以 `Answer: X`（首字母大写）结尾而非全大写 `ANSWER:`，解析时已用 `re.IGNORECASE`，50 题全部成功解析。

原始 predictions 文件：`outputs/gpqa_diamond/20260915_023303/predictions/EXAONE-4.0-32B/gpqa_diamond_default.jsonl`（eval-scope 容器内）

---

## 现象

原报告 V1–V4 全空（服务 V1 就崩）。本次用 plugin-FL 默认黑名单直接起 v2 服务，`Application startup complete` 正常，长 prompt 冒烟通过。v2 GPQA 58%（29/50 题正确）。

## 定位

plugin-FL 默认黑名单覆盖了 EXAONE-4.0-32B 的崩溃算子，eager 模式下一次起成功。EXAONE 模型输出以 `Answer: X`（首字母大写，非全大写 `ANSWER:`）结尾——evalscope 内部解析正常，分数以 evalscope report 中的 `metrics[0].score` 为准（fast_gpqa parse bug 导致 JSON 里 score 字段写成 null，已通过 `_score_source` patch 修正）。精度对比 NV 62%，绝对差 2.0 题，恰在噪声阈值边界，判定达标。

## 处置

直接用 SOP 默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + `--enforce-eager`，TP=4（GPU 0,1,2,3），端口 8000（默认），`max_model_len=32768`，`mode=standard`（非 thinking）。v2 评测后用 `_score_source` 字段从 evalscope report 回填 score，再跑 accuracy_compare。

## 结果

- 修复后 GPQA 正确率：**58%** (29/50)
- NV 基线：62%
- 达标判定（accuracy_compare 退出码）：**0（达标，noise_zone=true，2.0 题差 = 噪声阈值上限）**

## 提炼到 KNOWLEDGE 的条目

EXAONE-4.0-32B 在 MetaX 上用默认黑名单 + eager 模式可一次起成功；其模型输出以 `Answer: X`（非全大写）结尾，evalscope 能正常解析，自行后处理需用 `re.IGNORECASE`。
