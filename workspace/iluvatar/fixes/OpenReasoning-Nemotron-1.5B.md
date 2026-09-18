# iluvatar/OpenReasoning-Nemotron-1.5B 修复日志

- **失败报告**：新增模型（STATUS.md 补录，无历史失败报告）
- **原始失败类型**：未开始
- **日期**：2026-09-16

## 背景分析

OpenReasoning-Nemotron-1.5B 为 NVIDIA 开源推理小模型，1.5B 参数，decoder-only（Llama 架构）。
bf16 约 3 GB，单卡 32 GB 绰绰有余，TP=1。
评测指标为 mmlu + math_500（nv_baseline 无 gpqa_diamond 条目）。
NV 基线：mmlu=52.21，math_500=84.0。

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-openreasoning-nemotron-1.5b` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B` |
| 卡号 | GPU 1（CUDA_VISIBLE_DEVICES=1，TP=1） |
| 端口 | 8011 |

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
/usr/local/corex-4.5.0/bin/ixsmi
docker ps --format '{{.Names}}\t{{.Status}}'
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=openreasoning-nemotron-1.5b
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
ls /models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B/
```

若需下载（eval-scope 容器内）：
```bash
docker exec -it eval-scope bash
modelscope download --model nv-community/OpenReasoning-Nemotron-1.5B \
  --local_dir /models/flagrelease/fixes_models/OpenReasoning-Nemotron-1.5B
```
> 注：原路径 `nvidia/OpenReasoning-Nemotron-1.5B` 为错误路径（404），实际路径为 `nv-community/OpenReasoning-Nemotron-1.5B`。

## Step 3：起 vLLM 服务

```bash
docker exec -d flagrelease-fix-openreasoning-nemotron-1.5b bash -c "
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=OpenReasoning-Nemotron-1.5B
mkdir -p /models/release_run_logs/\${model_name}
vllm serve /models/flagrelease/fixes_models/\${model_name} \
  --served-model-name \${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8011 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/\${model_name}/serve.log
"
```

若 crash → 抓算子名追加黑名单：
```bash
grep -E "Error|crash|Traceback|RuntimeError|NotImplemented" \
  /models/release_run_logs/OpenReasoning-Nemotron-1.5B/serve.log | tail -20
```

| 迭代 | 黑名单 | TP | 端口 | 结果 | 备注 |
|------|--------|----|------|------|------|
| 第1次 | sort,sort_stable | 1 | 8011 | ❌ mmlu 35.0%（NV 52.21，↓32.9%）；math_500 进行中 | TRITON_ATTN；服务健康（190 tok/s）；mmlu 完成 2026-09-18 01:55；math_500 进行中（156/200 at 04:03，预计 ~05:30 完成） |

## Step 4：smoke test

```bash
model_name=OpenReasoning-Nemotron-1.5B
curl -s http://localhost:8011/v1/models
curl -s http://localhost:8011/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":64,"temperature":0}'
```

## Step 5：评测

评测指标为 mmlu + math_500（无 gpqa_diamond 基线）。

```bash
docker exec -d eval-scope bash -c "
cd /workspace/eval_scripts
model_name=OpenReasoning-Nemotron-1.5B
mkdir -p /models/release_run_logs/\${model_name}
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8011/v1 --dataset mmlu \
  --output /models/release_run_logs/\${model_name}/mmlu.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_mmlu.log
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8011/v1 --dataset math_500 \
  --output /models/release_run_logs/\${model_name}/math_500.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_math.log
"
```

compare：
```bash
docker exec eval-scope bash -c "
cd /workspace/eval_scripts
model_name=OpenReasoning-Nemotron-1.5B
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/\${model_name}/mmlu.json \
  --nv-baseline \${model_name} --nv-baseline-file nv_baseline.yaml \
  --metric mmlu --json \
  --output /models/release_run_logs/\${model_name}/verdict_mmlu.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/\${model_name}/math_500.json \
  --nv-baseline \${model_name} --nv-baseline-file nv_baseline.yaml \
  --metric math_500 --json \
  --output /models/release_run_logs/\${model_name}/verdict_math.json
"
```

| 迭代 | 黑名单 | mmlu | math_500 | 退出码 | 备注 |
|------|--------|------|----------|--------|------|
| 第1次 | sort,sort_stable | **35.0%**（1140题，NV 52.21，↓32.9%） | 进行中（156/200 at 2026-09-18 04:03） | — | mmlu 分数从 evalscope 报告 `outputs/mmlu/20260917_033152` 恢复；fast_gpqa.py detect_runaway bug crash |

## 现象

- iter1（sort,sort_stable 黑名单，TRITON_ATTN，TP=1，GPU 1，port 8011）：
  - 服务正常启动，smoke test 通过，生成速度约 190 tok/s（1.5B，正常）。
  - MMLU 评测完成（1140题，2026-09-18 01:55），fast_gpqa.py 因 thinking 模型 list content 触发 detect_runaway AttributeError 崩溃，score 字段未写出。
  - 从 evalscope 报告 `/workspace/eval_scripts/outputs/mmlu/20260917_033152/reports/OpenReasoning-Nemotron-1.5B/mmlu.json` 恢复：`score=0.35` → **35.0%**，1140 题。
  - math_500 评测仍在进行中（156/200 at 04:03，pid 5540 健康，预计约 05:30 完成）。

## 定位

- MMLU 退化：35.0% vs NV 52.21（↓32.9%），差距 17.21 分，远超 5% 容差。
- 基础黑名单（sort,sort_stable）对 OpenReasoning-Nemotron-1.5B 效果极差，精度损失来源于其他算子。
- math_500 结果待出，但 MMLU 退化幅度如此之大，math_500 大概率同样不达标。

## 处置

MMLU 严重不达标（↓32.9%），graph 模式 capture 在 batch 56 时 OOM（9/51 graphs 成功，VRAM 耗尽），graph 模式暂无法用。精度与 graph/eager 模式无关，精度损失来源于基础黑名单之外的其他算子。差距过大（17分），常规扩黑名单路径修复难度极高，**放弃**。

## 结果

- MMLU：**35.0%**（1140题，NV 52.21，↓32.9%）— ❌ 不达标
- math_500：已中止（容器已停）
- 达标判定：**放弃**（MMLU 差距 17.21 分，远超 5% 容差，graph 模式亦 OOM）

## 提炼到 KNOWLEDGE 的条目

OpenReasoning-Nemotron-1.5B 在 sort,sort_stable 基础黑名单下 MMLU=35.0%（NV 52.21，↓32.9%），严重不达标；精度损失来源于基础黑名单之外的其他算子。
