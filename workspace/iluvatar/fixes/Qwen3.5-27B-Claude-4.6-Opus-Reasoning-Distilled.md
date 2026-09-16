# iluvatar/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 修复日志

- **失败报告**：新增模型（STATUS.md 补录，无历史失败报告）
- **原始失败类型**：未开始
- **日期**：2026-09-16

## 背景分析

Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled 为蒸馏推理模型，27B dense decoder（Qwen3.5 架构，GQA）。
bf16 约 54 GB，单卡 32 GB 不够，需 TP=2（两卡各 27 GB，gpu-memory-utilization=0.9 → 可用 28.8 GB/卡，刚好容纳）。
推理/thinking 模型，使用 `TRITON_ATTN`（非 MLA）。
评测指标为 gpqa_diamond。
NV 基线：gpqa_diamond=75。
权重来源：`Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled`（ModelScope）。

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-qwen3.5-27b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled` |
| 卡号 | GPU 4+5（CUDA_VISIBLE_DEVICES=4,5，TP=2，等 Qwen3-30B eval 完成释放） |
| 端口 | 8014 |

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
/usr/local/corex-4.5.0/bin/ixsmi
docker ps --format '{{.Names}}\t{{.Status}}'
```

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

## Step 2：确认模型权重

```bash
ls /models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/
```

若需下载（eval-scope 容器内）：
```bash
docker exec eval-scope bash -c "
modelscope download --model Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled \
  --local_dir /models/flagrelease/fixes_models/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
"
```

## Step 3：起 vLLM 服务

```bash
docker exec -d flagrelease-fix-qwen3.5-27b bash -c "
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=4,5
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
mkdir -p /models/release_run_logs/\${model_name}
vllm serve /models/flagrelease/fixes_models/\${model_name} \
  --served-model-name \${model_name} --dtype bfloat16 \
  --tensor-parallel-size 2 --gpu-memory-utilization 0.9 \
  --port 8014 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/\${model_name}/serve.log
"
```

若 crash → 抓算子名追加黑名单：
```bash
grep -E "Error|crash|Traceback|RuntimeError|NotImplemented" \
  /models/release_run_logs/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled/serve.log | tail -20
```

| 迭代 | 黑名单 | TP | 端口 | 结果 | 备注 |
|------|--------|----|------|------|------|
| 第1次 | sort,sort_stable | 2 | 8014 | | |

## Step 4：smoke test

```bash
model_name=Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
curl -s http://localhost:8014/v1/models
curl -s http://localhost:8014/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":64,"temperature":0}'
```

## Step 5：评测

thinking 模型，gpqa_diamond，注意 fast_gpqa.py score=null 问题（从 evalscope 报告恢复）。

```bash
docker exec -d eval-scope bash -c "
cd /workspace/eval_scripts
model_name=Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
mkdir -p /models/release_run_logs/\${model_name}
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8014/v1 --dataset gpqa_diamond \
  --output /models/release_run_logs/\${model_name}/gpqa.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval.log
"
```

compare：
```bash
docker exec eval-scope bash -c "
cd /workspace/eval_scripts
model_name=Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/\${model_name}/gpqa.json \
  --nv-baseline \${model_name} --nv-baseline-file nv_baseline.yaml \
  --metric gpqa_diamond --json \
  --output /models/release_run_logs/\${model_name}/verdict.json
"
```

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | | | | |

## 现象

（首次运行，待填写）

## 定位

（待填写）

## 处置

（待填写）

## 结果

- 修复后分 / NV 基线：— / gpqa_diamond 75
- 达标判定（accuracy_compare 退出码）：—

## 提炼到 KNOWLEDGE 的条目

（完成后填写）
