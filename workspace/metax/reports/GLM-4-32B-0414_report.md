# metax/GLM-4-32B-0414 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_GLM-4-32B-0414_202608070851.md
- **原始失败类型**：服务启动失败 + 精度不达标（rel_drop 超阈值）
- **日期**：2026-09-14

## 现象

原报告中 V1–V4 的评测数据全空，说明服务在 V1 阶段就崩了；Issues 同时列了三条：
`Operator crash`、`Operator accuracy degradation`、`Operator performance degradation`——
即原报告里即使有版本把服务起来，精度和性能也不达标，属综合性难题。

本次上机（metax-60）按 plugin-FL 默认黑名单起服务，日志无崩溃：

```
INFO:     Application startup complete.
```

长 prompt 冒烟通过。50 题 GPQA 得 **52%（26/50）**，低于 NV 基线 55%，相对退化 5.45%，
虽已超出 5% 容差线，但绝对差仅 1.50 题（≤ 2 题噪声阈值），`noise_zone=true`，
按小样本噪声容忍判定达标。

## 定位

- 模型形态：GLM-4-32B-0414 为 dense 32B（bf16 约 64GB），GLM 特有 RoPE + 双流 attention 架构。
  单卡 63.6GB 放不下 → **TP=2**（127.2GB，预留后可用约 89GB）。原报告显示 9 卡属意外情况（通常 8 卡）。
- 服务层：plugin-FL 默认黑名单
  （`mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`）
  已覆盖 GLM-4 的崩溃算子，配合 `VLLM_FL_USE_FLAGGEMS_ATTN=0` 与 `--enforce-eager`，
  第 1 次尝试即启动成功，**没有出现 Operator crash，也无需抓算子名做黑名单二分排查**；
  无缺 .so 编译扩展、无 OOM。
- 精度层：对比 NV 基线 55%，绝对差 1.5 题（每题 2.00%，共 50 题），落在小样本评测方差区间内，
  `noise_adjusted=true`；非算子精度退化（若为退化，黑名单需按 Phi-4 经验补 `rms_norm,silu_and_mul`）。
- 评测工具层：`truncation_detected=false`、`runaway_count=0`，predictions/reviews 完整，无需补计分。

## 处置

### 环境（达标轮次）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `GLM-4-32B-0414_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/GLM-4-32B-0414` |
| TP / GPU / 端口 | TP=2，GPU 0,1，port=8003 |
| 权重来源 | `zai-org/GLM-4-32B-0414`（ModelScope） |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

### 迭代记录

| 迭代 | 是否开 plugin | VLLM_FL_FLAGOS_BLACKLIST | TP / 端口 | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------|--------------------------|-----------|------------|------------------------|------|
| 第1次 | 否（V1 基线） | N/A | TP=4 / 8000 | — | — | serve_v1.log，裸 vLLM 验证可用性，未跑评测 |
| v2 | 是 | 默认（mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice） | TP=2 / 8003 | **52%** (26/50) | **0（达标，noise_zone=true）** | 2026-09-15T02:46:07；默认黑名单一次起成功，黑名单全程未改动 |

原计划的第三阶段（用二分法定位精度退化算子）**未执行**——默认黑名单下服务一次起成功、
精度落在噪声区内，无需二分；黑名单最终与 SOP 默认值完全一致。

### 启动命令（v2，最终达标配置，复现用）

来源：serve_v2.log `api_utils.py:273` non-default args。

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0,1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
/opt/conda/bin/vllm serve /models/GLM-4-32B-0414 \
  --served-model-name GLM-4-32B-0414 \
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
  -d '{"model":"GLM-4-32B-0414","messages":[{"role":"user","content":"Introduce China's capital city, covering its history, population size and main political functions."}],"max_tokens":256,"temperature":0}'
```

### 评测

评测在 vLLM 同机容器 `GLM-4-32B-0414_flagos` 内执行，脚本目录为容器内的
/workspace/release_评测标准（源日志记录），产物落 `/models/release_run_logs/GLM-4-32B-0414/`：

```bash
docker exec GLM-4-32B-0414_flagos bash -c "
python3 fast_gpqa.py \
  --model-name GLM-4-32B-0414 \
  --api-base http://127.0.0.1:8003/v1 \
  --output /models/release_run_logs/GLM-4-32B-0414/gpqa_v2.json
"

docker exec GLM-4-32B-0414_flagos bash -c "
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/GLM-4-32B-0414/gpqa_v2.json \
  --nv-baseline GLM-4-32B-0414 \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/GLM-4-32B-0414/verdict_v2.json
"
```

**评测参数（v2，`gpqa_v2.json`）**：
- mode=standard，temperature=0.0，max_tokens=24576，max_model_len=32768，batch_size=8
- 50 题，无截断（truncation_detected=false），无复读（runaway_count=0）
- 耗时：探测 66s + 评测 1095s ≈ 19 分钟

**逐题对错（v2，doc_id 来自 evalscope predictions，按 doc_id 升序，共 50 题）**：

| 状态 | 题数 | doc_id 列表 |
|------|------|------------|
| ✓ 正确 | 26 | 0 1 2 4 5 7 11 12 13 14 16 17 18 19 23 26 31 32 35 37 38 39 41 46 47 48 |
| ✗ 错误 | 24 | 3 6 8 9 10 15 20 21 22 24 25 27 28 29 30 33 34 36 40 42 43 44 45 49 |

原始 predictions 文件：`outputs/gpqa_diamond/20260915_023318/predictions/GLM-4-32B-0414/gpqa_diamond_default.jsonl`
（eval-scope 容器内）。

## 结果

- 修复后分 / NV 基线：**52%**（26/50） / **55.0%**（差 1.50 题，`noise_zone=true`，属小样本噪声容忍达标）
- 达标判定（accuracy_compare 退出码）：**0（达标，噪声容忍；相对退化 5.45% 超 5% 容差，但绝对差 1.50 题 ≤ 2 题噪声阈值）**

verdict_v2.json 原文（最终达标那一份）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "GLM-4-32B-0414",
  "metric": "gpqa_diamond",
  "nv": { "score": 55.0, "source": "NV 实测" },
  "current": { "score": 52.0, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T02:52:16.303372",
  "rel_drop": 0.0545,
  "rel_drop_pct": 5.45,
  "abs_diff": -3.0,
  "aligned": true,
  "noise_zone": true,
  "noise_detail": "绝对差异 3.00% = 1.50 题 (每题 2.00%, 共 50 题), ≤ 2 题噪声阈值，属小样本评测方差",
  "diff_questions": 1.5,
  "noise_adjusted": true,
  "message": "精度达标(小样本噪声容忍): 当前=52.00%, NV=55.00%, 相对退化=5.45% 虽超容差 5.0%，但绝对差异 1.50 题 ≤ 2 题噪声阈值，判定达标"
}
```

## 提炼到 KNOWLEDGE 的条目

GLM-4-32B-0414 在 MetaX 上用 plugin-FL 默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + eager 模式
可一次起成功，无需额外补充黑名单条目（GLM 特有 RoPE + 双流 attention 未引入额外 crash 算子）。
另外，相对退化超 5% 但绝对差 ≤ 2 题时应以 `noise_zone` 判定为准，不要直接判不达标。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: zai-org/GLM-4-32B-0414
# IMAGE: harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
# HARBOR_VER: V3
# GPU: MetaX C550, 2 × 64GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 55.0
# SCORE_FLAGOS: 52.0
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
/opt/conda/bin/vllm serve /models/GLM-4-32B-0414 \
  --served-model-name GLM-4-32B-0414 \
  --dtype bfloat16 \
  --tensor-parallel-size 2 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8003 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```
