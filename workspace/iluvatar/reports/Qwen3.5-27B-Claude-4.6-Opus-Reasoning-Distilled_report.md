# iluvatar/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 修复日志

- **失败报告**：flagrelease_fail_reports/Iluvatar/FAILED_Iluvatar_Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled_202608240904.md
- **原始失败类型**：服务启动失败（Operator crash / 精度退化 / 性能退化 3 个 issue，V1–V4 评测数据全空）
- **日期**：2026-09-18

> 口径说明：源 fix 日志把本模型记为「新增模型（STATUS.md 补录，无历史失败报告）」，
> 但 `flagrelease_fail_reports/Iluvatar/` 下确有本模型的失败报告（报告生成时间 2026.08.24，
> 结论「❌ 迁移失败」，V1–V4 精度/性能数据全空），故此处按实际报告填写。

## 现象

失败报告侧：流程自动化结论「❌ 迁移失败」，V1–V4 的 GPQA_Diamond 精度表与性能表全部为 `-`，
未产出对外镜像；提交 3 个 issue（Operator accuracy degradation / Operator crash /
Operator performance degradation）。

本次复现（vLLM 0.24.0 + FlagGems 5.3.4.post1，TP=2，`TRITON_ATTN`）两轮实测：

- **iter1**（`sort,sort_stable`，`--max-model-len 8192`，端口 8014）：
  - 服务正常启动，smoke test 通过，**无算子 crash**
  - 评测完成，但 `fast_gpqa.py` 因 thinking 模型 `message.content` 为 list 触发
    `detect_runaway` 的 `AttributeError: 'list' object has no attribute 'strip'`，`score=null`
  - 从 evalscope 报告 `outputs/gpqa_diamond/20260917_050701` 恢复：`score=0.7` → **70.0%**
    （NV 75.0，↓6.67%），exit=1
  - `max_tokens=4096`（small_ctx 路径：`max_model_len=8192 ≤ 16384` → `8192 // 2`）
  - 1 个 runaway（index 22，`high_repeat_and_compressible`，`finish_reason=max_tokens`）
- **iter2**（追加 `mm,addmm`，`--max-model-len 65536`）：
  - 服务正常启动，50 题跑完，耗时 **86m29s（5189s）**
  - 从 evalscope 报告 `outputs/gpqa_diamond/20260918_060458` 恢复：`score=0.8` → **80.0%**（50 题）
  - **runaway 0/50**，`truncation_detected=false`，exit=0

## 定位

- 服务本身正常，两轮均无算子 crash，**不是启动类问题**
- iter1 的 70.0% → iter2 的 80.0% 之间，改动有两项：黑名单追加 `mm,addmm`、`max-model-len` 8192→65536。
  逐项核对：

  | 改动 | 是否是本次提升的原因 | 依据 |
  |------|:---:|------|
  | `max-model-len` 8192→65536 | **否** | 两轮输出长度分布几乎一致（iter1 中位 1462 / iter2 中位 1443 token），iter1 也**没有发生截断**（`truncation_detected=false`，仅 runaway 那 1 题撞顶） |
  | 黑名单追加 `mm,addmm` | **可能** | 唯一的算子侧改动；与 Qwen3-30B-A3B-Thinking-2507 的处置一致（该模型同样靠 `mm` 黑名单达标） |
  | 采样随机性 | **可能有贡献** | thinking 模式 `temperature=0.6`（非贪心），50 题下 1 SD ≈ 6.1%，10 个百分点的提升约 1.6 SD，不能排除部分来自运行间方差 |

  **结论：无法把提升单独归因于某一项。** `max-model-len` 可以排除；剩余候选是 `mm,addmm` 黑名单与采样方差。
  若要确证，需固定随机种子重跑 iter1 配置对比。

- iter1 的 `max-model-len=8192` 事后看是**过度保守**：同样 TP=2 / gpu-util=0.95 的条件下，
  65536 完全跑得起来（KV cache 需求远小于权重）。它虽未造成实际截断，但把 `max_tokens` 压到了 4096，
  对 reasoning 模型是隐患
- `fast_gpqa.auto_max_tokens()` 的取值路径：以 `max_model_len - 8192` 反推 `max_tokens`，
  且对 `max_model_len ≤ 16384` 的服务**再取半**；iter2 提到 65536 后 `max_tokens` 恢复为 thinking 上限 20000

## 处置

### 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-qwen3.5-27b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` |
| 卡号 / 端口 | GPU 5,6（TP=2）/ 8014 |
| attention-backend | `TRITON_ATTN`（Qwen3.5 GQA，非 MLA） |
| max-model-len | iter1 `8192` → **iter2 `65536`** |
| gpu-memory-utilization | 0.95 |
| 实际 vLLM 版本 | 0.24.0（vllm_fl0.24.0） |
| 权重来源 | `Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled`（ModelScope） |

### 起容器（宿主机执行）

```bash
docker run -itd --name flagrelease-fix-qwen3.5-27b \
  --device=/dev/iluvatar \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 bash
docker exec -it flagrelease-fix-qwen3.5-27b bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

### 起 vLLM 服务（容器内执行，iter2 最终达标配置）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --served-model-name Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled --dtype bfloat16 \
  --tensor-parallel-size 2 --gpu-memory-utilization 0.95 \
  --max-model-len 65536 \
  --port 8014 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```

> ⚠️ **`--max-model-len` 不要设得过小**：iter1 设 `8192` 看似"省显存"，实际让
> `fast_gpqa.auto_max_tokens()` 把 `max_tokens` 压到 4096（small_ctx 路径取半）；提到 `65536` 后
> `max_tokens` 恢复为 thinking 上限 20000。KV cache 需求远小于权重，65536 在 TP=2 下完全装得下。

### 迭代记录

| 迭代 | 黑名单 | max-model-len | GPQA | 退出码 | 备注 |
|------|--------|:---:|------|:---:|------|
| 第1次 | sort,sort_stable | 8192 | ❌ 70.0%（50 题） | 1（↓6.67%，NV 75.0） | TP=2，TRITON_ATTN，gpu-util=0.95；`max_tokens` 被压到 4096；1 runaway（index 22）；score=null 从 evalscope 报告恢复 |
| 第2次 | sort,sort_stable,**mm,addmm** | **65536** | ✅ **80.0%**（50 题） | **0（↑6.67%，反超基线）** | `max_tokens`=20000；runaway 0/50；无截断；耗时 86m29s |

### smoke test（容器内执行）

```bash
curl -s http://localhost:8014/v1/models
curl -s http://localhost:8014/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled","messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":64,"temperature":0}'
```

### 评测（eval-scope 容器内执行）

thinking 模型，gpqa_diamond。注意 `fast_gpqa.py` 对 thinking 模型有 `score=null` 问题
（`detect_runaway` 的 list-content bug），需从 evalscope 报告恢复分数。

```bash
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --api-base http://127.0.0.1:8014/v1 --dataset gpqa_diamond \
  --output /models/release_run_logs/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/gpqa_iter2.json
```

**iter2 分数重建**（`fast_gpqa` 写出 `score: null`，从 evalscope 报告恢复后跑 compare）：

```bash
REPORT=/workspace/eval_scripts/outputs/gpqa_diamond/20260918_060458/reports/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/gpqa_diamond.json
LOG=/models/release_run_logs/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
EVAL_DIR=/workspace/eval_scripts

cp -p ${LOG}/verdict.json ${LOG}/verdict_iter1.json
cp -p ${LOG}/gpqa.json    ${LOG}/gpqa_iter1.json

python3 -c "
import json
m = json.load(open('${REPORT}'))['metrics'][0]
out = {'model': 'Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled',
       'benchmark': 'gpqa_diamond', 'mode': 'thinking',
       'score': round(m['score']*100, 2), 'total_questions': m['num'],
       'source': 'evalscope report 20260918_060458'}
json.dump(out, open('${LOG}/gpqa_diamond_result_iter2.json','w'), ensure_ascii=False, indent=2)
print(out)
"

python3 ${EVAL_DIR}/accuracy_compare.py \
  --v2 ${LOG}/gpqa_diamond_result_iter2.json \
  --nv-baseline Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --nv-baseline-file ${EVAL_DIR}/nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output ${LOG}/verdict_gpqa_iter2.json
```

## 结果

- 修复后分 / NV 基线：**GPQA 80.0%**（50 题，从 evalscope 报告恢复）/ NV **75.0%**
- 达标判定（accuracy_compare 退出码）：**0（达标）** —— 相对变化 **↑6.67%（反超基线）**，
  2026-09-18 实跑
- 评测耗时：5189s（86m29s）；evalscope 报告：`outputs/gpqa_diamond/20260918_060458`

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
2. Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 在 BI-V150 上的达标配置为
   `sort,sort_stable,mm,addmm` + `TRITON_ATTN` + TP=2 + `--max-model-len 65536`，GPQA 80.0%（NV 75.0）。
3. thinking 模型 `temperature=0.6` 是非贪心采样，50 题量级下运行间方差约 ±6%，小幅达标/不达标
   需谨慎归因；判读提升时优先排除配置改动，再考虑方差。

---

## 发布字段

### 一、发布信息

```bash
# MODEL_SOURCE: Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
# IMAGE: harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
# HARBOR_VER: V3
# GPU: Iluvatar BI-V150, 2 × 32GB
# TP: 2
# VERDICT: ok
# METRIC: gpqa_diamond
# SCORE_ORIGIN: 75.0
# SCORE_FLAGOS: 80.0
# CONTAINER_DEVS: --device=/dev/iluvatar --ipc=host --network=host --shm-size=64g
```

### 二、容器创建（宿主机执行）

```bash
docker run --init -it --net=host --ipc=host \
  --device=/dev/iluvatar \
  --shm-size 64g \
  -v /mnt/share/models:/models \
  --name flagos \
  harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907 \
  /bin/bash
```

### 三、启动服务（容器内执行）

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm,addmm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
vllm serve /models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --served-model-name Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled --dtype bfloat16 \
  --tensor-parallel-size 2 --gpu-memory-utilization 0.95 \
  --max-model-len 65536 \
  --port 8014 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code
```
