# metax/EXAONE-4.0-32B 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_EXAONE-4.0-32B_202608070744.md
- **原始失败类型**：服务启动失败（Operator crash）
- **日期**：2026-09-14

## 现象

原报告中 V1–V4 所有评测数据均为空，说明服务在 V1 阶段（裸 vLLM）就起不来，连基线都没有，
原始 Issue 标题为 `Operator crash on 沐曦(Metax) (LGAI-EXAONE/EXAONE-4.0-32B)`。

本次在 plugin-FL 镜像上按 SOP 默认黑名单起服务，第 1 次尝试即启动成功，无任何算子崩溃：

```
No crash. First attempt (default blacklist) started successfully.
INFO:     Application startup complete.
```

长 prompt 冒烟（EXAONE 不能只测 `1+1`）通过。第 1 轮 **v2（50 题）** 的 GPQA 得 58%（29/50），
比 NV 基线 62% 低 4pt，落入小样本噪声区间（rel_drop 6.45% 超容差，但绝对差 2.0 题 = 噪声阈值），
属小样本容忍达标；随后第 2 轮 **v_198（198 题全量）** 得 63.13%（125/198），
`noise_zone=false` 干净达标（见「结果」）。

## 定位

- 模型形态：EXAONE-4.0-32B 为 MoE 架构（32B 总参，非稠密），attention 实现**可能**用了 MLA
  变体，需特别注意 `--attention-backend` 与 `VLLM_FL_USE_FLAGGEMS_ATTN` 的设置；
  权重文件约 64GB → 采用 **TP=4** 留足 KV cache 空间（EXAONE 类模型 TP=2 实测 KV cache OOM）。
- 服务层：plugin-FL 默认黑名单（`mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice`）
  已完整覆盖 EXAONE-4.0-32B 的崩溃算子，配合 `VLLM_FL_USE_FLAGGEMS_ATTN=0` 与 `--enforce-eager`，
  eager 模式下一次起成功，**无需抓算子名做黑名单二分排查**。
- 精度层：**v2（50 题轮）** 仅差 2.0 题即触达噪声阈值边界（`noise_zone=true`），因此不能以 50 题结果定论，
  必须重跑 198 题全量排除噪声；**v_198（198 题全量轮）** 结果为 `noise_zone=false` 干净达标。
- 评测工具层：`fast_gpqa.py` 对本模型写出 `score=null`（解析 bug），需从 evalscope reviews 的
  `sample_score.score.value.accuracy` 回填分数后再跑 `accuracy_compare.py`。EXAONE 输出以
  `Answer: X` 结尾（首字母大写，**非**全大写 `ANSWER:`），evalscope 内部解析正常，
  自行后处理需使用 `re.IGNORECASE`。

## 处置

### 环境（达标轮次）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-58`（198 题全量达标轮次；源日志环境表另记 metax-60，以评测记录为准） |
| 容器名 | `EXAONE-4.0-32B_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/EXAONE-4.0-32B` |
| TP / GPU / 端口 | TP=4，GPU 0,1,2,3，port=8000 |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |
| 权重来源 | `LGAI-EXAONE/EXAONE-4.0-32B`（ModelScope） |

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| v1（裸 vLLM） | N/A | — | — | serve.log，未另跑评测 |
| v2（plugin-FL 默认黑名单，50 题） | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **58%** (29/50) | **0（达标，noise_zone=true）** | 2026-09-15T03:05:29；小样本噪声容忍（2.0 题差 ≤ 阈值） |
| v_198（plugin-FL 默认黑名单，198 题全量） | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **63.13%** (125/198) | **0（达标，干净通过）** | 2026-09-16T09:40:08；耗时 125m 7.8s；fast_gpqa score=null，从 evalscope reviews 补计分 |

未做失败尝试：默认黑名单第 1 次即起成功，黑名单全程未改动，两轮评测用同一套算子配置。

### 启动命令（v2 起，最终达标配置，复现用）

来源：serve_v2.log `api_utils.py:273` non-default args。

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
/opt/conda/bin/vllm serve /models/EXAONE-4.0-32B \
  --served-model-name EXAONE-4.0-32B \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```

### 冒烟验证（thinking 类模型必须用长 prompt）

```bash
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"EXAONE-4.0-32B","messages":[{"role":"user","content":"Explain the historical development, population size and main political functions of China's capital city."}],"max_tokens":512,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'
```

### 评测

评测在起 vLLM 的同一台宿主机上的独立 eval 容器内执行，`max_model_len=32768`、`mode=standard`（非 thinking）。

**评测参数（v2，`gpqa_v2.json`，50 题）**：
- mode=standard，temperature=0.0，max_tokens=24576，max_model_len=32768，batch_size=8
- 无截断（truncation_detected=false），无复读（runaway_count=0）
- 耗时：探测 61s + 评测 2262s ≈ 39 分钟

**评测参数（v_198，`gpqa_v_198.json`，198 题全量）**：
- mode=standard，temperature=0.0，max_model_len=32768
- 耗时 125m 7.8s；198 题全量，truncation_detected=false
- 机器：metax-58 / `EXAONE-4.0-32B_flagos` / port 8000 / GPU 0-3 / TP=4

**score=null 的补计分过程**：`fast_gpqa.py` 跑完后 JSON 里 `score` 字段写成 null（解析 bug），
predictions/reviews 文件均完整。用 `_score_source` patch 从 evalscope reviews 逐条的
`sample_score.score.value.accuracy` 累加得分，回填到 result JSON 后再跑 `accuracy_compare.py`
得到正式 verdict：

```bash
python3 fast_gpqa.py --model-name EXAONE-4.0-32B \
  --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/EXAONE-4.0-32B/gpqa.json

python3 accuracy_compare.py \
  --v2 /models/release_run_logs/EXAONE-4.0-32B/gpqa.json \
  --nv-baseline EXAONE-4.0-32B \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/EXAONE-4.0-32B/verdict.json
```

补计分所用的 reviews 文件：
`/outputs/gpqa_diamond/20260916_071142/reviews/EXAONE-4.0-32B/gpqa_diamond_default.jsonl`（eval-scope 容器内）。

**逐题对错（v2，50 题，doc_id 来自 evalscope predictions，按 doc_id 升序）**：

| 状态 | 题数 | doc_id 列表 |
|------|------|------------|
| ✓ 正确 | 29 | 0 1 2 4 5 6 7 9 13 14 15 16 18 19 20 25 26 27 29 35 37 38 40 41 42 44 46 47 49 |
| ✗ 错误 | 21 | 3 8 10 11 12 17 21 22 23 24 28 30 31 32 33 34 36 39 43 45 48 |

原始 predictions：`outputs/gpqa_diamond/20260915_023303/predictions/EXAONE-4.0-32B/gpqa_diamond_default.jsonl`（eval-scope 容器内）。

**v2 verdict 原文（50 题，noise_zone 达标，仅作过程记录）**：

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

## 结果

本模型有**两轮**评测记录，发布口径取更晚、更干净的 198 题全量那一轮：

- **v2（50 题轮，2026-09-15）**：修复后分 **58%（29/50）** / NV 基线 **62.0%**；
  达标判定（accuracy_compare 退出码）：**0（达标，noise_zone=true）**——相对退化 6.45% 虽超 5% 容差，
  但绝对差 2.0 题 = 噪声阈值上限，按小样本噪声容忍规则达标。
- **v_198（198 题全量轮，2026-09-16）**：修复后分 / NV 基线：**63.13%**（125/198，198 题全量） / **62.0%**；
  达标判定（accuracy_compare 退出码）：**0（干净通过，noise_zone=false，相对退化 -1.82%，即高于基线 1.13pt）**。
- **发布取 v_198（198 题全量）这一轮**：50 题轮只是噪声边界上的过程记录，198 题全量排除了小样本噪声，
  结论更干净、样本量更大，故 `SCORE_FLAGOS` 采用 **63.13**（与 `workspace/metax/STATUS.md` 一致）。
- 需注意：源日志 `fixes/EXAONE-4.0-32B.md` 的「## 结果」节**只写到 v2（50 题）的 58%，未同步到 198 题轮**；
  198 题轮的结果记录在源日志的评测迭代表与 `verdict_v_198.json` 原文中。

verdict.json 原文（最终达标那一份，v_198，198 题全量）：

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

## 提炼到 KNOWLEDGE 的条目

EXAONE-4.0-32B 在 MetaX 上用 plugin-FL 默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + eager 模式
可一次起成功，无需对被猜测的 crash 算子做二分排查；该模型输出以 `Answer: X`（首字母大写，
非全大写 `ANSWER:`）结尾，evalscope 能正常解析，但自行后处理必须用 `re.IGNORECASE`。
另外，50 题结果落在噪声阈值边界时不可直接定论，应重跑 198 题全量排除噪声再判定。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: LGAI-EXAONE/EXAONE-4.0-32B
# IMAGE: harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
# HARBOR_VER: V3
# GPU: MetaX C550, 4 × 64GB
# TP: 4
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 62.0
# SCORE_FLAGOS: 63.13
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
/opt/conda/bin/vllm serve /models/EXAONE-4.0-32B \
  --served-model-name EXAONE-4.0-32B \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```
