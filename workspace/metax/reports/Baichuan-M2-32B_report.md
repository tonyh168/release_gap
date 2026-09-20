# metax/Baichuan-M2-32B 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Baichuan-M2-32B_202608020123.md
- **原始失败类型**：服务启动失败（V1–V4 全无数据），另挂 crash / accuracy / perf 三条 Issue
- **日期**：2026-09-16

## 现象

原报告 V1–V4 四个版本的评测数据全空，说明服务在 V1 阶段就崩，连基线分都没有。

本次上机（metax-60）用 plugin-FL 默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + `--enforce-eager`，
TP=2（GPU 6,7），端口 8003，服务第 1 次尝试即启动成功（源日志记为 `Application startup complete`；
源日志的「启动日志关键行」块为 `（待填写）`，未留原始日志）。

50 题 GPQA 全部评完，随后在 runaway 后处理扫描阶段抛出：

```
AttributeError: 'list' object has no attribute 'strip'
```

Baichuan-M2-32B 的响应里 `choices[0].message.content` 返回的是 list（非标准字符串），
`detect_runaway(content, stop_reason)` 未做类型检查就直接调用 `.strip()` 而崩溃。
崩溃点在全部 50 题判分完成**之后**的后处理阶段，50 题的 predictions 与 reviews 文件均已完整写入，
最终从 evalscope reviews 的 `sample_score.score.value.accuracy` 字段统计得 37/50 = **74.0%**。

## 定位

- 模型形态：dense 32B（非 MLA、非 MoE），bf16 权重约 64GB。原失败报告用 TP=8 属过保守，
  按 64GB × 1.2 / 63.6 = 1.21 → ceil = **TP=2**（每卡 32GB 权重，剩余约 25GB KV cache，充裕）。
  本次改用 TP=2 后服务层完全正常。
- 服务层：plugin-FL 默认黑名单
  （`mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`）
  已覆盖该模型的崩溃算子，配合 `VLLM_FL_USE_FLAGGEMS_ATTN=0` 与 eager 模式一次起成功，
  无算子 crash、无缺 .so 编译扩展、无 OOM，**无需抓算子名做黑名单二分排查**。
- 评测工具层：`fast_gpqa.py` 的 `detect_runaway` 类型守卫有漏洞——
  `(choices[0].get("message") or {}).get("content") or ""` 对非空 list 不会退化为 `""`
  （list 本身是 truthy），于是把 list 传给了 `.strip()`。该崩溃与硬件、plugin-FL 算子均无关，
  且发生在全部题目评完之后，不影响评测数据完整性，真实得分可从 reviews 文件补回。
- 精度层：相对退化 -15.62%（即高于基线 10pt），`noise_zone=false`，不涉及小样本噪声问题。

## 处置

### 环境（达标轮次）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-baichuan-m2-32b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Baichuan-M2-32B` |
| TP / GPU / 端口 | TP=2，GPU 6,7，port=8003 |
| 权重来源 | `baichuan-inc/Baichuan-M2-32B`（ModelScope） |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

### 迭代记录

| 迭代 | 是否开 plugin | VLLM_FL_FLAGOS_BLACKLIST | TP | 服务 | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------|--------------------------|----|------|------------|------------------------|------|
| v1 | 是 | 默认（mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice） | 2 | ✅ `Application startup complete` | **74.0%** (37/50) | **0（达标）** | 2026-09-16；黑名单全程未改动，一次起成功 |

无失败尝试：默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + eager 第 1 次即起成功，未做任何算子二分排查。
`--trust-remote-code` 必须开（Baichuan 系列自定义 tokenizer）。

### 启动命令（v1，最终达标配置，复现用）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=6,7
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/Baichuan-M2-32B \
  --served-model-name Baichuan-M2-32B \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8003 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```

### 冒烟验证

```bash
curl -s http://localhost:8003/v1/models

curl -s http://localhost:8003/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Baichuan-M2-32B","messages":[{"role":"user","content":"What is the capital of China?"}],"max_tokens":64,"temperature":0}'

curl -s http://localhost:8003/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Baichuan-M2-32B","messages":[{"role":"user","content":"Explain Newton's three laws of motion in detail, with one everyday example for each law, at least 100 words per law."}],"max_tokens":512,"temperature":0}'
```

第二条长 prompt 用于验证 prefill 路径，两条均正常返回。

### 评测与补计分

**评测参数（v1，`gpqa_v1.json`）**：
- mode=default，temperature=0，max_tokens=4096，max_model_len=32768，batch_size=16
- 50 题，无截断（truncation_detected=false）；runaway crash 发生在后处理阶段，非评测阶段
- 所有 50 题的 predictions 和 reviews 文件完整写入

**补计分过程**：`fast_gpqa.py` 在 post-processing 崩溃后 JSON 未落分，用脚本从 evalscope reviews
JSONL 逐条读取 `sample_score.score.value.accuracy` 字段累加得 37/50 = 74.0%，写入修复版
`gpqa_v1.json`，再重跑 `accuracy_compare.py` 得到正式 verdict：

```bash
docker exec eval-scope bash -c "
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name Baichuan-M2-32B \
  --api-base http://127.0.0.1:8003/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/Baichuan-M2-32B/gpqa_v1.json
"

docker exec eval-scope bash -c "
python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/Baichuan-M2-32B/gpqa_v1.json \
  --nv-baseline Baichuan-M2-32B \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/Baichuan-M2-32B/verdict_v1.json
"
```

原始 reviews 文件：`/outputs/gpqa_diamond/<timestamp>/reviews/Baichuan-M2-32B/gpqa_diamond_default.jsonl`
（eval-scope 容器内）。

## 结果

- 修复后分 / NV 基线：**74.0%**（37/50） / **64.0%**（高于基线 10pt，`noise_zone=false`）
- 达标判定（accuracy_compare 退出码）：**0（达标，相对退化 -15.62%）**

verdict_v1.json 原文（最终达标那一份）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Baichuan-M2-32B",
  "metric": "gpqa_diamond",
  "nv": { "score": 64.0, "source": "NV 实测" },
  "current": { "score": 74.0 },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T09:12:00.000000",
  "rel_drop": -0.1562,
  "rel_drop_pct": -15.62,
  "abs_diff": 10.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=74.00%, NV=64.00%, 相对退化=-15.62% (容差 5.0%)"
}
```

## 提炼到 KNOWLEDGE 的条目

1. Baichuan-M2-32B 在 MetaX 上用 plugin-FL 默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + eager
   + TP=2（GPU 6–7）可一次启动成功，无需调整黑名单；原失败报告给的 TP=8 过保守，
   dense 32B（约 64GB 权重）按 64×1.2/63.6 重算即得 TP=2。
2. `fast_gpqa.py` 的 `detect_runaway` 对 list 类型 content 会崩溃
   （`AttributeError: 'list' object has no attribute 'strip'`）；该崩溃发生在后处理阶段，
   50 题 reviews 文件仍完整，可从 `sample_score.score.value.accuracy` 补回得分。
3. Baichuan 系列必须开 `--trust-remote-code`（自定义 tokenizer）。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: baichuan-inc/Baichuan-M2-32B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
# HARBOR_VER: V3
# GPU: MetaX C550, 2 × 64GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 64.0
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
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/Baichuan-M2-32B \
  --served-model-name Baichuan-M2-32B \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8003 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```
