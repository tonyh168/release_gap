# metax/EXAONE-4.0-32B 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_EXAONE-4.0-32B_202608070744.md
- **原始失败类型**：服务启动失败（Operator crash）
- **日期**：2026-09-14

---

## 背景分析

原报告中 V1–V4 所有评测数据均为空，说明服务在 V1 阶段（裸 vLLM）就起不来，连基线都没有。
Issue 标题：`Operator crash on 沐曦(Metax) (LGAI-EXAONE/EXAONE-4.0-32B)`。

EXAONE-4.0-32B 是一个 MoE 架构模型（32B参数，非稠密），attention 实现可能用了 MLA 变体，
需要特别注意 `--attention-backend` 和 `VLLM_FL_USE_FLAGGEMS_ATTN` 的设置。

TP 计算：32B bf16 实际活跃参数更少，但权重文件仍约 64GB → TP=2 起步，若 OOM 升至 TP=4。
单卡 63.6GB，2 卡 127.2GB，预留 30% → 可用 89GB，能装下 64GB 权重。建议先用 **TP=4** 留
足 KV cache 空间（EXAONE 类模型实测 TP=2 KV cache OOM，见 SOP 说明）。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-___` |
| 容器名 | `EXAONE-4.0-32B_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/EXAONE-4.0-32B` |
| 卡号 | `MACA_VISIBLE_DEVICES=0,1,2,3`（TP=4）|
| 实际 vLLM 版本 | |

---

## Step 0：登录 + 查卡

```bash
ssh metax-57
mx-smi   # 确认至少4张卡空闲
```

**mx-smi 输出节选**：
```
（上机后粘贴，确认空闲卡号）
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
docker run -d --rm \
  --name EXAONE-4.0-32B_flagos \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it EXAONE-4.0-32B_flagos /bin/bash

mx-smi
python -c "import vllm; print(vllm.__version__)"
```

**自检输出**：
```
vllm 版本：
```

---

## Step 2：确认模型

权重来源：`LGAI-EXAONE/EXAONE-4.0-32B`（ModelScope）

```bash
ls /models/ | grep -i exaone
ls /models/EXAONE-4.0-32B/
```

**结果**：☐ 共享盘已有 / ☐ 需下载

若需下载：
```bash
pip install -q modelscope
modelscope download --model LGAI-EXAONE/EXAONE-4.0-32B \
  --local_dir /models/EXAONE-4.0-32B
```

---

## Step 3：起 vLLM 服务

### 修复策略

原始失败是 Operator crash，修复路径：
1. 先用 eager + 默认黑名单起服务，看崩溃日志定位算子名
2. 把崩溃算子加入黑名单，重试
3. 服务起来后做长 prompt 冒烟（不能只测 `1+1`，EXAONE 是 thinking 类模型）

### 环境变量（每次迭代更新）

**第1次尝试**（SOP 默认黑名单，TP=4）：
```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0,1,2,3
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
```

```bash
model_name=EXAONE-4.0-32B
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/EXAONE-4.0-32B \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

**崩溃日志关键行**（贴 traceback 最后几行 + 算子名）：
```
（崩溃时粘贴，用于定位黑名单补充项）
```

**第N次尝试**（补充黑名单后）：
```bash
# 在上面基础上修改 VLLM_FL_FLAGOS_BLACKLIST：
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice,<补充算子>
```

### 迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST 补充项 | 结果 | 备注 |
|------|---------------------------------|------|------|
| 第1次 | （无，使用默认） | 崩溃/成功 | |
| 第2次 | | | |

**启动成功的日志行**：
```
（贴 "Application startup complete"）
```

### 冒烟验证（EXAONE 是 thinking 模型，必须用长 prompt）

```bash
model_name=EXAONE-4.0-32B
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？请详细介绍该城市的历史沿革、人口规模和主要政治职能。"}],"max_tokens":512,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}'
```

**冒烟输出节选**：
```
（贴 content 字段前100字）
```

---

## Step 4：评测

```bash
# 宿主机
docker cp /path/to/release_评测标准 EXAONE-4.0-32B_flagos:/workspace/release_评测标准

# 容器内
docker exec -it EXAONE-4.0-32B_flagos /bin/bash
cd /workspace/release_评测标准
pip install -q 'evalscope==1.5.1' requests pyyaml

model_name=EXAONE-4.0-32B
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> ⚠ EXAONE 是 thinking 模型，50 题 GPQA 可能跑数小时，不要中断。
> 若 `truncation_detected: true` → 加大 `--max-model-len` 后重跑。

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| 第1次 | | | | |
| 第2次 | | | | |

**verdict.json 原文**（最终达标）：
```json
（粘贴）
```

---

## 现象
（上机后填：崩溃日志关键行 / 算子名）

## 定位
（填：哪个算子触发 crash / 是 graph capture 还是 eager 就崩）

## 处置
（填：加入黑名单的算子 / TP 调整）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
