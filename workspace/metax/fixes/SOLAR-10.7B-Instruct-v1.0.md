# metax/SOLAR-10.7B-Instruct-v1.0 修复日志

- **失败报告**：flagrelease_fail_reports/Metax/FAILED_Metax_SOLAR-10.7B-Instruct-v1.0_202607261725.md
- **原始失败类型**：plugin-FL 报错 + 精度不达标（V3: 30.3% vs NV基线，rel_drop 超阈值）
- **日期**：2026-09-14

---

## 背景分析

原报告用 vLLM 0.20.2 + plugin-FL 0.2.0；本次用 vLLM 0.24.0 镜像，版本不同需注意 MLA 接口变更。
服务在旧版本能起来（V2/V3 均有评测数据），主要问题是 plugin-FL 报错导致精度退化。

TP 计算：10.7B × 2 bytes(bf16) ≈ 21.4GB，单卡 63.6GB，预留 30% → 可用 44GB → TP=1。

---

## 环境（实际运行时填写）

| 项目 | 值 |
|------|---|
| 宿主机 | `metax-60` |
| 容器名 | `SOLAR-10.7B-Instruct-v1.0_flagos` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907` |
| 模型路径 | `/models/SOLAR-10.7B-Instruct-v1.0`（2026-09-14 下载中） |
| 卡号 | `MACA_VISIBLE_DEVICES=1`（GPU 1，空闲） |
| 实际 vLLM 版本 | 0.24.0 |

---

## Step 0：登录 + 查卡

```bash
ssh metax-60
mx-smi
```

**mx-smi 输出节选**（2026-09-14）：
```
GPU 0: 57252/65536 MiB 占用（Phi-3-mini 服务）
GPU 1-7: 858/65536 MiB 空闲
```

**分配**：GPU 1（TP=1），服务端口 8001

---

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/metax-vllm-0.24.0-pluginfl-tree3.6:xingchen4-0907
docker run -d --rm \
  --name SOLAR-10.7B-Instruct-v1.0_flagos \
  --network host \
  --shm-size 64g \
  --device /dev/dri:/dev/dri:rwm \
  --device /dev/mxcd:/dev/mxcd:rwm \
  -v /public-flash/models:/models \
  ${IMAGE} \
  sleep infinity
docker exec -it SOLAR-10.7B-Instruct-v1.0_flagos /bin/bash
```

容器内自检：
```bash
mx-smi
python -c "import vllm; print(vllm.__version__)"
```

**自检输出**（2026-09-14 metax-60）：
```
容器已启动（container ID: 61bf4177315035a6）
pip 路径：/opt/conda/bin/pip（非标准 PATH，需全路径调用）
```

---

## Step 2：确认模型

```bash
ls /models/ | grep -i solar
ls /models/SOLAR-10.7B-Instruct-v1.0/   # 确认 config.json / *.safetensors / tokenizer
```

**结果**：☐ 共享盘已有 / ☑ 需下载（2026-09-14 权重不在共享盘，已在容器内后台下载）

```bash
# 容器内安装 modelscope 并后台下载（已执行）
/opt/conda/bin/pip install -q modelscope
nohup /opt/conda/bin/modelscope download --model upstage/SOLAR-10.7B-Instruct-v1.0 \
  --local_dir /models/SOLAR-10.7B-Instruct-v1.0 \
  > /models/release_run_logs/solar-download.log 2>&1 &
```

---

## Step 3：起 vLLM 服务

### 实际使用的完整环境变量（每次迭代更新此块）

**第1次尝试**（`--max-model-len 32768`，2026-09-14 metax-60）：

报错：
```
pydantic_core._pydantic_core.ValidationError: User-specified max_model_len (32768) is greater
than the derived max_model_len (max_position_embeddings=4096.0).
To allow overriding this maximum, set the env var VLLM_ALLOW_LONG_MAX_MODEL_LEN=1.
```

原因：SOLAR-10.7B-Instruct-v1.0 基于 LLaMA2，`config.json` 中 `max_position_embeddings=4096`，
指定 32768 超出模型实际上下文长度，vLLM 拒绝启动。

**第2次尝试**（修正 `--max-model-len 4096`，GPU 1，端口 8001）：
```bash
export GEMS_VENDOR=metax
export VLLM_PLUGINS=fl
export MACA_VISIBLE_DEVICES=1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice
export VLLM_FL_USE_FLAGGEMS_ATTN=0
export VLLM_ENGINE_ITERATION_TIMEOUT_S=7200
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
```

```bash
model_name=SOLAR-10.7B-Instruct-v1.0
mkdir -p /models/release_run_logs/${model_name}
/opt/conda/bin/vllm serve /models/SOLAR-10.7B-Instruct-v1.0 \
  --served-model-name ${model_name} \
  --dtype bfloat16 \
  --tensor-parallel-size 1 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.9 \
  --port 8001 \
  --enforce-eager \
  --no-enable-chunked-prefill \
  --trust-remote-code \
  >> /models/release_run_logs/${model_name}/serve.log 2>&1 &
```

**启动结果**：
```
(APIServer pid=568) INFO:     Application startup complete.
```

### 冒烟验证（长 prompt，必须做，别只测 1+1）

```bash
model_name=SOLAR-10.7B-Instruct-v1.0
curl -s http://localhost:8000/v1/models
curl -s http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪个城市？请详细介绍该城市的历史沿革、人口规模和主要政治职能。"}],"max_tokens":256,"temperature":0}'
```

**冒烟输出节选**：
```
1 + 1 equals 2.
```

✅ 服务正常响应（2026-09-14 metax-60，端口 8001）

---

## Step 4：评测

使用已有的 `Phi-3-mini-eval` 评测容器（挂载同一 NFS，已装 evalscope 1.11.1 和 modelscope）：

```bash
model_name=SOLAR-10.7B-Instruct-v1.0

docker exec Phi-3-mini-eval bash -c "
python3 /workspace/eval_scripts/fast_gpqa.py \
  --model-name ${model_name} \
  --api-base http://127.0.0.1:8001/v1 \
  --dataset-dir /models/evalscope-datasets \
  --output /models/release_run_logs/${model_name}/gpqa.json
"

docker exec Phi-3-mini-eval bash -c "
python3 /workspace/eval_scripts/accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} \
  --nv-baseline-file /workspace/eval_scripts/nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
"
```

> `--api-base` 用 8001 端口（SOLAR 服务）；eval 容器与 vLLM 容器 `--network host`，打 127.0.0.1 直连。

### 评测迭代记录

| 迭代 | VLLM_FL_FLAGOS_BLACKLIST | GPQA 正确率 | accuracy_compare 退出码 | 备注 |
|------|--------------------------|------------|------------------------|------|
| 第1次 | mm,mm_out,bmm,bmm_out,linear,sort,stable_sort,masked_fill,masked_fill_,slice | | | |
| 第2次 | （如需调整填这里） | | | |

**verdict.json 原文**（最终达标的那次）：
```json
（粘贴内容）
```

---

## 现象
（上机后填：贴关键日志 / 评测分数 / plugin报错行）

## 定位
（填：涉及哪个算子 / plugin-FL 哪层报错）

## 处置
（填：黑名单做了哪些调整 / 调了哪些参数）

## 结果
- 修复后 GPQA 正确率：
- NV 基线：
- 达标判定（accuracy_compare 退出码）：0=达标

## 提炼到 KNOWLEDGE 的条目
（一句话规律，若无则写"无新规律"）
