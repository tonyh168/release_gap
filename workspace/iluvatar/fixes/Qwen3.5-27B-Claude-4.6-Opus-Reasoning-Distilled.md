# iluvatar/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 修复日志

- **失败报告**：新增模型（STATUS.md 补录，无历史失败报告）
- **原始失败类型**：未开始
- **修复日期**：2026-09-16 起，2026-09-18 iter2 达标

---

## 背景分析

Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 为蒸馏推理模型，27B dense decoder（Qwen3.5 架构，GQA）。
bf16 约 54 GB，单卡 32 GB 不够，需 TP=2（两卡各 27 GB，gpu-memory-utilization=0.95 → 可用 30.4 GB/卡）。
thinking 模型（名字含 `qwen3`，`fast_gpqa.detect_thinking()` 命中 → `temperature=0.6`），
使用 `TRITON_ATTN`（非 MLA）。
评测指标为 gpqa_diamond，NV 基线 75.0。
权重来源：`Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled`（ModelScope）。

---

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-qwen3.5-27b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` |
| 卡号 | `CUDA_VISIBLE_DEVICES=5,6`（TP=2） |
| 端口 | 8014 |
| attention-backend | `TRITON_ATTN`（Qwen3.5 GQA，非 MLA） |
| max-model-len | iter1 `8192` → **iter2 `65536`** |
| gpu-memory-utilization | 0.95 |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |

---

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
/usr/local/corex-4.5.0/bin/ixsmi
docker ps --format '{{.Names}}\t{{.Status}}'
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=qwen3.5-27b
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
```

---

## Step 2：确认模型权重

权重来源：`Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/
```

若需下载（eval-scope 容器内）：
```bash
docker exec eval-scope bash -c "
modelscope download --model Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --local-dir /models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
"
```

---

## Step 3：起 vLLM 服务（iter2 达标配置）

```bash
docker exec -d flagrelease-fix-qwen3.5-27b bash -c "
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=5,6
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
mkdir -p /models/release_run_logs/\${model_name}
nohup vllm serve /models/flagrelease/fixes_models/\${model_name} \
  --served-model-name \${model_name} --dtype bfloat16 \
  --tensor-parallel-size 2 --gpu-memory-utilization 0.95 \
  --max-model-len 65536 \
  --port 8014 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  > /models/release_run_logs/\${model_name}/serve_iter2.log 2>&1 &
echo \$! > /models/release_run_logs/\${model_name}/serve_iter2.pid
"
```

> ⚠️ **`--max-model-len` 不要设得过小**。iter1 设了 `8192`，看似"省显存"，实际白吃一个亏：
> `fast_gpqa.auto_max_tokens()` 用 `max_model_len - 8192` 反推 `max_tokens`，再对小上下文服务
> （`max_model_len ≤ 16384`）取半，于是 **`max_tokens` 被压到 4096**。
> iter2 提到 `65536` 后（同样的 TP=2 / gpu-util=0.95），`max_tokens` 恢复为 thinking 上限 20000。
> KV cache 需求远小于权重，65536 在 TP=2 下完全装得下。

若 crash → 抓算子名追加黑名单：
```bash
grep -E "Error|crash|Traceback|RuntimeError|NotImplemented" \
  /models/release_run_logs/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/serve_iter2.log | tail -20
```

### 迭代记录

| 迭代 | 黑名单 | max-model-len | GPQA | 退出码 | 备注 |
|------|--------|:---:|------|:---:|------|
| 第1次 | sort,sort_stable | 8192 | ❌ 70.0%（50题） | 1（↓6.67%，NV 75.0） | TP=2，TRITON_ATTN，gpu-util=0.95；`max_tokens` 被压到 4096；1 runaway（index 22）；score=null 从 evalscope 报告恢复 |
| 第2次 | sort,sort_stable,**mm,addmm** | **65536** | ✅ **80.0%**（50题） | **0（↑6.67%，反超基线）** | `max_tokens`=20000；runaway 0/50；无截断；耗时 86m29s |

---

## Step 4：smoke test

```bash
model_name=Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
curl -s http://localhost:8014/v1/models
curl -s http://localhost:8014/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":64,"temperature":0}'
```

---

## Step 5：评测

thinking 模型，gpqa_diamond。注意 `fast_gpqa.py` 对 thinking 模型有 `score=null` 问题
（`detect_runaway` 的 list-content bug），需从 evalscope 报告恢复分数。

```bash
docker exec -d eval-scope bash -c "
cd /workspace/eval_scripts
model_name=Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
mkdir -p /models/release_run_logs/\${model_name}
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8014/v1 --dataset gpqa_diamond \
  --output /models/release_run_logs/\${model_name}/gpqa_iter2.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_gpqa_iter2.log
"
```

**iter2 分数重建**（`fast_gpqa` 写出 `score: null`，从 evalscope 报告恢复后跑 compare）：

```bash
# eval-scope 容器内执行
REPORT=/workspace/eval_scripts/outputs/gpqa_diamond/20260918_060458/reports/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/gpqa_diamond.json
LOG=/models/release_run_logs/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
EVAL_DIR=/workspace/eval_scripts

# 1. 备份 iter1 产物（保留，不删）
cp -p $LOG/verdict.json $LOG/verdict_iter1.json
cp -p $LOG/gpqa.json    $LOG/gpqa_iter1.json

# 2. 从 evalscope 报告重建 iter2 result JSON
python3 -c "
import json
m = json.load(open('$REPORT'))['metrics'][0]
out = {'model': 'Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled',
       'benchmark': 'gpqa_diamond', 'mode': 'thinking',
       'score': round(m['score']*100, 2), 'total_questions': m['num'],
       'source': 'evalscope report 20260918_060458'}
json.dump(out, open('$LOG/gpqa_diamond_result_iter2.json','w'), ensure_ascii=False, indent=2)
print(out)
"   # → score: 80.0 total: 50

# 3. accuracy_compare
python3 $EVAL_DIR/accuracy_compare.py \
  --v2 $LOG/gpqa_diamond_result_iter2.json \
  --nv-baseline Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --nv-baseline-file $EVAL_DIR/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output $LOG/verdict_gpqa_iter2.json
# → 退出码 0
```

---

## 现象

- **iter1**（`sort,sort_stable`，TRITON_ATTN，TP=2，gpu-util=0.95，**max-model-len=8192**，端口 8014）：
  - 服务正常启动，smoke test 通过，无算子 crash。
  - 评测完成，但 `fast_gpqa.py` 因 thinking 模型 `message.content` 为 list 触发
    `detect_runaway` 的 `AttributeError: 'list' object has no attribute 'strip'`，`score=null`。
  - 从 evalscope 报告 `outputs/gpqa_diamond/20260917_050701` 恢复：`score=0.7` → **70.0%**（NV 75.0，↓6.67%）。
  - `max_tokens=4096`（small_ctx 路径：`max_model_len=8192 ≤ 16384` → `8192 // 2`）。
  - 1 个 runaway（index 22，`high_repeat_and_compressible`，`finish_reason=max_tokens`）。
- **iter2**（追加 `mm,addmm`，**max-model-len=65536**）：
  - 服务正常启动，50 题跑完，耗时 86m29s（5189s）。
  - `fast_gpqa` 同样写出 `score=null`；从 evalscope 报告 `outputs/gpqa_diamond/20260918_060458`
    恢复：`score=0.8` → **80.0%**（50 题）。
  - runaway **0/50**，`truncation_detected=false`。

## 定位

- 服务本身正常，两轮均无算子 crash，**不是启动类问题**。
- iter1 的 70.0% 与 iter2 的 80.0% 之间，改动有两项：黑名单追加 `mm,addmm`、`max-model-len` 8192→65536。
  逐项核对：

  | 改动 | 是否是本次提升的原因 | 依据 |
  |------|:---:|------|
  | `max-model-len` 8192→65536 | **否** | 两轮输出长度分布几乎一致（iter1 中位 1462 / iter2 中位 1443 token），iter1 也**没有发生截断**（`truncation_detected=false`，仅 runaway 那 1 题撞顶） |
  | 黑名单追加 `mm,addmm` | **可能** | 唯一的算子侧改动；与 Qwen3-30B-A3B-Thinking-2507 的处置一致（该模型同样靠 `mm` 黑名单达标） |
  | 采样随机性 | **可能有贡献** | thinking 模式 `temperature=0.6`（非贪心），50 题下 1 SD ≈ 6.1%，10 个百分点的提升约 1.6 SD，不能排除部分来自运行间方差 |

  **结论：无法把提升单独归因于某一项。** `max-model-len` 可以排除；剩余候选是 `mm,addmm` 黑名单
  与采样方差。若要确证，需固定随机种子重跑 iter1 配置对比。

- iter1 的 `max-model-len=8192` 事后看是**过度保守**：同样 TP=2 / gpu-util=0.95 的条件下，
  65536 完全跑得起来（KV cache 需求远小于权重）。它虽未造成实际截断，但把 `max_tokens` 压到了 4096，
  对 reasoning 模型是隐患。

## 处置

**iter2 达标，完成。**

达标配置（与 Qwen3-30B-A3B-Thinking-2507 一致的路子）：
`VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm` + `TRITON_ATTN` + TP=2 + `--max-model-len 65536`。

## 结果

- 修复后 GPQA 正确率：**80.0%**（50 题，从 evalscope 报告恢复）
- NV 基线：**75.0%**
- 相对变化：**↑6.67%（反超基线）**
- 达标判定：**✅ 达标**（`accuracy_compare` 退出码 0，2026-09-18 实跑）
- 评测耗时：5189s（86m29s）
- evalscope 报告：`outputs/gpqa_diamond/20260918_060458`

`verdict_gpqa_iter2.json`（accuracy_compare 输出）：

```json
{
  "baseline_mode": "nv_reference",
  "model": "Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled",
  "metric": "gpqa_diamond",
  "nv": { "score": 75.0, "source": "NV 实测" },
  "current": {
    "path": "/models/release_run_logs/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/gpqa_diamond_result_iter2.json",
    "model": "Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled",
    "score": 80.0,
    "mode": "thinking"
  },
  "tolerance": 0.05,
  "timestamp": "2026-09-18T08:21:20.371572",
  "missing_nv": false,
  "rel_drop": -0.0667,
  "rel_drop_pct": -6.67,
  "abs_diff": 5.0,
  "aligned": true,
  "noise_zone": false,
  "message": "精度达标: 当前=80.00%, NV=75.00%, 相对退化=-6.67% (容差 5.0%)"
}
```

## 提炼到 KNOWLEDGE 的条目

1. **`--max-model-len` 不要凭"权重能装下"就设得很小**：`fast_gpqa.auto_max_tokens()` 以
   `max_model_len - 8192` 反推 `max_tokens`，且对 `max_model_len ≤ 16384` 的服务再取半
   （`8192 → max_tokens=4096`）。对 reasoning 模型这是隐患，会静默压缩思考链预算。
   KV cache 需求远小于权重，TP=2 下 65536 通常也装得下。
2. Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 在 BI-V150 上达标配置为
   `sort,sort_stable,mm,addmm` + `TRITON_ATTN` + TP=2 + `--max-model-len 65536`，GPQA 80.0%（NV 75.0）。
3. thinking 模型 `temperature=0.6` 是非贪心采样，50 题量级下运行间方差约 ±6%，小幅达标/不达标
   需谨慎归因；判读提升时优先排除配置改动，再考虑方差。
