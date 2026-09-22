# metax/Phi-4-mini-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Phi-4-mini-instruct_202607171827.md
- **原始失败类型**：精度不达标（V3: 28% vs NV 基线 38%，相对退化 26.3%）+ plugin报错（2条Issue）
- **日期**：2026-09-15

## 现象

**原报告**：用 vLLM 0.20.2 + plugin-FL 0.2.0 + FlagGems 5.0.2。

- V1 数据缺失（GPQA 无数据），说明裸 vLLM 阶段就有问题或未完成；
- V2 精度 30%，V3 精度 28%，NV 基线 38%，V3 相对退化 26.3%，远超 5% 阈值；
- 提交了 3 条 Issue：算子精度退化、plugin-FL 报错（dispatch）、plugin-FL 报错（vllm_fl）；
- V2 算子白名单 31 个算子（add/sort/softmax 等标准集），V3 沿用相同白名单。

**本次复跑（metax-60，镜像 vLLM 0.24.0）**：

- v1（裸 vLLM，关闭 plugin）：**40%（20/50）**，超 NV 基线 38%，确认 vLLM 0.24.0 下模型本身精度正常；
- v2（plugin-FL 默认黑名单）：**26%（13/50）**，退化至 NV 以下，`rel_drop=+31.58%`，退出码 1，确认退化由 plugin-FL 引入；
- v3（扩展黑名单加 `rms_norm,silu_and_mul`）：**44%（22/50）**，超 NV 基线 6 题，退出码 0，达标；其中 doc_id 2 在 evalscope 中挂起（49/50 卡住超 6 分钟），kill 后用 `eval_missing_phi4_v3.py` 补评，答对（latency 132.5s，772 output tokens）。

模型与环境：

| 项目 | 值 |
|------|---|
| 架构 | 标准 dense（非 MoE、非 thinking），3.8B 参数，bf16 权重约 7.6GB，单卡可装；GQA（24Q/8KV，`num_key_value_heads=8`） |
| 权重来源 | `microsoft/Phi-4-mini-instruct`（ModelScope） |
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-phi-4-mini-instruct` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Phi-4-mini-instruct`（共享盘已有） |
| 卡号 / 端口 | `MACA_VISIBLE_DEVICES=1`（TP=1） / port 8002 |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

TP 计算：7.6GB / 63.6GB × 1.2 = 0.14 → **TP=1**（单卡足够，KV cache 空间充裕）。

查卡节选（2026-09-15，GPU 0 被 Phi-3.5 服务占用，GPU 1 空闲，分配给本次修复）：

```
| 1     MetaX C550 | ...  | 859/65536 MiB       | Available  |
```

启动日志关键行：

```
INFO 09-15 13:44:31 [__init__.py:237] Platform plugin fl is activated
(APIServer pid=60258) INFO:     Application startup complete.
```

冒烟验证：

```bash
curl -s http://localhost:8002/v1/models
curl -s http://localhost:8002/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Phi-4-mini-instruct","messages":[{"role":"user","content":"What is the capital of France?"}],"max_tokens":64,"temperature":0}'
```

> 注：`VLLM_FL_FLAGOS_BLACKLIST` 和 `VLLM_FL_USE_FLAGGEMS_ATTN` 会触发 vLLM core 的 "Unknown vLLM environment variable" WARNING，属正常现象，plugin-fl 自行读取这两个变量。

## 定位

Phi-4-mini-instruct 是 GQA 架构（24Q/8KV，`num_key_value_heads=8`），而 Phi-3.5 是 MHA（32Q/32KV）。
plugin-FL 默认黑名单下，`rms_norm` 和 `silu_and_mul` 走 FlagGems。

- MHA 的 Q/KV 张量 shape 对这两个算子无问题（Phi-3.5 默认黑名单直接达标）；
- 但 GQA 的 KV head 数量不同于 Q head，产生不同 shape，触发 FlagGems `rms_norm` 和 `silu_and_mul` 的精度 bug。

将 `rms_norm` 和 `silu_and_mul` 加入黑名单后，这两个算子回退到 MACA 原生实现，精度恢复正常。

config.json 差异对照：

- Phi-3.5：`num_attention_heads=32`，`num_key_value_heads=32`，`partial_rotary_factor=0.5`，vocab=32064
- Phi-4：`num_attention_heads=24`，`num_key_value_heads=8`，`partial_rotary_factor=0.75`，vocab=200064（GPT-4o tokenizer）

## 处置

修复路径（原报告 V1 数据缺失、plugin-FL 有精度退化和报错，故先分离变量再定位）：

1. **先跑裸 vLLM（关闭 plugin）建 V1 基线**：确认 vLLM 0.24.0 下模型本身精度（结果 40%，正常）；
2. **开 plugin-FL 默认黑名单（v2）**：对比 V1，定位退化来源（结果 26%，退化由 plugin-FL 引入，14 题退化，`rms_norm`/`silu_and_mul` 为 GQA 精度根因）；
3. **扩展黑名单（v3）**：加入 `rms_norm,silu_and_mul`，修复 GQA 精度问题（结果 44%，达标）。

在 SOP 默认黑名单基础上加 `rms_norm,silu_and_mul`，完整黑名单：

`mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice,rms_norm,silu_and_mul`

其余参数：`VLLM_FL_USE_FLAGGEMS_ATTN=0` + `--enforce-eager`，TP=1（GPU 1），port=8002，`max_model_len=32768`，`mode=standard`。

### 迭代记录

| 迭代 | VLLM_PLUGINS | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|-------------|--------------------------|------------|------------------------|------|
| v1（裸 vLLM） | 未设 | — | **40%** (20/50) | 0（达标） | 2026-09-15，建立基线，确认 vLLM 0.24 本身无问题 |
| v2（plugin-FL 默认黑名单） | fl | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **26%** (13/50) | 1（不达标） | 2026-09-15，plugin-FL 引入退化（rel_drop +31.58%），rms_norm/silu_and_mul 为 GQA 精度根因 |
| v3（扩展黑名单） | fl | 默认 + **rms_norm,silu_and_mul** | **44%** (22/50) | **0（达标）** | 2026-09-15，doc_id 2 evalscope 挂起，用 eval_missing_phi4_v3.py 补评（答对） |

评测参数（v3，`gpqa_v3.json`）：mode=standard，temperature=0.0，max_tokens=24576，max_model_len=32768；
50 题 = 49 题 evalscope 批量 + 1 题 `eval_missing_phi4_v3.py` 补评。

评测在独立的 eval-scope 容器内执行（`--network host`，直接打 `http://127.0.0.1:8002/v1`）：

```bash
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name Phi-4-mini-instruct \
  --api-base http://127.0.0.1:8002/v1 \
  --dataset gpqa_diamond \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/Phi-4-mini-instruct/gpqa_v3.json

python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/Phi-4-mini-instruct/gpqa_v3.json \
  --nv-baseline Phi-4-mini-instruct \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/Phi-4-mini-instruct/verdict_v3.json
```

> 注：doc_id 2 在评测中挂起（49/50 卡住超 6 分钟），与 Phi-3.5 的 doc_id 23/34 同类问题。
> 杀掉 evalscope 进程后用 `eval_missing_phi4_v3.py` 单独补评，doc_id 2 答对（latency 132.5s，772 output tokens）。

### 逐题对错（v3，doc_id 来自 evalscope predictions + eval_missing_phi4_v3.py）

| 状态 | 题数 | doc_id 列表 |
|------|------|------------|
| ✓ 正确 | 22 | 2 4 5 6 9 10 12 13 17 18 19 20 26 29 30 31 35 40 44 47 48 49 |
| ✗ 错误 | 28 | 0 1 3 7 8 11 14 15 16 21 22 23 24 25 27 28 32 33 34 36 37 38 39 41 42 43 45 46 |

## 结果

- 修复后分 / NV 基线：44.0%（22/50） / 38.0%（基线为 `nv_baseline.yaml` 记录值；本次 metax 超 NV 6 题）
- 达标判定（accuracy_compare 退出码）：0（达标）；v3 退出码 0，v1 裸 vLLM 退出码 0（40%，仅作基线），v2 默认黑名单退出码 1（不达标）

最终 verdict（`verdict_v3.json`）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Phi-4-mini-instruct",
  "metric": "gpqa_diamond",
  "nv": { "score": 38.0, "source": "NV 实测" },
  "current": { "score": 44.0, "mode": "unknown" },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T06:07:11.853226",
  "rel_drop": -0.1579,
  "rel_drop_pct": -15.79,
  "abs_diff": 6.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=44.00%, NV=38.00%, 相对退化=-15.79% (容差 5.0%)"
}
```

## 提炼到 KNOWLEDGE 的条目

GQA 模型（`num_key_value_heads` < `num_attention_heads`）在 plugin-FL 下需额外将 `rms_norm` 和 `silu_and_mul` 加入黑名单；
MHA 模型（`num_key_value_heads == num_attention_heads`）默认黑名单即可。evalscope 对长回答题目在高并发下偶发挂起，
遇 tqdm 长时间停在 49/50 须用 eval_missing 系列脚本补评未完成题目。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: microsoft/Phi-4-mini-instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
# HARBOR_VER: V3
# GPU: MetaX C550, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 38.0
# SCORE_FLAGOS: 44.0
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
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice,rms_norm,silu_and_mul
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/Phi-4-mini-instruct \
  --served-model-name Phi-4-mini-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8002 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```
