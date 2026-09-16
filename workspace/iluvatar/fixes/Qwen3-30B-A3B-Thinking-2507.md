# iluvatar/Qwen3-30B-A3B-Thinking-2507 修复日志

- **失败报告**：release_迁移失败报告/iluvatar/FAILED_Iluvatar_Qwen3-30B-A3B-Thinking-2507_202608261448.md
- **原始失败类型**：服务启动失败（Operator crash: libentry, mm on unknown platform）
- **日期**：2026-09-16

## 背景分析

V1 有 TTFT 性能数据（12265ms），说明裸 vLLM 可以起服务；V2/V3 评测全空，说明 plugin-FL 启动时 `mm` 算子 crash。
模型为 Qwen3 MoE（30B 总参数 / 3B 激活），标准 GQA attention，使用 `TRITON_ATTN`。
30B bf16 约 60 GB，TP=4（4×32 GB=128 GB），MoE routing overhead 不影响权重大小。
V2 白名单里含 MoE expert routing 相关 triton 代码片段（`cumsum_ptr`、`expert_ids_ptr`、`distributed_barrier`），这些是正常 MoE kernel，与 crash 无关；crash 在 `mm`（矩阵乘法）。

## 环境

| 项目 | 值 |
|------|----|
| 宿主机 | `iluvatar-139` |
| 容器名 | `flagrelease-fix-qwen3-30b-a3b-thinking` |
| 镜像 | `harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907` |
| 模型路径 | `/models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507` |
| 卡号 | GPU 4,5,6,7（CUDA_VISIBLE_DEVICES=4,5,6,7，TP=4） |
| 端口 | 8010 |

## Step 0：登录 + 查卡

```bash
ssh iluvatar-139
ixsmi
docker ps --format '{{.Names}}\t{{.Status}}'
```

## Step 1：起容器

```bash
IMAGE=harbor.baai.ac.cn/flagrelease-public/iluvatar-corex4.5.0-flagtree0.6.0-triton3.6.0-cxnone-vllm_fl0.24.0:2026082-xingchen4-0907
model_name=qwen3-30b-a3b-thinking
docker run -itd --name flagrelease-fix-${model_name} \
  --device=/dev/iluvatar0  --device=/dev/iluvatar1  --device=/dev/iluvatar2  --device=/dev/iluvatar3 \
  --device=/dev/iluvatar4  --device=/dev/iluvatar5  --device=/dev/iluvatar6  --device=/dev/iluvatar7 \
  --device=/dev/iluvatar8  --device=/dev/iluvatar9  --device=/dev/iluvatar10 --device=/dev/iluvatar11 \
  --device=/dev/iluvatar12 --device=/dev/iluvatar13 --device=/dev/iluvatar14 --device=/dev/iluvatar15 \
  --device=/dev/itrctl --device=/dev/itrlink --device=/dev/itr_peerm_dev0 \
  --ipc=host --network=host --shm-size 64g \
  -v /mnt/share/models:/models \
  ${IMAGE} bash
docker exec -it flagrelease-fix-${model_name} bash
ixsmi && python -c "import vllm; print(vllm.__version__)"
```

## Step 2：确认模型权重

权重来源：`Qwen/Qwen3-30B-A3B-Thinking-2507`（ModelScope）

```bash
ls /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507/
```

若需下载（eval-scope 容器内）：
```bash
docker exec -it eval-scope bash
modelscope download --model Qwen/Qwen3-30B-A3B-Thinking-2507 \
  --local_dir /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507
```

检查是否有 chat_template.jinja：
```bash
ls /models/flagrelease/fixes_models/Qwen3-30B-A3B-Thinking-2507/*.jinja 2>/dev/null
```

## Step 3：起 vLLM 服务

初始黑名单：`sort,sort_stable,mm`（原始 crash 为 `mm on unknown platform`）。

```bash
export GEMS_VENDOR=iluvatar
export VLLM_PLUGINS=fl
export CUDA_VISIBLE_DEVICES=<4张空闲卡>
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_FL_FLAGOS_BLACKLIST=sort,sort_stable,mm
export VLLM_ENGINE_ITERATION_TIMEOUT_S=72000
export VLLM_RPC_TIMEOUT=72000000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=7200
model_name=Qwen3-30B-A3B-Thinking-2507
mkdir -p /models/release_run_logs/${model_name}
vllm serve /models/flagrelease/fixes_models/${model_name} \
  --served-model-name ${model_name} --dtype bfloat16 \
  --tensor-parallel-size 4 --gpu-memory-utilization 0.9 \
  --port <PORT> --attention-backend TRITON_ATTN \
  --enforce-eager --trust-remote-code \
  2>&1 | tee /models/release_run_logs/${model_name}/serve.log
```

若有 chat_template.jinja，追加 `--chat-template /models/flagrelease/fixes_models/${model_name}/chat_template.jinja`。
若 OOM → 升 TP=8 或降 `--max-model-len 16384`。
若仍 crash → 从 serve.log 抓算子名，追加进黑名单。

| 迭代 | 黑名单 | TP | 端口 | 结果 | 备注 |
|------|--------|----|------|------|------|
| 第1次 | sort,sort_stable,mm | 4 | 8010 | ✅ GPQA 76.0% (NV 75.0%，↑1.33%) | 服务正常启动，无 crash；精度超基线，达标 |

## Step 4：smoke test

```bash
model_name=Qwen3-30B-A3B-Thinking-2507
curl -s http://localhost:<PORT>/v1/models
curl -s http://localhost:<PORT>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"'"${model_name}"'","messages":[{"role":"user","content":"中国的首都是哪里？"}],"max_tokens":64,"temperature":0}'
```

## Step 5：评测

Qwen3-30B-A3B-Thinking 为 thinking 模型，GPQA 50 题可能数小时，勿中断。

```bash
docker exec -it eval-scope bash
cd /workspace/release_评测标准
model_name=Qwen3-30B-A3B-Thinking-2507
python3 fast_gpqa.py --model-name ${model_name} \
  --api-base http://127.0.0.1:<PORT>/v1 \
  --output /models/release_run_logs/${model_name}/gpqa.json
python3 accuracy_compare.py \
  --v2 /models/release_run_logs/${model_name}/gpqa.json \
  --nv-baseline ${model_name} --nv-baseline-file nv_baseline.yaml --json \
  --output /models/release_run_logs/${model_name}/verdict.json
```

| 迭代 | 黑名单 | GPQA | 退出码 | 备注 |
|------|--------|------|--------|------|
| 第1次 | sort,sort_stable,mm | 76.0% | 0（达标） | score=null（thinking 模型 evalscope bug），从 `outputs/gpqa_diamond/20260916_074652/reports/` 恢复 score=0.76 → 76.0%；accuracy_compare ↑1.33%，反超基线 |

## 现象

原报告全部精度/性能数据为空（V2/V3）。V1 有 TTFT=12265ms，说明裸 vLLM 可起。
Issue：`【FR】Bug: Operator crash: libentry, mm on unknown platform`

## 定位

plugin-FL 启动时 `mm`（矩阵乘法）算子在天数硬件上 crash（`libentry` 路径）。

## 处置

`VLLM_FL_FLAGOS_BLACKLIST` 追加 `mm`，将矩阵乘法退回 PyTorch 原生实现。第1次迭代直接通过。

## 结果

- 修复后 GPQA 正确率：**76.0%**
- NV 基线：gpqa_diamond 75.0
- 达标判定（accuracy_compare 退出码）：**0（达标，↑1.33%，反超基线）**
- 评测耗时：~159 min（thinking 模型，50题）
- score=null 从 evalscope 原始报告恢复：`outputs/gpqa_diamond/20260916_074652/reports/Qwen3-30B-A3B-Thinking-2507/gpqa_diamond.json`

## 提炼到 KNOWLEDGE 的条目

- Qwen3 MoE 模型的原始 crash 根因是 `mm`（矩阵乘法）算子在 iluvatar libentry 路径 crash，黑名单加 `mm` 即可修复。
- 黑名单：`sort,sort_stable,mm`（三算子），TP=4，TRITON_ATTN。
- thinking 模型评测 score=null 是已知 evalscope 报告格式 bug，从 `outputs/<dataset>/<ts>/reports/<model>/` 恢复即可。
