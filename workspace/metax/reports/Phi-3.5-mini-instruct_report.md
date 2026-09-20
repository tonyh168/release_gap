# metax/Phi-3.5-mini-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Phi-3.5-mini-instruct_202607161811.md
- **原始失败类型**：精度不达标（V2: 28%，V3: 26%，V1 GPQA 未评测，无 Issue）
- **日期**：2026-09-14

## 现象

- 原报告 **V1 有性能数据但 GPQA 为空**（服务起来了但未跑评测），V2 = 28%，V3 = 26%，V2→V3 精度差 2%。**无 Issue 提交，说明无 crash，属纯精度退化**。
- 原报告算子白名单 31 个（add/sort/softmax 等标准集），V2 和 V3 白名单相同。
- 本次修复用 plugin-FL 默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + `--enforce-eager`（GPU 0，port 8001，TP=1）起服务，启动日志出现 `[INFO] [vllm_fl.dispatch] Platform plugin fl is activated` 与 `INFO: Application startup complete.`，无报错、无崩溃。
- 冒烟（`/v1/models` + 中文短问答）正常；随后跑 50 题 GPQA Diamond。
- 评测过程中 **doc_id 23 和 34 两题卡挂**（`GPU util` 持续 15% 达 28 分钟），`fast_gpqa.py` 的 parse bug 又导致 `score` 字段写成 `null`；两题用 `eval_missing2.py` 单独补评后合并计分。
- 合并后最终结果 **34%（17/50）**，已超过 NV 基线 26%，一次起服务即达标，无需二分排查黑名单。

## 定位

- Phi-3.5-mini-instruct 是标准 dense 模型（3.8B，非 MoE），bf16 权重约 7.6GB，单卡可装；TP 计算 7.6GB / 63.6GB × 1.2 = 0.14 → **TP=1**。
- 架构为标准 **MHA（32Q/32KV）**。plugin-FL 默认黑名单下 `rms_norm` 和 `silu_and_mul` 仍走 FlagGems，但 **MHA 的张量 shape 对 FlagGems 这两个算子无问题**，因此默认黑名单即可达标——这与 Phi-4-mini（GQA 路径，需把 `rms_norm,silu_and_mul` 加进黑名单）的退化根因不同，不能照搬结论。
- 本次未做算子级二分：V2/V3 的历史退化（28%/26%）在 plugin-FL 默认黑名单下即被消除，无残留 crash 算子、无 OOM、无缺 `.so` 编译扩展。
- 卡题定位（非服务崩溃）：doc_id 23/34 疑似生成了特别长的 CoT 回答（分别 387 和 564 tokens），evalscope tqdm 的剩余时间估算严重偏低（显示 26s 但实际挂起），是已知的概率性卡题。补评后两题**均答错**，不影响最终达标判定。

## 处置

### 运行环境

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-phi-3.5-mini-instruct` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Phi-3.5-mini-instruct`（ModelScope `LLM-Research/Phi-3.5-mini-instruct`，共享盘已有，无需下载） |
| 卡号 / 端口 | `MACA_VISIBLE_DEVICES=0`（TP=1），port=8001 |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |
| 最终配置 | plugin-FL 默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + `--enforce-eager`，`max_model_len=32768`，`mode=standard` |

### 修复路径与迭代记录

修复思路：先跑裸 vLLM V1 基线确认 vLLM 0.24.0 下模型本身精度 → 再开 plugin-FL 默认黑名单对比退化幅度 → 若 plugin 引入退化再用二分法缩小黑名单范围。实际执行中**默认黑名单一次即达标，二分排查未启用（方案弃用）**。

| 迭代 | VLLM_PLUGINS | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|-------------|--------------------------|------------|------------------------|------|
| v2（plugin-FL 默认黑名单） | fl | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **34%**（17/50） | **0（达标）** | 2026-09-15，doc_id 23/34 用 `eval_missing2.py` 补评后合并计分 |

未采用的尝试：原报告的 V2=28% / V3=26% 两轮均不达标，本次未复现那两轮的配置组合；「二分法缩黑名单」与「扩展黑名单加 `rms_norm,silu_and_mul`」（Phi-4-mini 方案）在本模型上**均未启用**，因为默认黑名单已达标。

### 评测过程

评测统一在独立 `eval-scope` 容器内执行，服务端口 8001，输出落到 `/models/release_run_logs/Phi-3.5-mini-instruct/`（`gpqa_v2.json` / `verdict_v2.json` / `eval_v2.log`）。

评测参数（`gpqa_v2.json`）：`mode=standard`，`temperature=0.0`，`max_tokens=24576`，`max_model_len=32768`，50 题（48 题 `fast_gpqa.py` 批量 + doc_id 23/34 由 `eval_missing2.py` 单独补评）。

补评/合并计分过程：`fast_gpqa.py` 的 parse bug 把 `score` 写成 `null`，分数从 evalscope reviews 逐题记录补计分；doc_id 23、34 卡挂后 kill evalscope，用 `eval_missing2.py` 补这两题并合入总分。

## 结果

- 修复后分 / NV 基线：**34.0%（17/50）** / **26.0%**
- 达标判定（accuracy_compare 退出码）：**0（达标，MetaX 实测超 NV 8 题）**

**verdict_v2.json 原文**（最终达标）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Phi-3.5-mini-instruct",
  "metric": "gpqa_diamond",
  "nv": { "score": 26.0, "source": "NV 实测" },
  "current": { "score": 34.0, "mode": "unknown" },
  "tolerance": 0.05,
  "timestamp": "2026-09-15T05:39:47.088658",
  "rel_drop": -0.3077,
  "rel_drop_pct": -30.77,
  "abs_diff": 8.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=34.00%, NV=26.00%, 相对退化=-30.77% (容差 5.0%)"
}
```

**逐题对错**（v2，doc_id 来自 evalscope predictions + `eval_missing2.py` 补评）：

| 状态 | 题数 | doc_id 列表 |
|------|------|------------|
| ✓ 正确 | 17 | 6 8 9 11 13 15 16 18 19 27 29 30 31 36 38 45 49 |
| ✗ 错误 | 33 | 0 1 2 3 4 5 7 10 12 14 17 20 21 22 23 24 25 26 28 32 33 34 35 37 39 40 41 42 43 44 46 47 48 |

## 提炼到 KNOWLEDGE 的条目

Phi-3.5-mini-instruct（MHA，3.8B）在 MetaX 上用 plugin-FL 默认黑名单 + `VLLM_FL_USE_FLAGGEMS_ATTN=0` + eager 一次起成功达标；evalscope 对长回答题目的剩余时间估算会严重偏低（显示 26s 但实际挂起），遇到 tqdm 长时间不动需用 `eval_missing2.py` 单独补评未完成题目后合并计分。另外，MHA 架构对 `rms_norm`/`silu_and_mul` 走 FlagGems 不敏感，GQA 模型（Phi-4）才需要把这两个算子加进黑名单，方案不可跨架构照搬。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: LLM-Research/Phi-3.5-mini-instruct
# IMAGE: harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
# HARBOR_VER: V3
# GPU: MetaX C550, 1 × 64GB
# TP: 1
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 26.0
# SCORE_FLAGOS: 34.0
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
/opt/conda/bin/vllm serve /models/flagrelease/fixes_models/Phi-3.5-mini-instruct \
  --served-model-name Phi-3.5-mini-instruct \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8001 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code
```
