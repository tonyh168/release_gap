# metax/SOLAR-10.7B-Instruct-v1.0 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_SOLAR-10.7B-Instruct-v1.0_202607261725.md
- **原始失败类型**：精度不达标（V2=27.78%，V3=30.3%，均低于 NV×0.95=32.3%）+ plugin-FL 报错
- **日期**：2026-09-16

---

## 背景分析

SOLAR-10.7B-Instruct-v1.0 是 dense 10.7B 模型，bf16 权重约 21GB。
ModelScope 来源：`upstage/SOLAR-10.7B-Instruct-v1.0`
NV 基线：gpqa_diamond = **34**（容差 5%，下限 ≥ 32.3%）

原始报告中 V1 无评测数据，V2（FlagGems，无 plugin）= 27.78%，V3（plugin-FL）= 30.3%——均不达标。
两个 issue 均为精度退化 + plugin-FL error，说明 plugin-FL 开启后算子替换造成精度损失。

TP 计算：21GB × 1.2 / 63.6 = 0.40 → TP=1（单卡剩余 ~37GB KV cache，充裕）

---

## 环境

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-solar-10.7b-instruct` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/SOLAR-10.7B-Instruct-v1.0` |
| TP / GPU / 端口 | TP=1，GPU 0，port=8000 |
| max_model_len | 4096（模型 config.json 中 max_position_embeddings=4096，不可超过） |
| 实际 vLLM 版本 | 0.24.0 (v0.1.dev17936+gee0da84ab) |

---

## Step 0：登录 + 查卡

```bash
ssh metax-60
mx-smi
```

**mx-smi 输出节选**（2026-09-16，所有容器已停止后）：
```
GPU 0-7: 858/65536 MiB（全部空闲）
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
docker run -d --rm \
  --name flagrelease-fix-solar-10.7b-instruct \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it flagrelease-fix-solar-10.7b-instruct /bin/bash
```

---

## Step 2：确认模型

权重来源：`upstage/SOLAR-10.7B-Instruct-v1.0`（ModelScope）

```bash
ls /models/ | grep -i solar
```

权重已存在于 `/models/SOLAR-10.7B-Instruct-v1.0`（无需下载）。

---

## Step 3：起 vLLM 服务

### 修复策略

原始失败为 plugin-FL 开启后精度退化。先用默认黑名单（屏蔽 mm/bmm/linear 等高风险算子）起服务。
v1 评测结果 24.0%（12/50），不达标（NV×0.95=32.3%），参考 Phi-4-mini 方案扩展黑名单加 `rms_norm,silu_and_mul`。

### 启动命令（v1，复现用）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=SOLAR-10.7B-Instruct-v1.0
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v1.log
```

**启动日志关键行**：
```
(EngineCore pid=642) [INFO] init engine (profile, create kv cache, warmup model) took 26.17 s
(APIServer pid=430) INFO:     Application startup complete.
```

### 启动命令（v3，复现用）

去掉 `VLLM_FL_USE_FLAGGEMS_ATTN=0`，仅保留默认黑名单。v1/v2 得分（24%/26%）均低于原报告 V3=30.3%，原因推断为 FlagGems attention 被禁用后 SOLAR 精度退化——SOLAR 是非 MLA dense 模型，FlagGems attention 对其无害，不应禁用。

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=SOLAR-10.7B-Instruct-v1.0
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v3.log
```

**启动日志关键行（v3）**：
```
(APIServer pid=14) INFO:     Application startup complete.
```

### 迭代记录（启动阶段）

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 变化 | 结果 | 日志关键报错 |
|------|------------------------------|------|-------------|
| v1（初次，max-model-len=32768） | 默认 | ❌ 启动失败 | `pydantic ValidationError: max_model_len (32768) > max_position_embeddings (4096)` |
| v1（重启，max-model-len=4096） | 默认 | ✅ 启动成功，`Application startup complete` | 无崩溃 |
| v2（重建容器，max-model-len=4096） | 加 `rms_norm,silu_and_mul` | ✅ 启动成功，`Application startup complete` | 无崩溃；v1 精度 24.0% 不达标，参考 Phi-4-mini 方案扩展黑名单 |
| v3（重建容器，去掉 VLLM_FL_USE_FLAGGEMS_ATTN=0） | 默认（无 rms_norm,silu_and_mul） | ✅ 启动成功 | v2 精度 26.0% 仍不达标；推断 FlagGems attn 被禁是退化根因，非 MLA 模型应保留 FlagGems attn |

### 启动命令（v2，复现用）

扩展黑名单，加 `rms_norm,silu_and_mul`（参考 Phi-4-mini 方案），重建容器后启动：

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice,rms_norm,silu_and_mul
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=SOLAR-10.7B-Instruct-v1.0
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v2.log
```

**启动日志关键行（v2）**：
```
(APIServer pid=15) INFO:     Application startup complete.
```

### 冒烟验证

```bash
model_name=SOLAR-10.7B-Instruct-v1.0

curl -s http://localhost:8000/v1/models

curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is the capital of France?"}],"max_tokens":32,"temperature":0}'

curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"请详细解释牛顿三大运动定律，并各举一个日常生活中的实例，要求每条定律的解释不少于100字。"}],"max_tokens":512,"temperature":0}'
```

**冒烟结果**：✅ 通过
- 短问答（英文）："What is the capital of France?" → 正确回答 "The capital city of France is Paris..."
- 长 prompt（中文牛顿定律）→ 正常生成，无截断，max_model_len=4096 下首次回复完整

---

## Step 4：评测

```bash
model_name=SOLAR-10.7B-Instruct-v1.0

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

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| v1 | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | **24.0%**（12/50） | **1（不达标）** | 2026-09-16；fast_gpqa score=null，从 evalscope reviews 补计分；rel_drop=29.41%，远超容差 |
| v2 | +rms_norm,silu_and_mul | **26.0%**（13/50） | **0（verdict aligned=false，不达标）** | 2026-09-16；rel_drop=23.53%；扩展黑名单反而未改善，推测 VLLM_FL_USE_FLAGGEMS_ATTN=0 是退化根因 |
| v3 | 默认（去掉 VLLM_FL_USE_FLAGGEMS_ATTN=0） | **20.0%**（10/50） | **1（不达标）** | 2026-09-16；rel_drop=41.18%；去掉 VLLM_FL_USE_FLAGGEMS_ATTN=0 反而更差，FlagGems attn 对 SOLAR 无益 |

**verdict_v1.json 原文**（不达标）：
```json
{
  "baseline_mode": "nv_reference",
  "model": "SOLAR-10.7B-Instruct-v1.0",
  "metric": "gpqa_diamond",
  "nv": { "score": 34.0, "source": "NV 实测" },
  "current": { "score": 24.0, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T09:35:XX",
  "rel_drop": 0.2941,
  "rel_drop_pct": 29.41,
  "abs_diff": -10.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=24.00%, NV=34.00%, 相对退化=29.41% > 容差 5.0%"
}
```

**verdict_v2.json 原文**（不达标）：
```json
{
  "baseline_mode": "nv_reference",
  "model": "SOLAR-10.7B-Instruct-v1.0",
  "metric": "gpqa_diamond",
  "nv": { "score": 34.0, "source": "NV 实测" },
  "current": { "score": 26.0, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T10:12:23.308235",
  "rel_drop": 0.2353,
  "rel_drop_pct": 23.53,
  "abs_diff": -8.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=26.00%, NV=34.00%, 相对退化=23.53% > 容差 5.0%"
}
```

**verdict_v3.json 原文**（不达标）：
```json
{
  "baseline_mode": "nv_reference",
  "model": "SOLAR-10.7B-Instruct-v1.0",
  "metric": "gpqa_diamond",
  "nv": { "score": 34.0, "source": "NV 实测" },
  "current": { "score": 20.0, "mode": "standard" },
  "tolerance": 0.05,
  "timestamp": "2026-09-16T10:40:12.029706",
  "rel_drop": 0.4118,
  "rel_drop_pct": 41.18,
  "abs_diff": -14.0,
  "aligned": false,
  "noise_zone": false,
  "message": "精度不达标: 当前=20.00%, NV=34.00%, 相对退化=41.18% > 容差 5.0%"
}
```

---

## 现象

三轮迭代均不达标：v1=24%❌（默认黑名单 + VLLM_FL_USE_FLAGGEMS_ATTN=0）、v2=26%❌（扩展黑名单加 rms_norm,silu_and_mul + VLLM_FL_USE_FLAGGEMS_ATTN=0）、v3=20%❌（默认黑名单，去掉 VLLM_FL_USE_FLAGGEMS_ATTN=0）。

原始回答检查显示模型 IS 在生成内容（30-44 tok/s），但大量回答是冗长的推理段落，没有以 `ANSWER: (X)` 格式收尾，导致 evalscope 无法提取答案字母。只有少数样本（如 "ANSWER: D" 开头的）被正确计分。这是 plugin-FL 在 MetaX 硬件上引起的格式退化（greedy-decode 路径偏移），而非模型静默。

对比：原始报告 V3=30.3%，本次最好 v2=26.0%，低 4pt，且三轮均低于 NV×0.95=32.3% 下限。

## 定位

- plugin-FL 开启后 MetaX 硬件上 SOLAR 的 greedy-decode 输出路径偏移，模型进入冗长推理模式，不再可靠地输出 MCQ 答案字母
- VLLM_FL_USE_FLAGGEMS_ATTN=0 对 SOLAR（非 MLA dense 模型）无益，去掉反而更差（v3=20% < v1=24%）
- 扩展黑名单加 rms_norm,silu_and_mul 有轻微改善（v2=26% > v1=24%），但远不够
- max_tokens=2048（由 max_model_len=4096 触发），truncation_detected=false，不是截断问题

## 处置

2026-09-16 暂停修复，记录当前状态。三轮最优为 v2（扩展黑名单 + VLLM_FL_USE_FLAGGEMS_ATTN=0，26%）。
容器已停止（docker stop flagrelease-fix-solar-10.7b-instruct）。

## 结果

- 最优得分 / NV 基线：**26.0%**（v2）/ 34.0%（下限 32.3%）
- 达标判定：❌ 未达标，所有迭代均不达标，修复暂停

## 提炼到 KNOWLEDGE 的条目

1. SOLAR-10.7B-Instruct-v1.0 在 MetaX + plugin-FL 下出现格式退化：模型生成冗长推理但不输出终止答案字母，evalscope 无法提取。这不是截断也不是静默，是 greedy-decode 路径偏移。
2. 对 SOLAR 这类非 MLA dense 模型，`VLLM_FL_USE_FLAGGEMS_ATTN=0` 无益，去掉后更差。
3. 扩展黑名单（加 rms_norm,silu_and_mul）有轻微改善但不解决根本问题，参考 Phi-4 方案不能直接套用。
