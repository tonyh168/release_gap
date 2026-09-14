# metax/Phi-3-mini-128k-instruct 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_Phi-3-mini-128k-instruct_202607160324.md
- **原始失败类型**：精度偏差 4.0%（V1:42% → V2:38%，超5%阈值）+ 性能 79.2%（踩线）
- **日期**：2026-09-14

---

## 背景分析

原报告用 vLLM 0.20.2 + plugin-FL 0.2.0；V2/V3 算子白名单数据缺失（无数据），说明自动化流程
在 V2 阶段就失败了，没产出有效算子数据。精度偏差 4.0%（50题：42% vs 38%）和性能 79.2% 都
刚好踩线——可能是随机抖动，也可能是真实算子问题，需在新镜像下重新跑一轮才能确认。

TP 计算：3.8B × 2 bytes(bf16) ≈ 7.6GB，单卡 63.6GB → TP=1。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `Phi-3-mini-128k-instruct_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/Phi-3-mini-128k-instruct` |
| 卡号 | `MACA_VISIBLE_DEVICES=0`（GPU 0，56GB 已占用） |
| 实际 vLLM 版本 | 0.24.0 |

---

## Step 0：登录 + 查卡

```bash
ssh metax-60
mx-smi
```

**mx-smi 输出节选**：
```
GPU 0: MetaX C550, 57252/65536 MiB 已占用（本模型服务进程）
GPU 1-7: 858/65536 MiB 空闲
```

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
docker run -d --rm \
  --name Phi-3-mini-128k-instruct_flagos \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it Phi-3-mini-128k-instruct_flagos /bin/bash

mx-smi
python -c "import vllm; print(vllm.__version__)"
```

**自检输出**：
```
vllm 版本：
```

---

## Step 2：确认模型

权重来源：`LLM-Research/Phi-3-mini-128k-instruct`（ModelScope）

```bash
ls /models/ | grep -i phi-3-mini
ls /models/Phi-3-mini-128k-instruct/
```

**结果**：☐ 共享盘已有 / ☐ 需下载

若需下载：
```bash
pip install -q modelscope
modelscope download --model LLM-Research/Phi-3-mini-128k-instruct \
  --local_dir /models/Phi-3-mini-128k-instruct
```

---

## Step 3：起 vLLM 服务

### 环境变量（每次迭代更新）

**第1次尝试**（SOP 默认黑名单，2026-09-14 metax-60）：
```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=0
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
```

```bash
model_name=Phi-3-mini-128k-instruct
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/Phi-3-mini-128k-instruct \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.9 \
  --port 8000 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

**启动结果**：
```
Application startup complete（服务正常启动，端口 8000）
```

### 冒烟验证

```bash
model_name=Phi-3-mini-128k-instruct
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？请详细介绍该城市的历史沿革、人口规模和主要政治职能。"}],"max_tokens":256,"temperature":0}'
```

**冒烟输出节选**：
```
（贴 content 字段前100字）
```

---

## Step 4：评测

```bash
# 宿主机
docker cp /path/to/release_评测标准 Phi-3-mini-128k-instruct_flagos:/workspace/release_评测标准

# 容器内
docker exec -it Phi-3-mini-128k-instruct_flagos /bin/bash
cd /workspace/release_评测标准
pip install -q 'evalscope==1.5.1' requests pyyaml

model_name=Phi-3-mini-128k-instruct
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:8000/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

> 若退出码 1 且精度偏差在 4-5%：用 `--limit 0` 跑全量 198 题确认是否真超阈值（50题随机抖动大）。
> 若精度偏差 >5%：二分法缩减黑名单定位退化算子。

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | 题数 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------|------------------------|------|
| 第1次（V3，plugin-FL 开） | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | 28% | 50 | 1（不达标） | 2026-09-14 metax-60，evalscope 1.11.1 |
| 第2次 | | | | | |

**verdict.json 原文**（最终达标）：
```json
（粘贴）
```

---

## 现象

- 服务正常启动（GPU 0，TP=1，端口 8000），`Application startup complete`
- evalscope 1.11.1 评测 50 题，耗时 ~447 秒（约 7.5 分钟）
- `truncation_detected: false`，`runaway_count: 0`，无截断无复读
- evalscope 报告文件（`outputs/gpqa_diamond/20260914_075702/reports/Phi-3-mini-128k-instruct/gpqa_diamond.json`）：`metrics[0].score = 0.28`
- gpqa.json 写出 `score: null`（parse_result bug，已在 commit 5b70c34 修复）

## 定位

- 精度结果：28%（14/50 题正确）
- NV 基线：33.0%（16.5/50 题对应）
- 相对退化：(33.0 - 28.0) / 33.0 = **15.15%**，远超 5% 阈值
- 绝对差 2.5 题，超过小样本容忍上限（≤2 题），无法用小样本容忍达标
- 退化原因尚未定位：可能是 plugin-FL 算子精度问题，也可能是 vLLM 0.24.0 相比 0.20.2 在 Phi-3 模型上有精度回退。需进一步二分法定位

## 处置

- 本轮未做黑名单调整，仅跑了第 1 次迭代（SOP 默认黑名单）
- 下一步：关闭 plugin（`VLLM_PLUGINS=` 不设）跑裸 vLLM V1 基线，确认是 plugin 引入的退化还是 vLLM 0.24.0 本身的回退

## 结果

- 修复后 GPQA 正确率：28%（V3，plugin-FL 开，默认黑名单）
- NV 基线：33.0%
- 达标判定：❌ 不达标（相对退化 15.15%，accuracy_compare 退出码 1）

## 提炼到 KNOWLEDGE 的条目

Phi-3-mini-128k-instruct 在 metax vLLM 0.24.0 + plugin-FL 默认黑名单下 GPQA 28%（NV 33%，相对退化 15%），需跑 V1 裸 vLLM 基线确认退化来源（plugin vs vLLM 版本）。
