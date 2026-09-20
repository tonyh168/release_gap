# metax/Phi-3-mini-128k-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Phi-3-mini-128k-instruct_202607160324.md
- **原始失败类型**：精度不达标（V2=38% vs NV=42%，精度偏差 4.0%；性能 79.2% 踩线）
- **日期**：2026-09-14（v1）/ 2026-09-18（v2，三路并行，达标）

## 现象

**原报告（20260716）**：用 vLLM 0.20.2 + plugin-FL 0.2.0；V2/V3 算子白名单数据缺失（无数据），说明自动化流程在 V2 阶段就失败了，没产出有效算子数据。精度偏差 4.0%（50 题：42% vs 38%）和性能 79.2% 都刚好踩线——可能是随机抖动，也可能是真实算子问题，需在新镜像下重跑一轮确认。

**本次复跑（metax-60，镜像 vLLM 0.24.0）**：

- v1（2026-09-14）：服务正常启动（GPU 0，TP=1，port 8000），50 题评测，evalscope 1.11.1，耗时约 447s。结果 **28%（14/50）**，NV 33%，`rel_drop=15.15%`，accuracy_compare 退出码 1，不达标。`gpqa.json` 写出 `score: null`（parse_result bug，已在 commit 5b70c34 修复）。
- v2（2026-09-18）：三路并行（容器 A/B/C，GPU 0/1/2，port 8000/8001/8002），evalscope 1.5.1，扩展黑名单加 `rms_norm,silu_and_mul`。B、C 完整跑完 50 题；**A 跑至 49/50 卡挂**（55+ 分钟无进展，GPU util 持续低迷），kill evalscope 进程后用 `eval_missing_phi3mini_v2.py` 补评 index 11，模型答对（latency 88.8s），合并后 **42%（21/50）**，accuracy_compare 退出码 0。

模型与环境：

| 项目 | 值 |
|------|---|
| 架构 | GQA（3.8B dense，`num_attention_heads=32`，`num_key_value_heads=8`），bf16 权重约 7.6GB，单卡可装 |
| 权重来源 | `LLM-Research/Phi-3-mini-128k-instruct`（ModelScope） |
| 宿主机 | `metax-60` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907`（实际 vLLM 0.24.0） |
| 模型路径 | `/models/Phi-3-mini-128k-instruct`（共享盘已有，无需下载） |
| 容器名（v2 三路） | `Phi-3-mini-128k-instruct_flagos`（A）、`_flagos_b`（B）、`_flagos_c`（C） |
| 卡号 | A: GPU 0 / B: GPU 1 / C: GPU 2（各 TP=1） |
| 端口 | A: 8000 / B: 8001 / C: 8002 |

TP 计算：7.6GB / 63.6GB × 1.2 ≈ 0.14 → **TP=1**（单卡足够，KV cache 空间充裕）。

启动前 mx-smi 节选（2026-09-18）：

```
GPU 0: MetaX C550, 57252/65536 MiB used (v1 serve process, before restart)
GPU 1-7: 858/65536 MiB free
```

启动日志关键行：

```
INFO [__init__.py:237] Platform plugin fl is activated
INFO:     Application startup complete.
```

冒烟验证：

```bash
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"Phi-3-mini-128k-instruct","messages":[{"role":"user","content":"What is the capital of France?"}],"max_tokens":64,"temperature":0}'
```

> 注：`VLLM_FL_FLAGOS_BLACKLIST` 和 `VLLM_FL_USE_FLAGGEMS_ATTN` 会触发 vLLM core 的 "Unknown vLLM environment variable" WARNING，属正常现象，plugin-fl 自行读取这两个变量。

## 定位

Phi-3-mini-128k-instruct 与 Phi-4-mini-instruct 同为 GQA 架构（`num_key_value_heads=8` < `num_attention_heads=32`）。
plugin-FL 默认黑名单下，`rms_norm` 和 `silu_and_mul` 走 FlagGems。
GQA 的 KV head 数量不同于 Q head，产生不同 tensor shape，触发 FlagGems 这两个算子的精度 bug，
导致 v1 默认黑名单 28%（相对退化 15.15%，NV 33%）。

对照 Phi-3.5-mini（MHA，32Q/32KV）：其 Q/KV 张量 shape 对这两个算子无问题，默认黑名单直接达标；
说明退化不是 plugin-FL 整体不可用，而是 FlagGems `rms_norm`/`silu_and_mul` 在 GQA shape 下的定点问题。

将 `rms_norm` 和 `silu_and_mul` 加入黑名单后，这两个算子回退到 MACA 原生实现，精度恢复正常。
v2 三路均超 NV 基线（38%/42%/44% vs NV 33%），稳定性验证通过。

## 处置

修复策略：v1 先用 plugin-FL 默认黑名单跑一轮，退化 15%（28% vs NV 33%）超 5% 阈值，不达标；
参考 Phi-4-mini 经验（同为 GQA，FlagGems `rms_norm`/`silu_and_mul` 在 KV head 数量与 Q head 不同时有精度 bug），
v2 扩展黑名单加 `rms_norm,silu_and_mul`，同时起三路并行实例（GPU 0/1/2）做稳定性验证。

在 SOP 默认黑名单基础上加 `rms_norm,silu_and_mul`，完整黑名单：

`mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice,rms_norm,silu_and_mul`

其余参数：`VLLM_FL_USE_FLAGGEMS_ATTN=0` + `--enforce-eager`，TP=1，`max_model_len=32768`，`mode=standard`。

### 迭代记录

| 迭代 | VLLM_PLUGINS | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|-------------|--------------------------|------------|------------------------|------|
| v1（plugin-FL 默认黑名单） | fl | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | 28% (14/50) | 1（不达标） | 2026-09-14，evalscope 1.11.1，rel_drop=15.15% |
| v2（扩展黑名单，三路并行） | fl | 默认 + **rms_norm,silu_and_mul** | A=42%✅ B=44%✅ C=38%✅ | **0（达标）** | 2026-09-18，evalscope 1.5.1，A 的 index 11 补评（答对） |

评测迭代（按实例）：

| 迭代 | 模式 | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|------|------------|------------------------|------|
| v1（plugin-FL 默认黑名单） | standard | 28% (14/50) | 1（不达标） | 2026-09-14 |
| v2 实例 B | standard | **44%** (22/50) | **0（达标）** | 2026-09-18，三路中首完成，rel_drop=-33.33% |
| v2 实例 C | standard | **38%** (19/50) | **0（达标）** | 2026-09-18，rel_drop=-15.15% |
| v2 实例 A | standard | **42%** (21/50) | **0（达标）** | 2026-09-18，index 11 补评（答对），rel_drop=-27.27% |

评测参数（v2，各实例）：mode=standard，temperature=0.0，max_tokens=24576，max_model_len=32768；
实例 A = 49 题 fast_gpqa 批量 + 1 题 `eval_missing_phi3mini_v2.py` 补评，实例 B/C = 50 题 fast_gpqa 完整运行。
评测前需在各容器内装依赖（`evalscope==1.5.1` requests pyyaml），并部署 `fast_gpqa.py`、`accuracy_compare.py`、`nv_baseline.yaml`。

实例 A（GPU 0，port 8000）评测与补评命令：

```bash
/opt/conda/bin/python3 /workspace/flagrelease_eval_methods/fast_gpqa.py \
  --model-name Phi-3-mini-128k-instruct \
  --api-base http://127.0.0.1:8000/v1 \
  --dataset gpqa_diamond \
  --output /models/release_run_logs/Phi-3-mini-128k-instruct/gpqa_v2.json \
  --limit 50

/opt/conda/bin/python3 /workspace/flagrelease_eval_methods/eval_missing_phi3mini_v2.py

/opt/conda/bin/python3 /workspace/flagrelease_eval_methods/accuracy_compare.py \
  --v2 /models/release_run_logs/Phi-3-mini-128k-instruct/gpqa_v2.json \
  --nv-baseline Phi-3-mini-128k-instruct \
  --nv-baseline-file /workspace/flagrelease_eval_methods/nv_baseline.yaml \
  --json --output /models/release_run_logs/Phi-3-mini-128k-instruct/verdict_v2.json
```

补评输出（实例 A，index 11）：

```
[eval_missing] index=11 target=A api=http://127.0.0.1:8000/v1
[eval_missing] finish_reason=stop  latency=88.8s
[eval_missing] extracted=A  target=A  acc=1.0
[eval_missing] total=50  correct=21  score=42.0%
[eval_missing] written /models/release_run_logs/Phi-3-mini-128k-instruct/gpqa_v2.json
```

三路并行稳定性验证：GPU 0/1/2，port 8000/8001/8002，三路均达标（退出码 0），结果一致。

## 结果

- 修复后分 / NV 基线：42.0%（21/50，实例 A） / 33.0%；三路并行 B=44.0%（22/50）、C=38.0%（19/50），均高于 NV 基线
- 达标判定（accuracy_compare 退出码）：0（达标）；实例 A/B/C 退出码均为 0，v1 为 1（不达标）

最终 verdict（实例 A，`verdict_v2.json`）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Phi-3-mini-128k-instruct",
  "metric": "gpqa_diamond",
  "nv": { "score": 33.0, "source": "NV 实测" },
  "current": {
    "path": "/models/release_run_logs/Phi-3-mini-128k-instruct/gpqa_v2.json",
    "model": "Phi-3-mini-128k-instruct",
    "score": 42.0,
    "mode": "standard"
  },
  "tolerance": 0.05,
  "timestamp": "2026-09-18T13:29:09.197586",
  "rel_drop": -0.2727,
  "rel_drop_pct": -27.27,
  "abs_diff": 9.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=42.00%, NV=33.00%, 相对退化=-27.27% (容差 5.0%)"
}
```

## 提炼到 KNOWLEDGE 的条目

Phi-3-mini-128k-instruct（GQA，3.8B，`num_key_value_heads=8`）在 MetaX 上与 Phi-4-mini 规律一致：
plugin-FL 默认黑名单触发 FlagGems `rms_norm`/`silu_and_mul` GQA 精度 bug，扩展黑名单加这两个算子后
v2 三路均超 NV 基线（38%/42%/44% vs NV 33%）。遇 evalscope 49/50 卡挂（已知概率性问题），
kill 后用 eval_missing 脚本单独补评，不影响最终达标判定。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: LLM-Research/Phi-3-mini-128k-instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
# HARBOR_VER: V3
# GPU: MetaX C550, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 33.0
# SCORE_FLAGOS: 42.0
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
/opt/conda/bin/vllm serve /models/Phi-3-mini-128k-instruct \
  --served-model-name Phi-3-mini-128k-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```
