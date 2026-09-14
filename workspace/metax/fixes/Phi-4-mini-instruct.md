# metax/Phi-4-mini-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Phi-4-mini-instruct_202607171827.md
- **原始失败类型**：精度不达标（V3: 28% vs NV基线 38%，相对退化 26.3%）+ plugin-FL 报错（2条Issue）
- **日期**：2026-09-14

---

## 背景分析

原报告用 vLLM 0.20.2 + plugin-FL 0.2.0 + FlagGems 5.0.2。
- V1 数据缺失（GPQA 无数据），说明裸 vLLM 阶段就有问题或未完成
- V2 精度 30%，V3 精度 28%，NV 基线 38%，V3 相对退化 26.3%，远超 5% 阈值
- 提交了 3 条 Issue：算子精度退化、plugin-FL 报错（dispatch）、plugin-FL 报错（vllm_fl）
- V2 算子白名单 31 个算子（add/sort/softmax 等标准集），V3 沿用相同白名单

Phi-4-mini-instruct 是标准 dense 模型（非 MoE、非 thinking），3.8B 参数，bf16 权重约 7.6GB，单卡可装。
ModelScope 来源：`microsoft/Phi-4-mini-instruct`。

TP 计算：7.6GB / 63.6GB × 1.2 = 0.14 → **TP=1**（单卡足够，KV cache 空间充裕）。

修复重点：plugin-FL 精度退化，方向与 Phi-3-mini 类似——先跑裸 vLLM V1 基线确认退化来源，
再二分法缩黑名单定位问题算子。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `Phi-4-mini-instruct_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/Phi-4-mini-instruct` |
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
docker run -d --rm \
  --name Phi-4-mini-instruct_flagos \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it Phi-4-mini-instruct_flagos /bin/bash
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

## Step 2：确认模型

权重来源：`microsoft/Phi-4-mini-instruct`（ModelScope）

```bash
ls /models/ | grep -i phi-4-mini
ls /models/Phi-4-mini-instruct/   # 确认 config.json / *.safetensors / tokenizer
```

**结果**：☐ 共享盘已有 / ☐ 需下载

若需下载：
```bash
/opt/conda/bin/pip install -q modelscope
/opt/conda/bin/modelscope download --model microsoft/Phi-4-mini-instruct \
  --local_dir /models/Phi-4-mini-instruct
```

---

## Step 3：起 vLLM 服务

### 修复策略

原报告 V1 数据缺失，plugin-FL 有精度退化和报错。修复路径：

1. **先跑裸 vLLM（关闭 plugin）建 V1 基线**：确认 vLLM 0.24.0 下模型本身精度是否正常
2. **开 plugin-FL 默认黑名单**：对比 V1，看退化是否来自 plugin
3. **二分法缩黑名单**：若 plugin 引入退化，逐步排查问题算子

### 第1次尝试 — 裸 vLLM V1 基线（不开 plugin）

```bash
export GEMS_VENDOR=metax
# 不设 VLLM_PLUGINS，跑裸 vLLM
export MACA_VISIBLE_DEVICES=<卡号>
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=Phi-4-mini-instruct
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/Phi-4-mini-instruct \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --port 80XX \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  >> /models/release_run_logs/${model_name}/serve_v1.log 2>&1 &
```

**启动结果**：
```
（粘贴 "Application startup complete" 所在行）
```

### 第2次尝试 — plugin-FL 默认黑名单（V3）

```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=<卡号>
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200

model_name=Phi-4-mini-instruct
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/Phi-4-mini-instruct \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --port 80XX \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  >> /models/release_run_logs/${model_name}/serve_v3.log 2>&1 &
```

**启动结果**：
```
（粘贴 "Application startup complete" 或崩溃日志）
```

### 冒烟验证

```bash
model_name=Phi-4-mini-instruct
curl -s http://localhost:80XX/v1/models
curl -s http://localhost:80XX/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？请详细介绍该城市的历史沿革、人口规模和主要政治职能。"}],"max_tokens":256,"temperature":0}'
```

**冒烟输出节选**：
```
（粘贴 content 字段前100字）
```

### 迭代记录

| 迭代 | VLLM_PLUGINS | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|-------------|--------------------------|------------|------------------------|------|
| 第1次（V1，裸 vLLM） | 未设 | — | | | V1 基线 |
| 第2次（V3，默认黑名单） | fl | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | | | 对比 V1 |
| 第3次 | fl | | | | 二分调整 |

---

## Step 4：评测

```bash
model_name=Phi-4-mini-instruct

# V1 基线评测
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name ${model_name} \
  --api-base http://127.0.0.1:80XX/v1 \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/${model_name}/gpqa_v1.json

python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa_v1.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict_v1.json

# V3 plugin 评测（服务换成 plugin-FL 后重跑）
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name ${model_name} \
  --api-base http://127.0.0.1:80XX/v1 \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/${model_name}/gpqa_v3.json

python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa_v3.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict_v3.json
```

> NV 基线：gpqa_diamond = **38.0%**（来源：nv_baseline.yaml，2026-07-09）

### 评测迭代记录

| 迭代 | 模式 | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|------|------------|------------------------|------|
| 第1次（V1） | 裸 vLLM | | | |
| 第2次（V3） | plugin-FL 默认黑名单 | | | |
| 第3次 | | | | |

**verdict.json 原文**（最终达标的那次）：
```json
（粘贴）
```

---

## 现象

（上机后填：启动是否正常 / plugin-FL 具体报错类型 / 精度对比）

原报告已知：
- V3 GPQA 28%（NV 38%，相对退化 26.3%）
- plugin-FL dispatch 报错 + vllm_fl 报错（共 2 条 Issue）
- V2/V3 算子白名单 31 个（以 add/sort/softmax 为主）

## 定位

（填：退化是 plugin 引入还是 vLLM 0.24.0 本身 / 具体问题算子）

## 处置

（填：黑名单调整项 / 是否上报 Issue）

## 结果

- V1 基线分：
- 修复后分 / NV 基线：38.0%
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目

（一句话规律，若无则写"无新规律"）
