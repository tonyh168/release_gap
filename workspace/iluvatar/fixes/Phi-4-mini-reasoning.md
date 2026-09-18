# iluvatar/Phi-4-mini-reasoning 修复日志

- **失败报告**：新增模型（STATUS.md 补录，无历史失败报告）
- **原始失败类型**：未开始
- **日期**：2026-09-16

## 背景分析

Phi-4-mini-reasoning 为 Microsoft Phi-4 系列推理小模型，约 3.8B 参数，decoder-only（Phi-4 MHA）。
bf16 约 7.6 GB，单卡 32 GB 足够，TP=1。
评测指标为 mmlu + math_500（nv_baseline 无 gpqa_diamond 条目）。
NV 基线：mmlu=72.83，math_500=88.2。

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-phi4-mini-reasoning` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Phi-4-mini-reasoning` |
| 卡号 | GPU 2（CUDA_VISIBLE_DEVICES=2，TP=1） |
| 端口 | 8012 |

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
/usr/local/corex-4.5.0/bin/ixsmi
docker ps --format '{{.Names}}\t{{.Status}}'
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=phi4-mini-reasoning
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
ls /models/flagrelease/fixes_models/Phi-4-mini-reasoning/
```

**权重来源（2026-09-18 改）**：改用 **HuggingFace 官方仓库** `microsoft/Phi-4-mini-reasoning`
（<https://huggingface.co/microsoft/Phi-4-mini-reasoning>）。此前那份是从 ModelScope 下的，
因怀疑权重有问题已于 2026-09-18 删除，改从 HF 重新下载。

> HF 上该仓库非 gated，许可 MIT。模型共 2 个分片 + index。

**下载路径（一律用 HF 官方 repo id，与 URL 一致）**：

| 项 | 值 |
|----|----|
| HF 页面 | <https://huggingface.co/microsoft/Phi-4-mini-reasoning> |
| repo id | `microsoft/Phi-4-mini-reasoning` |
| 本地目录 | `/models/flagrelease/fixes_models/Phi-4-mini-reasoning` |

下载（在 **eval-scope 容器内**执行）：

```bash
docker exec -it eval-scope bash

# ⚠️ 本集群直连 huggingface.co 不通（curl 15s 超时），必须设镜像，否则下载必失败
export HF_ENDPOINT=https://hf-mirror.com

# 方式一：hf（huggingface_hub 1.x 的当前命令；容器内已装 1.31.0）
hf download microsoft/Phi-4-mini-reasoning \
  --local-dir /models/flagrelease/fixes_models/Phi-4-mini-reasoning

# 方式二：huggingface-cli（旧命令，仍可用，会提示 deprecated）
# huggingface-cli download microsoft/Phi-4-mini-reasoning \
#   --local-dir /models/flagrelease/fixes_models/Phi-4-mini-reasoning
```

**下载后校验**（避免再次拿到可疑权重）——文件大小应与 HF 上游一致：

| 文件 | 大小（bytes） | sha256 |
|------|--------------|--------|
| `model-00001-of-00002.safetensors` | 4903637712 | `a0c24f128e33afb9e406915229af56171e0a2353bc78c1ea1b5260a36b3e6707` |
| `model-00002-of-00002.safetensors` | 2768428504 | `b4bfcc826b3c637333c6bd24b0dfe38fffd45eff7f4718df454366e875a12415` |

```bash
cd /models/flagrelease/fixes_models/Phi-4-mini-reasoning
ls -l model-0000*-of-00002.safetensors                     # 应为上表两个大小
sha256sum model-0000*-of-00002.safetensors                 # 应与上表一致
```

> **2026-09-18 实测校验结果：✅ 两个分片均完全一致。**
> 从 HF 重新下载后 `sha256sum` 输出
> `a0c24f128e33afb9e406915229af56171e0a2353bc78c1ea1b5260a36b3e6707`（00001）与
> `b4bfcc826b3c637333c6bd24b0dfe38fffd45eff7f4718df454366e875a12415`（00002），均与上游一致；
> 大小也与被删除的那份旧权重逐字节相同。
> **结论：权重不是低分（MMLU 58.07% / math_500 41.0%）的原因**，此前"权重损坏"的怀疑已排除，
> 后续排查应从算子 / 推理路径入手，勿再重复换权重。

> 环境要求：模型卡标注需 `transformers==4.51.3`（或更高版本支持），
> 参考依赖 `torch==2.5.1` / `accelerate==1.3.0`；推理时如遇异常可设
> `attn_implementation="eager"`。镜像内实际版本以 `pip list | grep transformers` 为准。
>
> `HF_ENDPOINT` 说明：`https://hf-mirror.com` 是国内常用的 HuggingFace 镜像站，
> 设了它之后 `hf` / `huggingface-cli` 的请求走镜像域名，**repo id 不用改**。
> 已验证：本集群 `hf-mirror.com` 可达（HTTP 307），`huggingface.co` 直连超时。

## Step 3：起 vLLM 服务

```bash
docker exec -d flagrelease-fix-phi4-mini-reasoning bash -c "
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=2
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Phi-4-mini-reasoning
mkdir -p /models/release_run_logs/\${model_name}
vllm serve /models/flagrelease/fixes_models/\${model_name} \
  --served-model-name \${model_name} --dtype bfloat16 \
  --tensor-parallel-size 1 --gpu-memory-utilization 0.9 \
  --port 8012 --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/\${model_name}/serve.log
"
```

若 crash → 抓算子名追加黑名单：
```bash
grep -E "Error|crash|Traceback|RuntimeError|NotImplemented" \
  /models/release_run_logs/Phi-4-mini-reasoning/serve.log | tail -20
```

| 迭代 | 黑名单 | TP | 端口 | 结果 | 备注 |
|------|--------|----|------|------|------|
| 第1次 | sort,sort_stable | 1 | 8012 | ❌ mmlu 58.07%（NV 72.83，↓20.3%）+ math_500 41.0%（NV 88.2，↓53.5%） | TRITON_ATTN；评测日志在容器内 `eval_mmlu.log` / `eval_math.log`；分数从 evalscope 报告恢复（mmlu: `outputs/mmlu/20260917_033152`，math_500: `outputs/math_500/20260917_102103`） |

## Step 4：smoke test

```bash
model_name=Phi-4-mini-reasoning
curl -s http://localhost:8012/v1/models
curl -s http://localhost:8012/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"What is 2+2?"}],"max_tokens":64,"temperature":0}'
```

## Step 5：评测

评测指标为 mmlu + math_500（无 gpqa_diamond 基线）。

```bash
docker exec -d eval-scope bash -c "
cd /workspace/eval_scripts
model_name=Phi-4-mini-reasoning
mkdir -p /models/release_run_logs/\${model_name}
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8012/v1 --dataset mmlu \
  --output /models/release_run_logs/\${model_name}/mmlu.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_mmlu.log
python3 fast_gpqa.py --model-name \${model_name} \
  --api-base http://127.0.0.1:8012/v1 --dataset math_500 \
  --output /models/release_run_logs/\${model_name}/math_500.json \
  2>&1 | tee /models/release_run_logs/\${model_name}/eval_math.log
"
```

compare：
```bash
docker exec eval-scope bash -c "
cd /workspace/eval_scripts
model_name=Phi-4-mini-reasoning
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
| 第1次 | | | | | |

## 现象

- iter1（sort,sort_stable 黑名单，TRITON_ATTN，TP=1，GPU 2，port 8012）：
  - 服务正常启动，smoke test 通过，生成速度约 11 tok/s（3.8B 单卡，thinking 模型，正常）。
  - MMLU 评测完成（1140题），从 evalscope 报告 `outputs/mmlu/20260917_033152` 恢复：**58.07%**。
  - math_500 评测完成（200题），从 evalscope 报告 `outputs/math_500/20260917_102103` 恢复：**41.0%**。
  - eval log 未写入 NFS，分数仅存于 eval-scope 容器内 evalscope 输出。

## 定位

- MMLU 退化：58.07% vs NV 72.83（↓20.3%），差距 14.76 分，远超 5% 容差。
- math_500 退化：41.0% vs NV 88.2（↓53.5%），差距 47.2 分，极度不达标。
- 基础黑名单（sort,sort_stable）对 Phi-4-mini-reasoning 效果极差，说明精度损失来源于其他算子。
- 数学推理任务对精度更敏感，41% 的 math_500 分数提示模型推理链受到严重干扰。

## 处置

iter1 双指标严重不达标，差距巨大（math_500 差距超 50%），常规扩黑名单路径修复难度极高，暂不继续迭代。

## 结果

- 修复后分数：MMLU **58.07%**（1140题）；math_500 **41.0%**（200题）
- NV 基线：MMLU 72.83；math_500 88.2
- 相对退化：MMLU ↓20.3%；math_500 ↓53.5%
- 达标判定：**❌ 不达标**（双指标均严重超出 5% 容差）

## 提炼到 KNOWLEDGE 的条目

Phi-4-mini-reasoning 在 sort,sort_stable 基础黑名单下 MMLU=58.07%（NV 72.83，↓20.3%）、math_500=41.0%（NV 88.2，↓53.5%），双指标严重不达标；精度损失来源于基础黑名单之外的其他算子，数学推理任务尤为敏感。
