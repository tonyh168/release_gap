# metax/Phi-3.5-mini-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Phi-3.5-mini-instruct_202607161811.md
- **原始失败类型**：精度不达标（V2: 28%，V3: 26%，V1 GPQA 未评测，无 Issue）
- **日期**：2026-09-14

---

## 背景分析

原报告 V1 有性能数据但 GPQA 为空（服务起来了但未跑评测），V2=28%，V3=26%，V2→V3 精度差 2%。
无 Issue 提交，说明无 crash，纯精度退化。
算子白名单 31 个（add/sort/softmax 等标准集），V2 和 V3 白名单相同。

Phi-3.5-mini-instruct 是标准 dense 模型（3.8B，非 MoE），bf16 权重约 7.6GB，单卡可装。
ModelScope 来源：`LLM-Research/Phi-3.5-mini-instruct`。

TP 计算：7.6GB / 63.6GB × 1.2 = 0.14 → **TP=1**（单卡足够）。

修复重点：先用 plugin-FL + 默认黑名单起服务，对比 V1 裸 vLLM 基线，定位精度退化来源。
若默认黑名单后仍退化，用二分法缩小黑名单范围排查问题算子。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `flagrelease-fix-phi-3.5-mini-instruct` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Phi-3.5-mini-instruct` |
| 卡号 | `MACA_VISIBLE_DEVICES=<空闲卡号>`（TP=1） |
| 实际 vLLM 版本 | |

---

## Step 0：登录 + 查卡

```bash
ssh metax-60
mx-smi   # 确认空闲单卡
```

**mx-smi 输出节选**：
```
（上机后粘贴）
```

**分配**：GPU X（TP=1），服务端口 80XX

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
model_name=phi-3.5-mini-instruct
docker run -d --rm \
  --name flagrelease-fix-${model_name} \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it flagrelease-fix-${model_name} /bin/bash
```

容器内自检：
```bash
mx-smi
python -c "import vllm; print(vllm.__version__)"   # 应为 0.24.0
```

**自检输出**：
```
（上机后填写）
```

---

## Step 2：下载模型

权重来源：`LLM-Research/Phi-3.5-mini-instruct`（ModelScope）

```bash
# 宿主机：确认 eval-scope 容器在运行
docker ps --filter name=eval-scope --format '{{.Names}}'
# 若无输出，创建：
docker run -d --name eval-scope \
  --network host \
  -v /public-flash/models:/models \
  harbor.baai.ac.cn/flagrelease-public/flagos-evalscope:latest-modelscope \
  sleep infinity

# eval-scope 容器内下载
docker exec -it eval-scope /bin/bash
ls /models/flagrelease/fixes_models/ | grep -i phi-3.5   # 先确认是否已有
# 若无：
mkdir -p /models/flagrelease/fixes_models
modelscope download --model LLM-Research/Phi-3.5-mini-instruct \
  --local_dir /models/flagrelease/fixes_models/Phi-3.5-mini-instruct
ls /models/flagrelease/fixes_models/Phi-3.5-mini-instruct/   # 确认 config.json / *.safetensors / tokenizer
```

**结果**：☐ 共享盘已有 / ☐ 需下载

---

## Step 3：起 vLLM 服务

### 修复策略

V1 GPQA 原报告未跑，V2/V3 都有精度退化（28%/26%）。路径：
1. **先跑裸 vLLM V1 基线**（不开 plugin）确认 vLLM 0.24.0 下模型本身精度
2. **开 plugin-FL 默认黑名单**：对比 V1，看退化幅度
3. **二分法缩黑名单**：若 plugin 引入退化，逐步排查问题算子

### 第1次 — 裸 vLLM V1 基线

```bash
# 服务容器内执行（flagrelease-fix-phi-3.5-mini-instruct）
export GEMS_VENDOR=metax
# 不设 VLLM_PLUGINS
export MACA_VISIBLE_DEVICES=<卡号>
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=Phi-3.5-mini-instruct
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --port 80XX \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v1.log &
```

### 第2次 — plugin-FL 默认黑名单

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=<卡号>
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=Phi-3.5-mini-instruct
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --port 80XX \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve_v3.log &
```

### 冒烟验证

```bash
model_name=Phi-3.5-mini-instruct
curl -s http://localhost:80XX/v1/models
curl -s http://localhost:80XX/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？请详细介绍该城市的历史沿革、人口规模和主要政治职能。"}],"max_tokens":256,"temperature":0}'
```

### 迭代记录

| 迭代 | VLLM_PLUGINS | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|-------------|--------------------------|------------|------------------------|------|
| 第1次（V1，裸 vLLM） | 未设 | — | | | V1 基线 |
| 第2次（默认黑名单） | fl | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | | | |
| 第3次 | fl | | | | 二分调整 |

---

## Step 4：评测

评测统一在 **eval-scope 容器**内执行。

```bash
docker exec -it eval-scope /bin/bash
cd /workspace/release_评测标准

model_name=Phi-3.5-mini-instruct

# V1 基线评测
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:80XX/v1 \
  --output /models/release_run_logs/${model_name}/gpqa_v1.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa_v1.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict_v1.json

# plugin-FL 评测（切换服务后重跑）
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:80XX/v1 \
  --output /models/release_run_logs/${model_name}/gpqa_v3.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa_v3.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict_v3.json
```

### 评测迭代记录

| 迭代 | 模式 | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|------|------------|------------------------|------|
| 第1次（V1） | 裸 vLLM | | | |
| 第2次 | plugin-FL 默认黑名单 | | | |
| 第3次 | | | | |

**verdict.json 原文**（最终达标的那次）：
```json
（粘贴）
```

---

## 现象

原报告已知：
- V1 GPQA 未跑（性能数据有，精度数据空）
- V2 GPQA 28%，V3 GPQA 26%，V2→V3 精度差 2%
- 算子白名单 31 个（add/sort/softmax 等）
- 无 Issue 提交，无 crash

## 定位

（填：退化是 plugin 引入还是 vLLM 0.24.0 本身 / 具体问题算子）

## 处置

（填：黑名单调整项）

## 结果

- V1 基线分：
- 修复后分 / NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目

（一句话规律，若无则写"无新规律"）
